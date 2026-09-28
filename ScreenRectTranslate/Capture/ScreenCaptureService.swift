import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit

enum ScreenCaptureError: LocalizedError {
    case noDisplay
    case permissionDenied
    case emptyImage
    case captureFailed(String)

    var errorDescription: String? {
        switch self {
        case .noDisplay:
            return "選択範囲に対応するディスプレイが見つかりませんでした。"
        case .permissionDenied:
            return "画面収録の権限がありません。システム設定で ScreenRectTranslate を許可してから、アプリを再起動してください。"
        case .emptyImage:
            return "画面の取り込み結果が空でした。DRM 保護された画面や、権限が不足している可能性があります。"
        case .captureFailed(let detail):
            return "画面の取り込みに失敗しました。\(detail)"
        }
    }
}

/// 選択範囲の画面取り込み。ScreenCaptureKit を優先し、失敗時は CGWindowListCreateImage に倒す。
final class ScreenCaptureService: Sendable {
    func capture(rectInAppKitPoints rect: CGRect) async throws -> CGImage {
        guard let screen = ScreenGeometry.screen(containing: rect) else {
            throw ScreenCaptureError.noDisplay
        }
        if !PermissionSupport.hasScreenRecordingAccess() {
            AppLog.capture.error("Screen recording permission is not granted")
            throw ScreenCaptureError.permissionDenied
        }

        do {
            let image = try await captureWithScreenCaptureKit(rect: rect, screen: screen)
            AppLog.capture.info("Captured via ScreenCaptureKit \(image.width)x\(image.height)")
            return image
        } catch {
            AppLog.capture.error("ScreenCaptureKit failed: \(error.localizedDescription, privacy: .public). Falling back to CGWindowListCreateImage.")
            if let image = captureWithCGWindowList(rect: rect) {
                AppLog.capture.info("Captured via CGWindowListCreateImage \(image.width)x\(image.height)")
                return image
            }
            throw error
        }
    }

    private func captureWithScreenCaptureKit(rect: CGRect, screen: NSScreen) async throws -> CGImage {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            AppLog.capture.error("SCShareableContent failed: \(error.localizedDescription, privacy: .public)")
            throw ScreenCaptureError.captureFailed(error.localizedDescription)
        }

        guard let displayID = ScreenGeometry.displayID(of: screen),
              let display = content.displays.first(where: { $0.displayID == displayID })
        else {
            throw ScreenCaptureError.noDisplay
        }

        let clipped = rect.intersection(screen.frame)
        let sourceRect = ScreenGeometry.screenCaptureKitSourceRect(
            appKitRect: clipped,
            displayFrameAppKit: screen.frame
        )
        let pixels = ScreenGeometry.pixelSize(pointSize: clipped.size, scale: screen.backingScaleFactor)

        let configuration = SCStreamConfiguration()
        configuration.sourceRect = sourceRect
        configuration.width = Int(pixels.width)
        configuration.height = Int(pixels.height)
        configuration.showsCursor = false
        configuration.scalesToFit = false
        configuration.capturesAudio = false
        configuration.colorSpaceName = CGColorSpace.sRGB

        let filter = SCContentFilter(display: display, excludingWindows: [])
        do {
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            if image.width == 0 || image.height == 0 {
                throw ScreenCaptureError.emptyImage
            }
            return image
        } catch let error as ScreenCaptureError {
            throw error
        } catch {
            AppLog.capture.error("SCScreenshotManager.captureImage failed: \(error.localizedDescription, privacy: .public)")
            throw ScreenCaptureError.captureFailed(error.localizedDescription)
        }
    }

    private func captureWithCGWindowList(rect: CGRect) -> CGImage? {
        let mainHeight = ScreenGeometry.mainDisplayHeight()
        let cgRect = ScreenGeometry.cgWindowListRect(appKitRect: rect, mainDisplayHeight: mainHeight)
        guard let image = CGWindowListCreateImage(
            cgRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            AppLog.capture.error("CGWindowListCreateImage returned nil for \(String(describing: cgRect), privacy: .public)")
            return nil
        }
        if image.width == 0 || image.height == 0 {
            AppLog.capture.error("CGWindowListCreateImage returned an empty image")
            return nil
        }
        return image
    }
}
