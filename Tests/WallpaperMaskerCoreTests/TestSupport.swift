import CoreGraphics
import XCTest
@testable import WallpaperMaskerCore

/// The 14" MacBook Pro geometry measured during development: 3024×1964 px, a 68px strip above
/// the zoomed window, 32px (16pt @2x) corner radius. Built by hand so tests need no display.
func mbp14Spec() -> MaskSpec {
    MaskSpec(screenPx: CGSize(width: 3024, height: 1964),
             windowRectPx: CGRect(x: 0, y: 68, width: 3024, height: 1896),
             cornerRadiusPx: 32)
}

func solidWhite(_ w: Int, _ h: Int) -> CGImage {
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.setFillColor(.white)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    return ctx.makeImage()!
}

/// 8px black / 8px white vertical stripes: a blur turns it mid-grey, no blur keeps it binary.
func stripes(_ w: Int, _ h: Int) -> CGImage {
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.setFillColor(.white)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    ctx.setFillColor(.black)
    for x in stride(from: 0, to: w, by: 16) { ctx.fill(CGRect(x: x, y: 0, width: 8, height: h)) }
    return ctx.makeImage()!
}

struct Pixel: Equatable, CustomStringConvertible {
    let r: Int, g: Int, b: Int
    var lum: Int { (r + g + b) / 3 }
    var description: String { "(\(r),\(g),\(b))" }
    static let black = Pixel(r: 0, g: 0, b: 0)
    static let white = Pixel(r: 255, g: 255, b: 255)
}

/// Reads an 8-bit RGB(A) pixel; `y` counts from the top.
func pixel(_ img: CGImage, _ x: Int, _ y: Int) -> Pixel {
    let data = img.dataProvider!.data! as Data
    let i = y * img.bytesPerRow + x * (img.bitsPerPixel / 8)
    return Pixel(r: Int(data[i]), g: Int(data[i + 1]), b: Int(data[i + 2]))
}

func near(_ a: Int, _ b: Int, _ tolerance: Int = 6) -> Bool { abs(a - b) <= tolerance }
