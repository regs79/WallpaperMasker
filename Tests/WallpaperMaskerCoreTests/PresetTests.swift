import XCTest
@testable import WallpaperMaskerCore

final class PresetTests: XCTestCase {
    func testMacBookPro14PresetMatchesMeasuredGeometry() throws {
        let preset = try XCTUnwrap(DisplayPreset.all.first { $0.id == "mbp14" })
        let spec = DisplayPreset.spec(for: preset, topStripPt: preset.topStripPt, cornerRadiusPt: 16, scaleMode: .fill)
        XCTAssertEqual(spec, mbp14Spec())
    }

    func test1080pPresetOnA4KImage() throws {
        let preset = try XCTUnwrap(DisplayPreset.all.first { $0.id == "1080p" })
        let spec = DisplayPreset.spec(for: preset, topStripPt: preset.topStripPt, cornerRadiusPt: 16, scaleMode: .fill)
        let (rect, r) = MaskRenderer.windowRectInImage(imageSize: CGSize(width: 3840, height: 2160), spec: spec)
        XCTAssertEqual(rect, CGRect(x: 0, y: 52, width: 3840, height: 2108), "26pt strip on 1080pt → 52px on 2160px")
        XCTAssertEqual(r, 32, "16pt radius → 32px on a 2x-scaled image")
    }

    func testStripOverrideMovesOnlyTheTopEdge() throws {
        let preset = try XCTUnwrap(DisplayPreset.all.first { $0.id == "mbp14" })
        let base = DisplayPreset.spec(for: preset, topStripPt: 34, cornerRadiusPt: 16, scaleMode: .fill)
        let taller = DisplayPreset.spec(for: preset, topStripPt: 40, cornerRadiusPt: 16, scaleMode: .fill)
        XCTAssertEqual(taller.windowRectPx.minY, 80)
        XCTAssertEqual(taller.windowRectPx.maxY, base.windowRectPx.maxY)
    }

    func testPresetTableSanity() {
        XCTAssertEqual(DisplayPreset.all.count, 20)
        XCTAssertEqual(Set(DisplayPreset.all.map(\.id)).count, DisplayPreset.all.count, "ids unique")
        for p in DisplayPreset.all {
            XCTAssertGreaterThan(p.pointSize.width, 0, p.id)
            XCTAssertGreaterThan(p.pointSize.height, 0, p.id)
            XCTAssertTrue([DisplayPreset.notchStrip, DisplayPreset.plainStrip].contains(p.topStripPt), p.id)
        }
    }

    func testFitAndStretchMapping() {
        var spec = mbp14Spec()
        spec.scaleMode = .stretch
        let stretched = MaskRenderer.windowRectInImage(imageSize: CGSize(width: 1000, height: 1000), spec: spec)
        XCTAssertEqual(stretched.rect, CGRect(x: 0, y: 35, width: 1000, height: 965), "68/1964 of 1000 rows ≈ 35")

        spec.scaleMode = .fit
        let fitted = MaskRenderer.windowRectInImage(imageSize: CGSize(width: 1000, height: 1000), spec: spec)
        // Fit: image height fills the screen height; screen is wider than the image, so the window
        // rect extends beyond the image horizontally and the strip is 68/1964 of the height.
        XCTAssertEqual(fitted.rect.minY, 35)
        XCTAssertLessThan(fitted.rect.minX, 0)
    }
}
