import Foundation
import NaturalLanguage

struct LanguageDetectionResult: Sendable, Equatable {
    let dominantLanguageCode: String?
    let containsEnglish: Bool
    let englishScore: Double
    let standaloneEnglishWords: Bool
}

/// OCR 結果に英語が含まれるかを見る。翻訳するかどうかの判定だけを担う。
enum LanguageDetector {
    static func analyze(_ text: String) -> LanguageDetectionResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let standalone = containsStandaloneEnglishWords(trimmed)
        guard !trimmed.isEmpty else {
            return LanguageDetectionResult(
                dominantLanguageCode: nil,
                containsEnglish: false,
                englishScore: 0,
                standaloneEnglishWords: false
            )
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        let dominant = recognizer.dominantLanguage
        let hypotheses = recognizer.languageHypotheses(withMaximum: 8)
        let englishScore = hypotheses[.english] ?? 0
        let dominantIsEnglish = dominant == .english
        let containsEnglish = dominantIsEnglish || englishScore >= 0.12 || standalone

        AppLog.language.info(
            "Language detect dominant=\(dominant?.rawValue ?? "nil", privacy: .public) enScore=\(englishScore) standalone=\(standalone) containsEnglish=\(containsEnglish)"
        )

        return LanguageDetectionResult(
            dominantLanguageCode: dominant?.rawValue,
            containsEnglish: containsEnglish,
            englishScore: englishScore,
            standaloneEnglishWords: standalone
        )
    }

    /// ASCII の英単語（3文字以上）があるか。日英混在の UI でも翻訳対象にする。
    static func containsStandaloneEnglishWords(_ text: String) -> Bool {
        let separators = CharacterSet.letters.inverted
        return text.unicodeScalars
            .split(whereSeparator: { separators.contains($0) })
            .contains { chunk in
                chunk.count >= 3 && chunk.allSatisfy { CharacterSet.letters.contains($0) && $0.isASCII }
            }
    }
}
