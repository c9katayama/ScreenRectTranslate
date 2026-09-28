import AppKit
import CoreGraphics
import Foundation

enum ScreenGeometry {
    /// AppKit（左下原点・ポイント）の選択範囲を、指定ディスプレイ局所の ScreenCaptureKit `sourceRect`（左上原点・ポイント）へ変換する。
    static func screenCaptureKitSourceRect(
        appKitRect: CGRect,
        displayFrameAppKit: CGRect
    ) -> CGRect {
        let local = appKitRect.intersection(displayFrameAppKit)
        guard !local.isNull, !local.isEmpty else { return .zero }
        let localX = local.minX - displayFrameAppKit.minX
        let localYFromBottom = local.minY - displayFrameAppKit.minY
        let yFromTop = displayFrameAppKit.height - localYFromBottom - local.height
        return CGRect(x: localX, y: yFromTop, width: local.width, height: local.height)
    }

    /// AppKit 矩形を `CGWindowListCreateImage` 用（メインディスプレイ左上原点）へ変換する。
    static func cgWindowListRect(
        appKitRect: CGRect,
        mainDisplayHeight: CGFloat
    ) -> CGRect {
        CGRect(
            x: appKitRect.minX,
            y: mainDisplayHeight - appKitRect.minY - appKitRect.height,
            width: appKitRect.width,
            height: appKitRect.height
        )
    }

    static func pixelSize(pointSize: CGSize, scale: CGFloat) -> CGSize {
        CGSize(
            width: (pointSize.width * scale).rounded(),
            height: (pointSize.height * scale).rounded()
        )
    }

    static func screen(containing rect: CGRect) -> NSScreen? {
        let mid = CGPoint(x: rect.midX, y: rect.midY)
        if let exact = NSScreen.screens.first(where: { $0.frame.contains(mid) }) {
            return exact
        }
        return NSScreen.screens.max { lhs, rhs in
            lhs.frame.intersection(rect).area < rhs.frame.intersection(rect).area
        }
    }

    static func mainDisplayHeight() -> CGFloat {
        let main = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main
        return main?.frame.height ?? 0
    }

    static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}

extension CGRect {
    var area: CGFloat { max(0, width) * max(0, height) }
}
