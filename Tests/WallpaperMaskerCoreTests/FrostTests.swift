import XCTest
@testable import WallpaperMaskerCore

final class FrostTests: XCTestCase {
    func testFrostedStripAndMatchedCorners() throws {
        let (w, h) = (3024, 1964)
        var spec = mbp14Spec()
        // 24pt blur @2x = 48px sigma, 50% black tint: stripes average 127.5 → tinted ≈ 64.
        spec.menuBarStyle = RegionStyle(color: RGBA(r: 0, g: 0, b: 0, a: 0.5), blurPx: 48)
        spec.cornerStyle = spec.menuBarStyle  // "Match menu bar"
        let m = try MaskRenderer.render(source: stripes(w, h), spec: spec)
        let top = 68

        let strip = pixel(m, w / 2, top / 2).r, strip2 = pixel(m, w / 2 + 8, top / 2).r
        XCTAssertTrue(near(strip, 64) && near(strip2, 64), "frosted strip blurred to grey then tinted: \(strip), \(strip2)")
        XCTAssertTrue(near(strip, strip2, 2), "blur removed the stripes")

        // Wedges sit on the image edge where the clamped blur is darker; compare to the strip in the same column.
        XCTAssertTrue(near(pixel(m, 0, h - 1).r, pixel(m, 0, top / 2).r, 2), "bottom-left wedge matches strip in column 0")
        XCTAssertTrue(near(pixel(m, 0, top).r, pixel(m, 0, top / 2).r, 2), "top-left wedge matches strip in column 0")
        XCTAssertTrue(near(pixel(m, 4, top + 4).r, pixel(m, 4, top / 2).r, 2), "wedge interior matches strip in column 4")

        let inside = pixel(m, w / 2, h / 2).r, inside2 = pixel(m, w / 2 + 8, h / 2).r
        XCTAssertTrue((inside == 0 || inside == 255) && inside != inside2, "window interior still binary stripes")

        let below = pixel(m, w / 2, top).r, below2 = pixel(m, w / 2 + 8, top).r
        XCTAssertTrue(near(pixel(m, w / 2, top - 1).r, 64) && (below == 0 || below == 255) && below != below2,
                      "strip bottom edge is crisp")
    }

    func testTranslucentTintWithoutBlurKeepsStripes() throws {
        var spec = mbp14Spec()
        spec.menuBarStyle = RegionStyle(color: RGBA(r: 1, g: 0, b: 0, a: 0.5), blurPx: 0)
        spec.cornerStyle = RegionStyle()
        let m = try MaskRenderer.render(source: stripes(3024, 1964), spec: spec)
        let a = pixel(m, 4, 34), b = pixel(m, 12, 34)
        let pair = [a, b]
        XCTAssertTrue(pair.contains { near($0.r, 128) && $0.g == 0 && $0.b == 0 }, "black stripe → (128,0,0): \(pair)")
        XCTAssertTrue(pair.contains { $0.r == 255 && near($0.g, 128) && near($0.b, 128) }, "white stripe → (255,128,128): \(pair)")
        XCTAssertEqual(pixel(m, 0, 1963), .black, "independent corner style still solid black")
    }

    func testGaussianBlurOfSolidIsIdentity() {
        let blurred = MaskRenderer.gaussianBlur(solidWhite(400, 300), sigma: 20)!
        XCTAssertEqual(blurred.width, 400)
        XCTAssertEqual(blurred.height, 300)
        XCTAssertEqual(pixel(blurred, 0, 0), .white, "edge clamping keeps corners white")
        XCTAssertEqual(pixel(blurred, 200, 150), .white)
    }
}
