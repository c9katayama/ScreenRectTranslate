import CoreGraphics
import XCTest
@testable import ScreenRectTranslate

/// OCR 行の組み立て。折り返された 1 文が 1 文として翻訳に渡るかを確認する。
final class OCRTextJoinerTests: XCTestCase {
    /// 上から順に、行の高さ 0.1・行間 0.02 で並んだ行を作る。
    private func stackedLines(_ texts: [String], top: CGFloat = 0.95, x: CGFloat = 0.1) -> [OCRLine] {
        texts.enumerated().map { index, text in
            let maxY = top - CGFloat(index) * 0.12
            return OCRLine(text: text, boundingBox: CGRect(x: x, y: maxY - 0.1, width: 0.8, height: 0.1))
        }
    }

    /// 漫画の吹き出しのような全大文字の折り返しは、1 文の通常表記になること。
    func testMangaBalloonBecomesOneSentence() {
        let lines = stackedLines([
            "WHAT WOULD", "YOU SAY ABOUT", "THE LARGE", "PUBLIC BATH", "THAT MAKES", "OUR PRIDE IN", "THE MEANTIME?"
        ])
        XCTAssertEqual(
            OCRTextJoiner.join(lines),
            "What would you say about the large public bath that makes our pride in the meantime?"
        )
    }

    /// 行間が大きく空いた行は別段落として改行で区切ること。
    func testLargeGapSplitsParagraphs() {
        let first = stackedLines(["Hello", "there."], top: 0.95)
        let second = stackedLines(["See you", "later."], top: 0.5)
        XCTAssertEqual(OCRTextJoiner.join(first + second), "Hello there.\nSee you later.")
    }

    /// 横に並んだ別の吹き出しは同じ段落にしないこと。
    func testSideBySideBlocksSplit() {
        let left = OCRLine(text: "Left", boundingBox: CGRect(x: 0.0, y: 0.8, width: 0.3, height: 0.1))
        let right = OCRLine(text: "Right", boundingBox: CGRect(x: 0.6, y: 0.8, width: 0.3, height: 0.1))
        XCTAssertEqual(OCRTextJoiner.paragraphs([left, right]).count, 2)
    }

    /// 行末ハイフンで分綴された単語は 1 語に戻すこと。
    func testHyphenatedLineBreakIsRejoined() {
        XCTAssertEqual(OCRTextJoiner.joinLines(["the pub-", "lic bath"]), "the public bath")
    }

    /// 日本語の行は空白を挟まずにつなぐこと。
    func testJapaneseLinesJoinWithoutSpace() {
        XCTAssertEqual(OCRTextJoiner.joinLines(["これは折り返された", "文章です。"]), "これは折り返された文章です。")
    }

    /// 全大文字の複数文は文ごとに先頭を大文字にし、一人称 I は大文字のままにすること。
    func testNormalizeCaseKeepsSentenceStartsAndPronounI() {
        XCTAssertEqual(OCRTextJoiner.normalizeCase("I THINK SO. I'M FINE!"), "I think so. I'm fine!")
    }

    /// 大文字と小文字が混在する通常の文は変更しないこと。
    func testMixedCaseTextIsUnchanged() {
        XCTAssertEqual(OCRTextJoiner.normalizeCase("Open the NASA website."), "Open the NASA website.")
    }
}
