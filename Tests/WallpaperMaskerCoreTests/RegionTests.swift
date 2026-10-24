import XCTest
@testable import WallpaperMaskerCore

final class RegionTests: XCTestCase {
    /// Runs the geometry checks for one region combination on one image size.
    private func assertRegions(width w: Int, height h: Int, menuBar: Bool, corners: Bool,
                               file: StaticString = #filePath, line: UInt = #line) throws {
        var spec = mbp14Spec()
        spec.maskMenuBar = menuBar
        spec.maskCorners = corners
        let (rect, r) = MaskRenderer.windowRectInImage(imageSize: CGSize(width: w, height: h), spec: spec)
        let m = try MaskRenderer.render(source: solidWhite(w, h), spec: spec)

        let top = Int(rect.minY), rad = Int(r), cx = w / 2, bottom = h - 1
        let x0 = Int(rect.minX), x1 = Int(rect.maxX) - 1
        let B = menuBar ? 0 : 255, C = corners ? 0 : 255
        let label = "\(w)x\(h) bar=\(menuBar) corners=\(corners)"

        XCTAssertEqual(pixel(m, cx, 0).lum, B, "\(label): strip row 0", file: file, line: line)
        XCTAssertEqual(pixel(m, cx, top - 1).lum, B, "\(label): strip last row", file: file, line: line)
        XCTAssertEqual(pixel(m, cx, top).lum, 255, "\(label): first window row stays white", file: file, line: line)
        XCTAssertEqual(pixel(m, x0, top).lum, C, "\(label): top-left corner", file: file, line: line)
        XCTAssertEqual(pixel(m, x1, top).lum, C, "\(label): top-right corner", file: file, line: line)
        XCTAssertEqual(pixel(m, x0, bottom).lum, C, "\(label): bottom-left corner", file: file, line: line)
        XCTAssertEqual(pixel(m, x1, bottom).lum, C, "\(label): bottom-right corner", file: file, line: line)
        XCTAssertEqual(pixel(m, x0 + rad, top + rad).lum, 255, "\(label): inside TL arc white", file: file, line: line)
        XCTAssertEqual(pixel(m, x1 - rad, bottom - rad).lum, 255, "\(label): inside BR arc white", file: file, line: line)
        XCTAssertEqual(pixel(m, x0 + 1, h / 2).lum, 255, "\(label): left edge mid-height white", file: file, line: line)
        XCTAssertEqual(pixel(m, x0 + rad / 4, top + rad / 4).lum, C, "\(label): outside TL arc", file: file, line: line)
        XCTAssertEqual(pixel(m, x1 - rad / 4, bottom - rad / 4).lum, C, "\(label): outside BR arc", file: file, line: line)
        XCTAssertEqual(pixel(m, x0, top - 1).lum, B, "\(label): strip/wedge seam row", file: file, line: line)
    }

    func testMappingOnNativeAndOversizedImages() {
        let spec = mbp14Spec()
        let native = MaskRenderer.windowRectInImage(imageSize: CGSize(width: 3024, height: 1964), spec: spec)
        XCTAssertEqual(native.rect, CGRect(x: 0, y: 68, width: 3024, height: 1896))
        XCTAssertEqual(native.radius, 32)

        // 6016×3900 is slightly wider than 3024:1964, so Fill crops ~5.5px off each side.
        let big = MaskRenderer.windowRectInImage(imageSize: CGSize(width: 6016, height: 3900), spec: spec)
        XCTAssertEqual(big.rect, CGRect(x: 6, y: 135, width: 6005, height: 3765))
        XCTAssertEqual(big.radius, 64)
    }

    func testAllRegionCombinations() throws {
        for (w, h) in [(3024, 1964), (6016, 3900)] {
            try assertRegions(width: w, height: h, menuBar: true, corners: true)
            try assertRegions(width: w, height: h, menuBar: true, corners: false)
            try assertRegions(width: w, height: h, menuBar: false, corners: true)
        }
    }

    func testIndependentColours() throws {
        var spec = mbp14Spec()
        spec.menuBarColor = RGBA(r: 1, g: 0, b: 0)
        spec.cornerColor = RGBA(r: 0, g: 0, b: 1)
        let m = try MaskRenderer.render(source: solidWhite(3024, 1964), spec: spec)
        XCTAssertEqual(pixel(m, 1512, 34), Pixel(r: 255, g: 0, b: 0), "strip is red")
        XCTAssertEqual(pixel(m, 1, 1962), Pixel(r: 0, g: 0, b: 255), "corner wedge is blue")
        XCTAssertEqual(pixel(m, 0, 67), Pixel(r: 255, g: 0, b: 0), "row above the window is strip colour")
        XCTAssertEqual(pixel(m, 0, 68), Pixel(r: 0, g: 0, b: 255), "window's top-left pixel is corner colour")
    }

    func testOutputKeepsSizeAndDepth() throws {
        let m = try MaskRenderer.render(source: solidWhite(3024, 1964), spec: mbp14Spec())
        XCTAssertEqual(m.width, 3024)
        XCTAssertEqual(m.height, 1964)
        XCTAssertEqual(m.bitsPerComponent, 8)
    }
}
