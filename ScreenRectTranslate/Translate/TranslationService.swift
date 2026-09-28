import Combine
import Foundation
import SwiftUI
import Translation

/// Apple Translation framework（`TranslationSession`）で英語→日本語をオンデバイス翻訳する。
/// セッション本体は SwiftUI の `.translationTask` から受け取る。
@MainActor
final class TranslationService: ObservableObject {
    enum Phase: Equatable {
        case idle
        case preparing
        case translating
        case done
        case skippedNoEnglish
        case failed
    }

    static let sourceLanguage = Locale.Language(identifier: "en")
    static let targetLanguage = Locale.Language(identifier: "ja")

    @Published var configuration: TranslationSession.Configuration?
    @Published var sourceText: String = ""
    @Published var translatedText: String = ""
    @Published var phase: Phase = .idle
    @Published var errorMessage: String?
    @Published var availabilityMessage: String = "言語データの状態を確認していません。"

    private var prepareOnly = false

    func reset() {
        configuration = nil
        sourceText = ""
        translatedText = ""
        phase = .idle
        errorMessage = nil
        prepareOnly = false
    }

    func skipBecauseNoEnglish() {
        configuration = nil
        translatedText = ""
        errorMessage = nil
        prepareOnly = false
        phase = .skippedNoEnglish
    }

    func startEnglishToJapanese(_ text: String) {
        sourceText = text
        translatedText = ""
        errorMessage = nil
        prepareOnly = false
        phase = .preparing
        applyConfiguration()
    }

    /// 初回の言語ダウンロードだけを行う。`prepareTranslation()` がシステムの許可 UI を出す。
    func prepareLanguages() {
        sourceText = ""
        translatedText = ""
        errorMessage = nil
        prepareOnly = true
        phase = .preparing
        applyConfiguration()
    }

    func refreshAvailability() async {
        let availability = LanguageAvailability()
        let status = await availability.status(from: Self.sourceLanguage, to: Self.targetLanguage)
        switch status {
        case .installed:
            availabilityMessage = "英語→日本語の言語データはインストール済みです。オンデバイスで翻訳できます。"
        case .supported:
            availabilityMessage = "英語→日本語は対応していますが、初回は言語データのダウンロードが必要です。「翻訳言語を準備」を押すか、最初の翻訳時にシステムの案内に従ってください。"
        case .unsupported:
            availabilityMessage = "この Mac では英語→日本語のオンデバイス翻訳がサポートされていません。"
        @unknown default:
            availabilityMessage = "言語データの状態を確認できませんでした。"
        }
        AppLog.translate.info("LanguageAvailability status=\(String(describing: status), privacy: .public)")
    }

    func perform(session: TranslationSession) async {
        do {
            phase = .preparing
            AppLog.translate.info("prepareTranslation en → ja")
            try await session.prepareTranslation()
            if prepareOnly || sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                AppLog.translate.info("Language assets prepared (no text to translate)")
                phase = .idle
                await refreshAvailability()
                return
            }
            phase = .translating
            AppLog.translate.info("translate \(self.sourceText.count) chars")
            let response = try await session.translate(sourceText)
            translatedText = response.targetText
            phase = .done
            AppLog.translate.info("Translation finished \(self.translatedText.count) chars")
        } catch is CancellationError {
            AppLog.translate.notice("Translation cancelled")
        } catch {
            AppLog.translate.error("Translation failed: \(error.localizedDescription, privacy: .public)")
            phase = .failed
            errorMessage = Self.japaneseMessage(for: error)
        }
    }

    private func applyConfiguration() {
        if var existing = configuration {
            existing.source = Self.sourceLanguage
            existing.target = Self.targetLanguage
            existing.invalidate()
            configuration = existing
        } else {
            configuration = TranslationSession.Configuration(
                source: Self.sourceLanguage,
                target: Self.targetLanguage
            )
        }
    }

    static func japaneseMessage(for error: Error) -> String {
        let detail = error.localizedDescription
        return "翻訳に失敗しました。\(detail) 初回は英語と日本語の言語データをシステムがダウンロードします。ネットワークを確認するか、メニューの「翻訳言語を準備」を試してください。"
    }
}

/// `.translationTask` を常時マウントするための見えないホスト。セッションを View 消失後に使うと fatalError になる。
struct TranslationHostView: View {
    @ObservedObject var service: TranslationService

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .translationTask(service.configuration) { session in
                await service.perform(session: session)
            }
    }
}

@MainActor
final class TranslationHostController {
    private let panel: NSPanel

    init(service: TranslationService) {
        let hosting = NSHostingView(rootView: TranslationHostView(service: service))
        hosting.frame = NSRect(x: 0, y: 0, width: 4, height: 4)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 4, height: 4),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.isFloatingPanel = false
        panel.level = .normal
        panel.alphaValue = 0
        panel.ignoresMouseEvents = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.orderFrontRegardless()
        self.panel = panel
        AppLog.translate.info("Translation host window mounted")
    }
}
