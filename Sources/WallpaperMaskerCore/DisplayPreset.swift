import CoreGraphics
import Foundation

/// A known display. Only the point size and the menu-bar strip height matter for the mask;
/// the pixel scale is informational (the mask is proportional, so it cancels out).
public struct DisplayPreset: Identifiable, Hashable, Sendable {
    public enum Group: String, CaseIterable, Sendable { case appleBuiltIn = "Apple notebooks & iMac", appleExternal = "Apple displays", monitors = "Common monitors" }

    public let id: String
    public let name: String
    public let group: Group
    public let pointSize: CGSize
    public let scale: CGFloat
    /// Visible strip above a zoomed window in points (menu bar + the 2pt gap macOS leaves below it).
    public let topStripPt: CGFloat

    public var pixelSize: CGSize { CGSize(width: pointSize.width * scale, height: pointSize.height * scale) }
    public var label: String { "\(name) · \(Int(pixelSize.width))×\(Int(pixelSize.height))" }

    /// Measured on a 14" MacBook Pro: 32pt notch-height menu bar + 2pt gap.
    public static let notchStrip: CGFloat = 34
    /// Standard 24pt menu bar + 2pt gap on displays without a notch.
    public static let plainStrip: CGFloat = 26

    private static func p(_ id: String, _ name: String, _ g: Group, _ w: CGFloat, _ h: CGFloat, _ s: CGFloat, _ strip: CGFloat) -> DisplayPreset {
        DisplayPreset(id: id, name: name, group: g, pointSize: CGSize(width: w, height: h), scale: s, topStripPt: strip)
    }

    /// Default "looks like" modes as of October 2026.
    public static let all: [DisplayPreset] = [
        // Apple notebooks & iMac
        p("mbp14", "MacBook Pro 14″ (notch)", .appleBuiltIn, 1512, 982, 2, notchStrip),
        p("mbp16", "MacBook Pro 16″ (notch)", .appleBuiltIn, 1728, 1117, 2, notchStrip),
        p("mba13", "MacBook Air 13″ M2–M4 (notch)", .appleBuiltIn, 1470, 956, 2, notchStrip),
        p("mba15", "MacBook Air 15″ (notch)", .appleBuiltIn, 1710, 1112, 2, notchStrip),
        p("mba13m1", "MacBook Air 13″ M1 / Pro 13″", .appleBuiltIn, 1440, 900, 2, plainStrip),
        p("imac24", "iMac 24″", .appleBuiltIn, 2240, 1260, 2, plainStrip),
        // Apple displays
        p("studio", "Studio Display 27″", .appleExternal, 2560, 1440, 2, plainStrip),
        p("xdr", "Pro Display XDR 32″", .appleExternal, 3008, 1692, 2, plainStrip),
        // Common monitors
        p("1080p", "1080p · 1920×1080", .monitors, 1920, 1080, 1, plainStrip),
        p("1200p", "WUXGA · 1920×1200", .monitors, 1920, 1200, 1, plainStrip),
        p("1440p", "QHD 1440p · 2560×1440", .monitors, 2560, 1440, 1, plainStrip),
        p("1600p", "WQXGA · 2560×1600", .monitors, 2560, 1600, 1, plainStrip),
        p("4k2x", "4K UHD @2x (looks like 1920×1080)", .monitors, 1920, 1080, 2, plainStrip),
        p("4kscaled", "4K UHD scaled (looks like 2560×1440)", .monitors, 2560, 1440, 2, plainStrip),
        p("4k1x", "4K UHD @1x · 3840×2160", .monitors, 3840, 2160, 1, plainStrip),
        p("5k", "5K @2x · 5120×2880", .monitors, 2560, 1440, 2, plainStrip),
        p("uw3440", "Ultrawide 21:9 · 3440×1440", .monitors, 3440, 1440, 1, plainStrip),
        p("uw3840", "Ultrawide 24:10 · 3840×1600", .monitors, 3840, 1600, 1, plainStrip),
        p("5k2k", "5K2K ultrawide @2x · 5120×2160", .monitors, 2560, 1080, 2, plainStrip),
        p("suw", "Super ultrawide 32:9 · 5120×1440", .monitors, 5120, 1440, 1, plainStrip),
    ]

    public static func spec(for preset: DisplayPreset, topStripPt: CGFloat, cornerRadiusPt: CGFloat, scaleMode: ScaleMode) -> MaskSpec {
        let s = preset.scale
        let px = preset.pixelSize
        return MaskSpec(
            screenPx: px,
            windowRectPx: CGRect(x: 0, y: topStripPt * s, width: px.width, height: px.height - topStripPt * s),
            cornerRadiusPx: cornerRadiusPt * s,
            scaleMode: scaleMode
        )
    }
}
