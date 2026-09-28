import AppKit
import SwiftUI

enum PermissionGuideFocus: Equatable {
    case general
    case screenRecording
    case accessibility
}

@MainActor
final class PermissionGuideController {
    private var window: NSWindow?

    func show(focus: PermissionGuideFocus) {
        let view = PermissionGuideView(focus: focus) { [weak self] in
            self?.window?.orderOut(nil)
        }
        let hosting = NSHostingController(rootView: view)
        let window = self.window ?? NSWindow(contentViewController: hosting)
        window.contentViewController = hosting
        window.title = "権限の確認"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 480, height: 420))
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        self.window = window
        AppLog.permission.info("Permission guide shown (\(String(describing: focus), privacy: .public))")
    }
}

struct PermissionGuideView: View {
    let focus: PermissionGuideFocus
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ScreenRectTranslate の権限")
                .font(.title2.weight(.semibold))
            Text(headline)
                .font(.body)
            GroupBox("いまの状態") {
                Text(PermissionSupport.japaneseSummary())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
            }
            permissionRow(
                title: "画面収録",
                detail: "選択した範囲の画像を取り込むために必要です。許可したあとはアプリを再起動してください。",
                actionTitle: "画面収録の設定を開く"
            ) {
                PermissionSupport.requestScreenRecordingAccess()
                PermissionSupport.openScreenRecordingSettings()
            }
            permissionRow(
                title: "アクセシビリティ",
                detail: "ホットキー自体は Carbon で登録します。クリック外で結果パネルを閉じるなど、一部操作で必要になることがあります。",
                actionTitle: "アクセシビリティの設定を開く"
            ) {
                PermissionSupport.promptAccessibilityIfNeeded()
                PermissionSupport.openAccessibilitySettings()
            }
            HStack {
                Spacer()
                Button("閉じる", action: onClose)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    private var headline: String {
        switch focus {
        case .screenRecording:
            return "画面収録がオフのため、選択範囲を取り込めません。システム設定で ScreenRectTranslate を許可してください。"
        case .accessibility:
            return "アクセシビリティがオフです。グローバル操作が不安定なときは許可してください。"
        case .general:
            return "このアプリはメニューバー常駐です。画面収録と（推奨）アクセシビリティを許可すると、ホットキーから範囲選択→OCR→翻訳が使えます。"
        }
    }

    private func permissionRow(title: String, detail: String, actionTitle: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
            Button(actionTitle, action: action)
        }
    }
}
