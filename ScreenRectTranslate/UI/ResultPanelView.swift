import AppKit
import SwiftUI

@MainActor
final class ResultPanelModel: ObservableObject {
    @Published var ocrText: String = ""
    @Published var statusMessage: String?
    @Published var isError: Bool = false
    @Published var copiedLabel: String?

    let translation: TranslationService

    init(translation: TranslationService) {
        self.translation = translation
    }

    func presentOCR(_ text: String, detection: LanguageDetectionResult) {
        ocrText = text
        isError = false
        copiedLabel = nil
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            statusMessage = "この範囲から文字を認識できませんでした。"
            translation.reset()
            return
        }
        if detection.containsEnglish {
            statusMessage = nil
            translation.startEnglishToJapanese(text)
        } else {
            statusMessage = "英語が見つかりませんでした。翻訳は行っていません。"
            translation.skipBecauseNoEnglish()
        }
    }

    func presentError(_ message: String) {
        ocrText = ""
        statusMessage = message
        isError = true
        copiedLabel = nil
        translation.reset()
    }

    func copy(_ text: String, label: String) {
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedLabel = label
        AppLog.ui.info("Copied \(label, privacy: .public)")
    }
}

struct ResultPanelView: View {
    @ObservedObject var model: ResultPanelModel
    @ObservedObject var translation: TranslationService
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if let statusMessage = model.statusMessage {
                Text(statusMessage)
                    .font(.callout)
                    .foregroundStyle(model.isError ? Color.red : Color.secondary)
                    .textSelection(.enabled)
            }
            textBlock(
                title: "認識したテキスト",
                text: model.ocrText,
                placeholder: "OCR 結果はありません",
                copyLabel: "原文をコピー"
            )
            translationBlock
            HStack {
                Button("両方コピー") {
                    let ja = translation.translatedText
                    let combined = ja.isEmpty ? model.ocrText : "\(model.ocrText)\n\n---\n\n\(ja)"
                    model.copy(combined, label: "両方")
                }
                .disabled(model.ocrText.isEmpty)
                Spacer()
                Button("閉じる", action: onClose)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(minWidth: 360, maxWidth: .infinity, minHeight: 280, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ScreenRectTranslate")
                    .font(.headline)
                Text("Vision OCR → Apple Translation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let copied = model.copiedLabel {
                Text("\(copied)をコピーしました")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var translationBlock: some View {
        switch translation.phase {
        case .preparing:
            labeledProgress("言語データを準備しています…")
        case .translating:
            labeledProgress("翻訳しています…")
        case .failed:
            VStack(alignment: .leading, spacing: 6) {
                Text("日本語訳")
                    .font(.subheadline.weight(.semibold))
                Text(translation.errorMessage ?? "翻訳に失敗しました。")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        case .skippedNoEnglish, .idle:
            if translation.phase == .skippedNoEnglish {
                VStack(alignment: .leading, spacing: 6) {
                    Text("日本語訳")
                        .font(.subheadline.weight(.semibold))
                    Text("翻訳対象の英語がなかったため、ここでは何も訳していません。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        case .done:
            textBlock(
                title: "日本語訳",
                text: translation.translatedText,
                placeholder: "翻訳結果はありません",
                copyLabel: "訳文をコピー"
            )
        }
    }

    private func labeledProgress(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("日本語訳")
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(title)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func textBlock(title: String, text: String, placeholder: String, copyLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(copyLabel) {
                    model.copy(text, label: copyLabel)
                }
                .disabled(text.isEmpty)
            }
            ScrollView {
                Text(text.isEmpty ? placeholder : text)
                    .font(.body)
                    .foregroundStyle(text.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 72, maxHeight: .infinity)
            .padding(8)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.08))
            )
        }
    }
}
