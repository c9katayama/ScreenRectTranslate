import ApplicationServices
import AppKit
import Foundation

enum PermissionKind: String {
    case screenRecording
    case accessibility
}

enum PermissionSupport {
    static func hasScreenRecordingAccess() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// システムダイアログを出す。拒否された場合は設定アプリへの誘導が必要。
    @discardableResult
    static func requestScreenRecordingAccess() -> Bool {
        let granted = CGRequestScreenCaptureAccess()
        AppLog.permission.info("CGRequestScreenCaptureAccess -> \(granted)")
        return granted
    }

    static func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    /// プロンプト付きでアクセシビリティ信頼状態を確認する。
    @discardableResult
    static func promptAccessibilityIfNeeded() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        AppLog.permission.info("AXIsProcessTrustedWithOptions -> \(trusted)")
        return trusted
    }

    static func openScreenRecordingSettings() {
        openFirstAvailable([
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.Settings.PrivacySecurity?Privacy_ScreenCapture"
        ])
    }

    static func openAccessibilitySettings() {
        openFirstAvailable([
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.Settings.PrivacySecurity?Privacy_Accessibility"
        ])
    }

    private static func openFirstAvailable(_ rawURLs: [String]) {
        for raw in rawURLs {
            guard let url = URL(string: raw) else { continue }
            if NSWorkspace.shared.open(url) {
                AppLog.permission.info("Opened System Settings: \(raw, privacy: .public)")
                return
            }
            AppLog.permission.error("Failed to open System Settings URL: \(raw, privacy: .public)")
        }
    }

    static func japaneseSummary() -> String {
        let screen = hasScreenRecordingAccess() ? "許可済み" : "未許可"
        let ax = isAccessibilityTrusted() ? "許可済み" : "未許可"
        return "画面収録: \(screen)\nアクセシビリティ: \(ax)"
    }
}
