import AppKit
import SwiftUI
import WallpaperMaskerCore
import UniformTypeIdentifiers

@MainActor
final class MaskModel: ObservableObject {
    @Published var loaded: ImageFile.Loaded?
    @Published var preview: NSImage?
    @Published var status: String = "Drop a wallpaper image here, or click Open…"
    @Published var isError = false
    @Published var isWorking = false

    enum DisplaySelection: Hashable {
        case screen(Int)
        case preset(String)
    }

    @Published var screens: [NSScreen] = NSScreen.screens
    @Published var selection: DisplaySelection = .screen(0) { didSet { resetTopStrip(); schedulePreview() } }
    /// Points between the top of the screen and the top of a zoomed window. Measured for connected
    /// screens, estimated for presets; adjustable either way.
    @Published var topStripPt: Double = 0 { didSet { schedulePreview() } }
    @Published var cornerRadiusPt: Double = ScreenGeometry.defaultCornerRadiusPt { didSet { schedulePreview() } }
    @Published var scaleMode: ScaleMode = .fill { didSet { schedulePreview() } }
    @Published var maskMenuBar = true { didSet { schedulePreview() } }
    @Published var maskCorners = true { didSet { schedulePreview() } }
    @Published var menuBarColor: Color = .black { didSet { schedulePreview() } }
    @Published var cornerColor: Color = .black { didSet { schedulePreview() } }
    /// Frosted = blur the wallpaper under the region, then lay the (usually translucent) colour over it,
    /// which is how the menu bar looks on macOS versions where it isn't fully transparent.
    @Published var menuBarFrosted = false { didSet { if menuBarFrosted, !oldValue { suggestFrostTint(&menuBarColor) }; schedulePreview() } }
    @Published var cornersFrosted = false { didSet { if cornersFrosted, !oldValue { suggestFrostTint(&cornerColor) }; schedulePreview() } }
    /// Corners copy the menu bar's colour, opacity and blur so the wedges and strip read as one surface.
    @Published var cornersMatchMenuBar = false { didSet { schedulePreview() } }
    /// Blur sigma in points, shared by every frosted region.
    @Published var blurPt: Double = 24 { didSet { schedulePreview() } }

    private var previewTask: Task<Void, Never>?

    init() {
        if let main = NSScreen.main, let i = screens.firstIndex(of: main) { selection = .screen(i) }
        resetTopStrip()
        AppDelegate.onOpen = { [weak self] url in self?.load(url) }
        if let url = AppDelegate.pendingURL { AppDelegate.pendingURL = nil; load(url) }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshScreens() }
        }
    }

    var screen: NSScreen? {
        if case .screen(let i) = selection, screens.indices.contains(i) { return screens[i] }
        return nil
    }

    var preset: DisplayPreset? {
        if case .preset(let id) = selection { return DisplayPreset.all.first { $0.id == id } }
        return nil
    }

    /// The strip height the current selection reports before any user adjustment.
    var defaultTopStripPt: Double {
        if let screen { return ScreenGeometry.topStripPt(for: screen) }
        if let preset { return preset.topStripPt }
        return 0
    }

    func resetTopStrip() { topStripPt = defaultTopStripPt }

    var spec: MaskSpec? {
        var spec: MaskSpec
        if let screen {
            spec = ScreenGeometry.spec(for: screen, topStripPt: topStripPt, cornerRadiusPt: cornerRadiusPt, scaleMode: scaleMode)
        } else if let preset {
            spec = DisplayPreset.spec(for: preset, topStripPt: topStripPt, cornerRadiusPt: cornerRadiusPt, scaleMode: scaleMode)
        } else {
            return nil
        }
        spec.maskMenuBar = maskMenuBar
        spec.maskCorners = maskCorners
        let blurPx = CGFloat(blurPt) * displayScale
        spec.menuBarStyle = RegionStyle(color: RGBA(menuBarColor), blurPx: menuBarFrosted ? blurPx : 0)
        spec.cornerStyle = cornersMatchMenuBar
            ? spec.menuBarStyle
            : RegionStyle(color: RGBA(cornerColor), blurPx: cornersFrosted ? blurPx : 0)
        return spec
    }

    var displayScale: CGFloat { screen?.backingScaleFactor ?? preset?.scale ?? 2 }

    /// When a region is first frosted and its colour is still opaque, swap in a translucent tint that
    /// resembles the system menu bar in the current appearance. Leaves user-chosen tints alone.
    private func suggestFrostTint(_ color: inout Color) {
        guard RGBA(color).a >= 0.999 else { return }
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        color = dark ? Color(.sRGB, white: 0.1, opacity: 0.55) : Color(.sRGB, white: 1, opacity: 0.7)
    }

    var nothingSelected: Bool { !maskMenuBar && !maskCorners }

    /// Human-readable summary of what will be blacked out, in image pixels.
    var summary: String {
        guard let spec else { return "No display found." }
        var s = "Screen \(Int(spec.screenPx.width))×\(Int(spec.screenPx.height)) px · top strip \(Int(spec.topStripPx)) px · corner radius \(Int(spec.cornerRadiusPx)) px"
        if let img = loaded?.image {
            let (rect, r) = MaskRenderer.windowRectInImage(imageSize: CGSize(width: img.width, height: img.height), spec: spec)
            s += "\nImage \(img.width)×\(img.height) px → strip \(Int(rect.minY.rounded())) px, radius \(Int(r.rounded())) px"
        }
        return s
    }

    func refreshScreens() {
        let current = screen
        screens = NSScreen.screens
        if case .screen = selection {
            selection = .screen(current.flatMap { screens.firstIndex(of: $0) } ?? 0)
        }
    }

    func open() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url { load(url) }
    }

    func load(_ url: URL) {
        do {
            loaded = try ImageFile.load(url)
            isError = false
            status = "Loaded \(url.lastPathComponent)"
            schedulePreview()
        } catch {
            fail(error)
        }
    }

    func schedulePreview() {
        previewTask?.cancel()
        guard let loaded, let spec else { preview = nil; return }
        let source = loaded.image
        isWorking = true
        previewTask = Task.detached(priority: .userInitiated) { [source, spec] in
            try? await Task.sleep(for: .milliseconds(120)) // debounce stepper/slider churn
            if Task.isCancelled { return }
            // Full-resolution render so zooming in shows the real pixels that will be saved,
            // cropped to the part of the image the screen actually shows.
            guard let rendered = try? MaskRenderer.render(source: source, spec: spec) else { return }
            let visible = MaskRenderer.visibleRect(imageSize: CGSize(width: rendered.width, height: rendered.height), spec: spec)
            let out = rendered.cropping(to: visible) ?? rendered
            let ns = NSImage(cgImage: out, size: NSSize(width: out.width, height: out.height))
            await MainActor.run {
                if !Task.isCancelled { self.preview = ns; self.isWorking = false }
            }
        }
    }

    func saveCopy() {
        guard let loaded, let spec else { return }
        let outType = ImageFile.outputType(for: loaded.type)
        let base = loaded.url.deletingPathExtension().lastPathComponent
        let ext = outType.preferredFilenameExtension ?? loaded.url.pathExtension

        let panel = NSSavePanel()
        panel.directoryURL = loaded.url.deletingLastPathComponent()
        panel.nameFieldStringValue = "\(base) masked.\(ext)"
        panel.allowedContentTypes = [outType]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        isWorking = true
        status = "Rendering…"
        let source = loaded.image
        let sourceURL = loaded.url
        Task.detached(priority: .userInitiated) {
            do {
                let out = try MaskRenderer.render(source: source, spec: spec)
                try ImageFile.save(out, to: url, as: outType, source: sourceURL)
                await MainActor.run {
                    self.isWorking = false
                    self.isError = false
                    self.status = "Saved \(url.lastPathComponent)"
                }
            } catch {
                await MainActor.run { self.isWorking = false; self.fail(error) }
            }
        }
    }

    private func fail(_ error: Error) {
        isError = true
        status = error.localizedDescription
    }
}

private extension RGBA {
    init(_ color: Color) {
        let c = NSColor(color).usingColorSpace(.sRGB) ?? .black
        self.init(r: c.redComponent, g: c.greenComponent, b: c.blueComponent, a: c.alphaComponent)
    }
}
