import XCTest
@testable import WallpaperMaskerCore

/// Fill mode crops a wider-than-screen image; the cropped columns are never visible but must not
/// be left as raw wallpaper or a hairline shows in the file (and once did in the preview).
final class MarginTests: XCTestCase {
    let size = CGSize(width: 6016, height: 3900)

    func testVisibleRectIsCentredScreenArea() {
        XCTAssertEqual(MaskRenderer.visibleRect(imageSize: size, spec: mbp14Spec()),
                       CGRect(x: 6, y: 0, width: 6005, height: 3900))
        XCTAssertEqual(MaskRenderer.visibleRect(imageSize: CGSize(width: 3024, height: 1964), spec: mbp14Spec()),
                       CGRect(x: 0, y: 0, width: 3024, height: 1964), "native size has no margins")
    }

    func testMarginsPaintedLikeStrip() throws {
        let m = try MaskRenderer.render(source: solidWhite(6016, 3900), spec: mbp14Spec())
        XCTAssertEqual(pixel(m, 0, 1950), .black, "left margin")
        XCTAssertEqual(pixel(m, 5, 1950), .black, "last left-margin column")
        XCTAssertEqual(pixel(m, 6, 1950), .white, "first on-screen column untouched")
        XCTAssertEqual(pixel(m, 6010, 1950), .white, "last on-screen column untouched")
        XCTAssertEqual(pixel(m, 6011, 1950), .black, "first right-margin column")
        XCTAssertEqual(pixel(m, 6015, 1950), .black, "right margin")
    }

    func testMarginsFollowWhicheverRegionIsOn() throws {
        var spec = mbp14Spec()
        spec.maskMenuBar = false
        spec.cornerStyle = RegionStyle(color: RGBA(r: 0, g: 0, b: 1))
        let cornersOnly = try MaskRenderer.render(source: solidWhite(6016, 3900), spec: spec)
        XCTAssertEqual(pixel(cornersOnly, 0, 1950), Pixel(r: 0, g: 0, b: 255), "corners only → margin uses corner colour")
        XCTAssertEqual(pixel(cornersOnly, 3008, 10), .white, "strip untouched")

        spec.maskMenuBar = true
        spec.maskCorners = false
        spec.menuBarStyle = RegionStyle(color: RGBA(r: 1, g: 0, b: 0))
        let barOnly = try MaskRenderer.render(source: solidWhite(6016, 3900), spec: spec)
        XCTAssertEqual(pixel(barOnly, 0, 3899), Pixel(r: 255, g: 0, b: 0), "bar only → margin uses strip colour")
        XCTAssertEqual(pixel(barOnly, 6, 3899), .white, "corner wedge untouched")
    }

    func testNativeSizeLeavesEdgesAlone() throws {
        var spec = mbp14Spec()
        spec.maskCorners = false
        let m = try MaskRenderer.render(source: solidWhite(3024, 1964), spec: spec)
        XCTAssertEqual(pixel(m, 0, 1000), .white)
        XCTAssertEqual(pixel(m, 3023, 1000), .white)
    }
}
