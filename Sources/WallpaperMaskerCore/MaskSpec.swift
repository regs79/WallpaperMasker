import CoreGraphics
import Foundation

/// How macOS scales the wallpaper onto the screen (System Settings → Wallpaper).
public enum ScaleMode: String, CaseIterable, Identifiable, Sendable {
    case fill = "Fill Screen"
    case fit = "Fit to Screen"
    case stretch = "Stretch to Fill Screen"
    public var id: String { rawValue }
}

/// A plain sRGB colour that is cheap to compare and hand to Core Graphics.
public struct RGBA: Equatable, Sendable {
    public var r: Double, g: Double, b: Double, a: Double
    public init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }
    public static let black = RGBA(r: 0, g: 0, b: 0)
    public var cgColor: CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }
}

/// How a region is painted: an optional frosted blur of the wallpaper underneath,
/// then a colour (with opacity) on top. Solid black = no blur, opaque black.
/// Frosted menu bar (Sonoma/Sequoia look) = blur + translucent white or black.
public struct RegionStyle: Equatable, Sendable {
    public var color: RGBA
    /// Gaussian blur sigma in *screen pixels*; 0 = no blur.
    public var blurPx: CGFloat
    public init(color: RGBA = .black, blurPx: CGFloat = 0) {
        self.color = color; self.blurPx = blurPx
    }
    public var isFrosted: Bool { blurPx > 0 }
}

/// Everything the renderer needs, in *screen pixels* (origin top-left).
public struct MaskSpec: Equatable, Sendable {
    /// Full screen size in pixels.
    public var screenPx: CGSize
    /// Frame of a zoomed (maximised) window in pixels, origin top-left.
    public var windowRectPx: CGRect
    /// Window corner radius in pixels.
    public var cornerRadiusPx: CGFloat
    public var scaleMode: ScaleMode

    /// Paint the strip above the window (menu bar + gap).
    public var maskMenuBar: Bool
    /// Paint the four wedges outside the window's rounded corners.
    public var maskCorners: Bool
    public var menuBarStyle: RegionStyle
    public var cornerStyle: RegionStyle

    public init(screenPx: CGSize, windowRectPx: CGRect, cornerRadiusPx: CGFloat, scaleMode: ScaleMode = .fill,
                maskMenuBar: Bool = true, maskCorners: Bool = true,
                menuBarStyle: RegionStyle = RegionStyle(), cornerStyle: RegionStyle = RegionStyle()) {
        self.screenPx = screenPx
        self.windowRectPx = windowRectPx
        self.cornerRadiusPx = cornerRadiusPx
        self.scaleMode = scaleMode
        self.maskMenuBar = maskMenuBar
        self.maskCorners = maskCorners
        self.menuBarStyle = menuBarStyle
        self.cornerStyle = cornerStyle
    }

    // Convenience accessors for callers that only care about a flat colour.
    public var menuBarColor: RGBA { get { menuBarStyle.color } set { menuBarStyle.color = newValue } }
    public var cornerColor: RGBA { get { cornerStyle.color } set { cornerStyle.color = newValue } }

    /// Height of the visible strip above the window (menu bar + gap), in pixels.
    public var topStripPx: CGFloat { windowRectPx.minY }
}
