import AppKit
import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var translation: TranslationService
    @State private var isRecordingHotkey = false
    @State private var recorderError: String?

    var body: some View {
        Form {
            Section("ショートカット") {
                HStack {
                    Text("範囲選択")
                    Spacer()
                    Text(settings.combo.displayString)
                        .font(.body.monospaced())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                HStack {
                    Button(isRecordingHotkey ? "キーを押してください…" : "ショートカットを変更") {
                        isRecordingHotkey = true
                        recorderError = nil
                    }
                    .keyboardShortcut("r", modifiers: [.command])
                    Button("デフォルトに戻す") {
                        settings.resetHotkey()
                        isRecordingHotkey = false
                    }
                }
                if let recorderError {
                    Text(recorderError)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
                Text("初期値は ⌥⇧T です。修飾キー（⌘⌥⌃⇧）を1つ以上含めてください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("権限") {
                Text(PermissionSupport.japaneseSummary())
                    .font(.callout)
                HStack {
                    Button("画面収録を開く") {
                        PermissionSupport.requestScreenRecordingAccess()
                        PermissionSupport.openScreenRecordingSettings()
                    }
                    Button("アクセシビリティを開く") {
                        PermissionSupport.promptAccessibilityIfNeeded()
                        PermissionSupport.openAccessibilitySettings()
                    }
                }
                Text("設定を変更したあとは、このアプリを再起動してください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("翻訳言語（英語 → 日本語）") {
                Text(translation.availabilityMessage)
                    .font(.callout)
                HStack {
                    Button("状態を再確認") {
                        Task { await translation.refreshAvailability() }
                    }
                    Button("翻訳言語を準備") {
                        translation.prepareLanguages()
                    }
                }
                Text("初回はシステムが言語データをダウンロードします。ダウンロード中は翻訳できません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 460)
        .onAppear {
            Task { await translation.refreshAvailability() }
        }
        .background(HotkeyRecorderRepresentable(isRecording: $isRecordingHotkey) { combo in
            guard combo.carbonModifiers != 0 else {
                recorderError = "修飾キー（⌘ / ⌥ / ⌃ / ⇧）を1つ以上含めてください。"
                return
            }
            settings.apply(combo: combo)
            isRecordingHotkey = false
            recorderError = nil
        })
    }
}

/// 次のキー入力をホットキーとして受け取る。
private struct HotkeyRecorderRepresentable: NSViewRepresentable {
    @Binding var isRecording: Bool
    var onCapture: (HotkeyCombo) -> Void

    func makeNSView(context: Context) -> HotkeyRecorderView {
        let view = HotkeyRecorderView()
        view.onCapture = onCapture
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderView, context: Context) {
        nsView.onCapture = onCapture
        nsView.isRecording = isRecording
    }
}

final class HotkeyRecorderView: NSView {
    var isRecording = false
    var onCapture: ((HotkeyCombo) -> Void)?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.isRecording else { return event }
                if event.keyCode == 53 {
                    self.isRecording = false
                    return nil
                }
                let modifiers = HotkeyCombo.carbonModifiers(from: event.modifierFlags)
                let combo = HotkeyCombo(keyCode: UInt32(event.keyCode), carbonModifiers: modifiers)
                self.onCapture?(combo)
                return nil
            }
        }
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
