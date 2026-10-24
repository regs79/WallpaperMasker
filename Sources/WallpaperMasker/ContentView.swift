import SwiftUI
import WallpaperMaskerCore
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var model = MaskModel()
    @State private var isTargeted = false

    var body: some View {
        HSplitView {
            previewPane
                .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
            sidebar
                .frame(minWidth: 260, idealWidth: 340, maxWidth: 520, maxHeight: .infinity)
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let p = providers.first else { return false }
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                if let url { Task { @MainActor in model.load(url) } }
            }
            return true
        }
    }

    private var previewPane: some View {
        ZStack {
            Rectangle().fill(Color(nsColor: .underPageBackgroundColor))
            if let preview = model.preview {
                ZoomablePreview(image: preview)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 56)).foregroundStyle(.secondary)
                    Text("Drop a wallpaper image").font(.title3)
                    Button("Open…") { model.open() }.keyboardShortcut("o")
                }
            }
            if isTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8]))
                    .padding(8)
            }
            if model.isWorking {
                ProgressView().controlSize(.small).padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private var sidebar: some View {
        Form {
            Section("Display") {
                Picker("Resolution", selection: $model.selection) {
                    Section("Connected") {
                        ForEach(Array(model.screens.enumerated()), id: \.offset) { i, s in
                            Text(ScreenGeometry.name(of: s)).tag(MaskModel.DisplaySelection.screen(i))
                        }
                    }
                    ForEach(DisplayPreset.Group.allCases, id: \.self) { group in
                        Section(group.rawValue) {
                            ForEach(DisplayPreset.all.filter { $0.group == group }) { preset in
                                Text(preset.label).tag(MaskModel.DisplaySelection.preset(preset.id))
                            }
                        }
                    }
                }
                Picker("Wallpaper mode", selection: $model.scaleMode) {
                    ForEach(ScaleMode.allCases) { Text($0.rawValue).tag($0) }
                }
                Stepper(value: $model.topStripPt, in: 0...80, step: 1) {
                    HStack {
                        Text("Menu bar")
                        Spacer()
                        Text("\(Int(model.topStripPt)) pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                Stepper(value: $model.cornerRadiusPt, in: 0...40, step: 1) {
                    HStack {
                        Text("Corner radius")
                        Spacer()
                        Text("\(Int(model.cornerRadiusPt)) pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section("Menu bar") {
                HStack {
                    Toggle("Mask menu bar", isOn: $model.maskMenuBar)
                    Spacer()
                    ColorPicker("Menu bar colour", selection: $model.menuBarColor, supportsOpacity: true)
                        .labelsHidden().disabled(!model.maskMenuBar)
                }
                Toggle("Frosted blur", isOn: $model.menuBarFrosted)
                    .disabled(!model.maskMenuBar)
            }
            Section("Corners") {
                HStack {
                    Toggle("Mask corners", isOn: $model.maskCorners)
                    Spacer()
                    ColorPicker("Corner colour", selection: $model.cornerColor, supportsOpacity: true)
                        .labelsHidden().disabled(!model.maskCorners || model.cornersMatchMenuBar)
                }
                Toggle("Match menu bar", isOn: $model.cornersMatchMenuBar)
                    .disabled(!model.maskCorners || !model.maskMenuBar)
                Toggle("Frosted blur", isOn: $model.cornersFrosted)
                    .disabled(!model.maskCorners || model.cornersMatchMenuBar)
            }
            Section("Frost") {
                Stepper(value: $model.blurPt, in: 2...80, step: 2) {
                    HStack {
                        Text("Blur radius")
                        Spacer()
                        Text("\(Int(model.blurPt)) pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!(model.menuBarFrosted || (model.cornersFrosted && !model.cornersMatchMenuBar)))
            }
            Section("Mask") {
                Text(model.summary)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section {
                HStack {
                    Button("Open…") { model.open() }
                    Spacer()
                    Button("Save Copy…") { model.saveCopy() }
                        .keyboardShortcut("s")
                        .buttonStyle(.borderedProminent)
                        .disabled(model.loaded == nil || model.isWorking || model.nothingSelected)
                }
            }
            Section {
                Text(model.status)
                    .font(.caption)
                    .foregroundStyle(model.isError ? Color.red : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
    }
}

/// Scrollable, zoomable image. Zoom 1 = fit to the pane; "100%" shows one image pixel per screen pixel.
private struct ZoomablePreview: View {
    let image: NSImage

    @State private var zoom: CGFloat = 1
    @State private var gestureStart: CGFloat?
    @Environment(\.displayScale) private var displayScale

    private let minZoom: CGFloat = 1
    private let maxZoom: CGFloat = 64

    var body: some View {
        GeometryReader { geo in
            let pane = geo.size
            let fit = fitSize(in: CGSize(width: max(pane.width - 32, 1), height: max(pane.height - footerHeight - 32, 1)))
            let shown = CGSize(width: fit.width * zoom, height: fit.height * zoom)
            let pixelsPerPoint = image.size.width / max(shown.width, 1)

            VStack(spacing: 0) {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .resizable()
                        // Nearest-neighbour once we're at or past 1:1 so real pixels stay crisp.
                        .interpolation(pixelsPerPoint * displayScale <= 1 ? .none : .high)
                        .frame(width: shown.width, height: shown.height)
                        .padding(16)
                        .frame(minWidth: pane.width, minHeight: pane.height - footerHeight) // centres when smaller than the pane
                }
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            if gestureStart == nil { gestureStart = zoom }
                            setZoom((gestureStart ?? zoom) * value.magnification)
                        }
                        .onEnded { _ in gestureStart = nil }
                )
                Divider()
                // Footer lives outside the scroll area so it never covers the image.
                controls(oneToOne: image.size.width / (fit.width * displayScale))
                    .frame(height: footerHeight)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .background(.bar)
            }
        }
    }

    private let footerHeight: CGFloat = 34

    private func fitSize(in bounds: CGSize) -> CGSize {
        let s = min(bounds.width / image.size.width, bounds.height / image.size.height)
        return CGSize(width: image.size.width * s, height: image.size.height * s)
    }

    private func setZoom(_ z: CGFloat) { zoom = min(max(z, minZoom), maxZoom) }

    private func controls(oneToOne: CGFloat) -> some View {
        HStack(spacing: 2) {
            Button { setZoom(zoom / 1.25) } label: { Image(systemName: "minus.magnifyingglass") }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(zoom <= minZoom)
            Text("\(Int((zoom / oneToOne * 100).rounded()))%")
                .monospacedDigit()
                .frame(width: 52)
            Button { setZoom(zoom * 1.25) } label: { Image(systemName: "plus.magnifyingglass") }
                .keyboardShortcut("=", modifiers: .command)
                .disabled(zoom >= maxZoom)
            Divider().frame(height: 14)
            Button("Fit") { setZoom(1) }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(zoom == 1)
            Button("100%") { setZoom(oneToOne) }
                .keyboardShortcut("1", modifiers: .command)
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(.horizontal, 12)
        .onChange(of: image) { setZoom(1) }
    }
}
