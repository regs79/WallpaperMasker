import AppKit

/// Reads the live geometry of an `NSScreen` and converts it into a `MaskSpec`.
public enum ScreenGeometry {
    /// Default window corner radius on macOS 26 (measured: `NSWindow._cornerRadius` = 16pt).
    public static let defaultCornerRadiusPt: CGFloat = 16

    /// Points between the top of the screen and the top of a zoomed window (menu bar + gap).
    public static func topStripPt(for screen: NSScreen) -> CGFloat {
        screen.frame.maxY - screen.visibleFrame.maxY
    }

    /// `topStripPt` overrides the measured strip when non-nil (user adjustment).
    public static func spec(for screen: NSScreen, topStripPt: CGFloat? = nil, cornerRadiusPt: CGFloat, scaleMode: ScaleMode) -> MaskSpec {
        let s = screen.backingScaleFactor
        let frame = screen.frame
        let visible = screen.visibleFrame // a zoomed window fills exactly this rect
        let strip = topStripPt ?? self.topStripPt(for: screen)

        // AppKit uses bottom-left origin; convert to top-left relative to the screen's own frame.
        let x = (visible.minX - frame.minX) * s
        let y = strip * s
        let w = visible.width * s
        let h = (visible.maxY - visible.minY) * s - (strip - self.topStripPt(for: screen)) * s

        return MaskSpec(
            screenPx: CGSize(width: frame.width * s, height: frame.height * s),
            windowRectPx: CGRect(x: x, y: y, width: w, height: h),
            cornerRadiusPx: cornerRadiusPt * s,
            scaleMode: scaleMode
        )
    }

    public static func name(of screen: NSScreen) -> String {
        let px = CGSize(width: screen.frame.width * screen.backingScaleFactor,
                        height: screen.frame.height * screen.backingScaleFactor)
        return "\(screen.localizedName) (\(Int(px.width))×\(Int(px.height)))"
    }
}
