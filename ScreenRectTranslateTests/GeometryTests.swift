import XCTest
@testable import ScreenRectTranslate

/// 論理ポイント（AppKit 左下原点）とピクセル／SCK／CGWindow 座標の変換を検証する。
final class GeometryTests: XCTestCase {
    /// メインディスプレイ上の選択範囲が、ScreenCaptureKit の左上原点 sourceRect になること。
    func testScreenCaptureKitSourceRectFlipsYOnMainDisplay() {
        let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let selection = CGRect(x: 100, y: 200, width: 50, height: 40)

        let source = ScreenGeometry.screenCaptureKitSourceRect(
            appKitRect: selection,
            displayFrameAppKit: display
        )

        XCTAssertEqual(source.origin.x, 100, accuracy: 0.001)
        XCTAssertEqual(source.origin.y, 660, accuracy: 0.001)
        XCTAssertEqual(source.width, 50, accuracy: 0.001)
        XCTAssertEqual(source.height, 40, accuracy: 0.001)
    }

    /// 右隣の外部ディスプレイ上の選択範囲が、そのディスプレイ局所座標になること。
    func testScreenCaptureKitSourceRectOnSecondaryDisplay() {
        let display = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        let selection = CGRect(x: 1500, y: 100, width: 80, height: 60)

        let source = ScreenGeometry.screenCaptureKitSourceRect(
            appKitRect: selection,
            displayFrameAppKit: display
        )

        XCTAssertEqual(source.origin.x, 60, accuracy: 0.001)
        XCTAssertEqual(source.origin.y, 920, accuracy: 0.001)
        XCTAssertEqual(source.width, 80, accuracy: 0.001)
        XCTAssertEqual(source.height, 60, accuracy: 0.001)
    }

    /// CGWindowListCreateImage はメインディスプレイ左上原点なので Y が反転すること。
    func testCGWindowListRectFlipsAgainstMainDisplayHeight() {
        let selection = CGRect(x: 100, y: 200, width: 50, height: 40)
        let cgRect = ScreenGeometry.cgWindowListRect(appKitRect: selection, mainDisplayHeight: 900)

        XCTAssertEqual(cgRect.origin.x, 100, accuracy: 0.001)
        XCTAssertEqual(cgRect.origin.y, 660, accuracy: 0.001)
        XCTAssertEqual(cgRect.width, 50, accuracy: 0.001)
        XCTAssertEqual(cgRect.height, 40, accuracy: 0.001)
    }

    /// Retina（scale=2）では出力ピクセルが論理サイズの2倍に丸められること。
    func testPixelSizeRoundsRetinaScale() {
        let pixels = ScreenGeometry.pixelSize(pointSize: CGSize(width: 120.4, height: 80.6), scale: 2)
        XCTAssertEqual(pixels.width, 241, accuracy: 0.001)
        XCTAssertEqual(pixels.height, 161, accuracy: 0.001)
    }

    /// ディスプレイと交差しない矩形は空の sourceRect になること。
    func testNonIntersectingRectIsZero() {
        let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let selection = CGRect(x: 2000, y: 2000, width: 50, height: 40)
        let source = ScreenGeometry.screenCaptureKitSourceRect(
            appKitRect: selection,
            displayFrameAppKit: display
        )
        XCTAssertEqual(source, .zero)
    }
}
