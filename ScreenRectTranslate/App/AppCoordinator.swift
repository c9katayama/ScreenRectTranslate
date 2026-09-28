import AppKit
import Foundation

/// ホットキー以降の本流。Capture → OCR → Language → Translate → UI を順番に呼ぶ。
@MainActor
final class AppCoordinator {
    private let settings: AppSettings
    private let translation: TranslationService
    private let capture = ScreenCaptureService()
    private let ocr = OCRService()
    private let overlay = SelectionOverlayController()
    private let resultPanel: ResultPanelController
    private let permissionGuide = PermissionGuideController()
    private var isRunning = false

    init(settings: AppSettings, translation: TranslationService) {
        self.settings = settings
        self.translation = translation
        self.resultPanel = ResultPanelController(settings: settings, translation: translation)
    }

    func runFlow() {
        Task { await runFlowAsync() }
    }

    func showPermissions(focus: PermissionGuideFocus = .general) {
        permissionGuide.show(focus: focus)
    }

    func prepareTranslationLanguages() {
        translation.prepareLanguages()
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "翻訳言語を準備しています"
        alert.informativeText = "英語と日本語の言語データが未ダウンロードの場合、システムの許可ダイアログが出ます。完了後にもう一度範囲選択してください。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
        Task { await translation.refreshAvailability() }
    }

    private func runFlowAsync() async {
        guard !isRunning else {
            AppLog.flow.notice("Selection flow already running; ignoring hotkey")
            return
        }
        isRunning = true
        defer { isRunning = false }

        resultPanel.dismiss()
        AppLog.flow.info("Starting capture flow. hotkey=\(self.settings.combo.displayString, privacy: .public)")

        if !PermissionSupport.hasScreenRecordingAccess() {
            let granted = PermissionSupport.requestScreenRecordingAccess()
            if !granted && !PermissionSupport.hasScreenRecordingAccess() {
                AppLog.flow.error("Screen recording permission missing")
                permissionGuide.show(focus: .screenRecording)
                return
            }
        }

        guard let rect = await overlay.selectRectangle() else {
            AppLog.flow.info("Selection cancelled")
            return
        }

        do {
            AppLog.flow.info("Capturing selection")
            let image = try await capture.capture(rectInAppKitPoints: rect)
            AppLog.flow.info("Running Vision OCR")
            let ocrResult = try await ocr.recognize(image: image)
            let detection = LanguageDetector.analyze(ocrResult.text)
            resultPanel.showOCR(text: ocrResult.text, detection: detection, anchorRect: rect)
        } catch {
            AppLog.flow.error("Flow failed: \(error.localizedDescription, privacy: .public)")
            resultPanel.showError(error, anchorRect: rect)
        }
    }
}
