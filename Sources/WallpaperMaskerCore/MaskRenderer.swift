import CoreGraphics
import CoreImage
import Foundation

/// Pure image → image transform: paints over every part of the wallpaper that
/// would be visible around a maximised window.
public enum MaskRenderer {
    public enum RenderError: Error, LocalizedError {
        case contextFailed
        public var errorDescription: String? { "Could not create a drawing context for this image." }
    }

    /// How the screen maps onto the image: the window rounded-rect in *image pixel*
    /// coordinates (origin top-left) and the number of screen pixels per image pixel.
    public struct Mapping {
        public var rect: CGRect
        public var radius: CGFloat
        /// Screen px per image px (max of the two axes, so blur/radius use the tighter axis).
        public var screenPxPerImagePx: CGFloat
        /// The whole screen in image coordinates. In Fill mode this is inset from the image (the
        /// crop margins outside it are never shown); in Fit mode it extends beyond the image.
        public var screenRect: CGRect
    }

    public static func mapping(imageSize: CGSize, spec: MaskSpec) -> Mapping {
        let sx = spec.screenPx.width / imageSize.width   // screen px per image px, horizontally
        let sy = spec.screenPx.height / imageSize.height

        // f = how many screen px one image px becomes. Fill = cover, Fit = contain.
        let fx: CGFloat, fy: CGFloat
        switch spec.scaleMode {
        case .fill:    let f = max(sx, sy); fx = f; fy = f
        case .fit:     let f = min(sx, sy); fx = f; fy = f
        case .stretch: fx = sx; fy = sy
        }

        // The screen, mapped into image space, is centred on the image.
        let screenW = spec.screenPx.width / fx
        let screenH = spec.screenPx.height / fy
        let originX = (imageSize.width - screenW) / 2
        let originY = (imageSize.height - screenH) / 2

        let exact = CGRect(
            x: originX + spec.windowRectPx.minX / fx,
            y: originY + spec.windowRectPx.minY / fy,
            width: spec.windowRectPx.width / fx,
            height: spec.windowRectPx.height / fy
        )
        // Snap to whole pixels so straight edges never anti-alias (and the menu-bar strip and
        // corner wedges meet seamlessly); only the arcs are anti-aliased.
        let rect = CGRect(x: exact.minX.rounded(), y: exact.minY.rounded(),
                          width: exact.width.rounded(), height: exact.height.rounded())
        let f = max(fx, fy)
        let screenExact = CGRect(x: originX, y: originY, width: screenW, height: screenH)
        let screenRect = CGRect(x: screenExact.minX.rounded(), y: screenExact.minY.rounded(),
                                width: screenExact.width.rounded(), height: screenExact.height.rounded())
        return Mapping(rect: rect, radius: (spec.cornerRadiusPx / f).rounded(.up),
                       screenPxPerImagePx: f, screenRect: screenRect)
    }

    /// The part of the rendered image that actually appears on screen (Fill mode crops the rest).
    public static func visibleRect(imageSize: CGSize, spec: MaskSpec) -> CGRect {
        mapping(imageSize: imageSize, spec: spec).screenRect.intersection(CGRect(origin: .zero, size: imageSize))
    }

    public static func windowRectInImage(imageSize: CGSize, spec: MaskSpec) -> (rect: CGRect, radius: CGFloat) {
        let m = mapping(imageSize: imageSize, spec: spec)
        return (m.rect, m.radius)
    }

    public static func render(source: CGImage, spec: MaskSpec) throws -> CGImage {
        let w = source.width, h = source.height
        let imageSize = CGSize(width: w, height: h)
        let map = mapping(imageSize: imageSize, spec: spec)
        let window = map.rect, radius = map.radius

        let colorSpace = source.colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? CGColorSpace(name: CGColorSpace.sRGB)!
        let deep = source.bitsPerComponent > 8
        let bitsPerComponent = deep ? 16 : 8
        let bitmapInfo: UInt32 = deep
            ? CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder16Little.rawValue
            : CGImageAlphaInfo.premultipliedLast.rawValue

        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: bitsPerComponent,
                                  bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo) else {
            throw RenderError.contextFailed
        }

        let full = CGRect(origin: .zero, size: imageSize)
        ctx.draw(source, in: full)

        // One blurred copy serves every frosted region (they share a blur radius in the UI, but
        // cache per radius anyway so differing radii still work).
        var blurCache: [CGFloat: CGImage] = [:]
        func blurred(_ blurPx: CGFloat) -> CGImage? {
            let sigma = blurPx / map.screenPxPerImagePx
            if let hit = blurCache[sigma] { return hit }
            guard let out = gaussianBlur(source, sigma: sigma) else { return nil }
            blurCache[sigma] = out
            return out
        }

        // Core Graphics contexts are bottom-left origin; flip so our top-left rects apply directly.
        ctx.translateBy(x: 0, y: imageSize.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.setShouldAntialias(true)

        /// Paints `style` inside whatever clip `clip` installs.
        func paint(_ style: RegionStyle, clip: (CGContext) -> Void) {
            ctx.saveGState()
            clip(ctx)
            if style.isFrosted, let img = blurred(style.blurPx) {
                // Un-flip for the image draw; `full` is symmetric so the clip still applies.
                ctx.saveGState()
                ctx.translateBy(x: 0, y: imageSize.height)
                ctx.scaleBy(x: 1, y: -1)
                ctx.draw(img, in: full)
                ctx.restoreGState()
            }
            if style.color.a > 0 {
                ctx.setFillColor(style.color.cgColor)
                ctx.fill(full)
            }
            ctx.restoreGState()
        }

        if spec.maskMenuBar, window.minY > 0 {
            // Everything above the window, full image width (crop margins are invisible anyway).
            paint(spec.menuBarStyle) { c in
                c.clip(to: CGRect(x: 0, y: 0, width: imageSize.width, height: window.minY))
            }
        }

        // Fill-mode crop margins (columns/rows outside the screen) are never visible on screen, but
        // leaving them unpainted shows a hairline of wallpaper in the file. Paint them like the strip.
        let margins = full.subtracting(map.screenRect)
        if let style = spec.maskMenuBar ? spec.menuBarStyle : (spec.maskCorners ? spec.cornerStyle : nil),
           !margins.isEmpty {
            paint(style) { c in c.clip(to: margins) }
        }

        if spec.maskCorners, radius > 0 {
            // Four r×r squares at the window's corners minus the rounded rect = the four wedges.
            let r = min(radius, window.width / 2, window.height / 2)
            paint(spec.cornerStyle) { c in
                c.clip(to: [
                    CGRect(x: window.minX, y: window.minY, width: r, height: r),
                    CGRect(x: window.maxX - r, y: window.minY, width: r, height: r),
                    CGRect(x: window.minX, y: window.maxY - r, width: r, height: r),
                    CGRect(x: window.maxX - r, y: window.maxY - r, width: r, height: r),
                ])
                let path = CGMutablePath()
                path.addRect(window)
                path.addRoundedRect(in: window, cornerWidth: r, cornerHeight: r)
                c.addPath(path)
                c.clip(using: .evenOdd)
            }
        }

        guard let out = ctx.makeImage() else { throw RenderError.contextFailed }
        return out
    }

}

private extension CGRect {
    /// The up-to-four rectangles of `self` that lie outside `other` (empty if `other` covers `self`).
    func subtracting(_ other: CGRect) -> [CGRect] {
        let inner = intersection(other)
        guard !inner.isEmpty, inner != self else { return inner.isEmpty ? [self] : [] }
        var parts: [CGRect] = []
        if inner.minY > minY { parts.append(CGRect(x: minX, y: minY, width: width, height: inner.minY - minY)) }
        if inner.maxY < maxY { parts.append(CGRect(x: minX, y: inner.maxY, width: width, height: maxY - inner.maxY)) }
        if inner.minX > minX { parts.append(CGRect(x: minX, y: inner.minY, width: inner.minX - minX, height: inner.height)) }
        if inner.maxX < maxX { parts.append(CGRect(x: inner.maxX, y: inner.minY, width: maxX - inner.maxX, height: inner.height)) }
        return parts
    }
}

extension MaskRenderer {
    private static let ciContext = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])

    /// Gaussian blur that extends edge pixels instead of fading to transparent at the borders.
    public static func gaussianBlur(_ image: CGImage, sigma: CGFloat) -> CGImage? {
        guard sigma > 0 else { return image }
        let ci = CIImage(cgImage: image)
        let out = ci.clampedToExtent()
            .applyingGaussianBlur(sigma: Double(sigma))
            .cropped(to: ci.extent)
        return ciContext.createCGImage(out, from: ci.extent)
    }
}
