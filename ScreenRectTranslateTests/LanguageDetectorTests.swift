import XCTest
@testable import ScreenRectTranslate

/// 英語の有無判定。翻訳する／しないの分岐が意図どおりかを確認する。
final class LanguageDetectorTests: XCTestCase {
    /// 典型的な英語文は英語ありと判定すること。
    func testEnglishSentenceContainsEnglish() {
        let result = LanguageDetector.analyze("The settings window is not responding.")
        XCTAssertTrue(result.containsEnglish)
        XCTAssertGreaterThan(result.englishScore, 0)
    }

    /// 日本語だけの文は翻訳対象にしないこと。
    func testJapaneseOnlyHasNoEnglish() {
        let result = LanguageDetector.analyze("この画面には翻訳する英語がありません。")
        XCTAssertFalse(result.containsEnglish)
        XCTAssertFalse(result.standaloneEnglishWords)
    }

    /// 日本語 UI に英単語が混ざる場合は翻訳対象にすること。
    func testMixedJapaneseAndEnglishWords() {
        XCTAssertTrue(LanguageDetector.containsStandaloneEnglishWords("設定を Cancel して Retry してください"))
        let result = LanguageDetector.analyze("設定を Cancel して Retry してください")
        XCTAssertTrue(result.containsEnglish)
    }

    /// 2文字以下の ASCII は英単語として扱わないこと（UI の OK などを誤検出しない）。
    func testShortASCIIIsNotStandaloneEnglishWord() {
        XCTAssertFalse(LanguageDetector.containsStandaloneEnglishWords("OK です"))
        XCTAssertFalse(LanguageDetector.containsStandaloneEnglishWords("あいうえお"))
    }

    /// 空文字は英語なしであること。
    func testEmptyTextHasNoEnglish() {
        let result = LanguageDetector.analyze("   \n")
        XCTAssertFalse(result.containsEnglish)
        XCTAssertNil(result.dominantLanguageCode)
    }

    /// 3文字以上の連続した ASCII 英字を英単語として検出すること。
    func testStandaloneEnglishWordHelper() {
        XCTAssertTrue(LanguageDetector.containsStandaloneEnglishWords("Error"))
        XCTAssertTrue(LanguageDetector.containsStandaloneEnglishWords("コードに Hello が混ざる"))
        XCTAssertFalse(LanguageDetector.containsStandaloneEnglishWords("123 456"))
    }
}
