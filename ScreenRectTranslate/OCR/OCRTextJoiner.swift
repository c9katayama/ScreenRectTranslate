import CoreGraphics
import Foundation

/// Vision が返す 1 行分の認識結果。boundingBox は正規化座標（左下原点）。
struct OCRLine: Sendable, Equatable {
    let text: String
    let boundingBox: CGRect
}

/// OCR の行を翻訳しやすい文章に組み立てる。
/// 漫画の吹き出しのように 1 文が複数行に折り返されていても、1 文として翻訳させるため。
enum OCRTextJoiner {
    /// 行間がこの倍率（行の高さの中央値に対する比）を超えたら段落を分ける。
    static let paragraphGapRatio: CGFloat = 0.8

    static func join(_ lines: [OCRLine]) -> String {
        paragraphs(lines)
            .map { normalizeCase(joinLines($0.map(\.text))) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// 縦の間隔と横の重なりで、同じ段落（吹き出し）に属する行をまとめる。
    static func paragraphs(_ lines: [OCRLine]) -> [[OCRLine]] {
        let lines = lines.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !lines.isEmpty else { return [] }

        let heights = lines.map(\.boundingBox.height).sorted()
        let medianHeight = heights[heights.count / 2]

        var result: [[OCRLine]] = [[lines[0]]]
        for (previous, current) in zip(lines, lines.dropFirst()) {
            let gap = previous.boundingBox.minY - current.boundingBox.maxY
            let overlapsHorizontally = previous.boundingBox.minX < current.boundingBox.maxX
                && current.boundingBox.minX < previous.boundingBox.maxX
            if gap > medianHeight * paragraphGapRatio || gap < -medianHeight || !overlapsHorizontally {
                result.append([current])
            } else {
                result[result.count - 1].append(current)
            }
        }
        return result
    }

    /// 段落内の行をつなぐ。行末ハイフンの分綴は戻し、CJK 同士は空白を入れない。
    static func joinLines(_ lines: [String]) -> String {
        var text = ""
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            guard let last = text.last, let first = line.first else {
                text = line
                continue
            }
            if last == "-", text.dropLast().last?.isLetter == true, first.isLetter {
                text.removeLast()
                text += line
            } else if isCJK(last) || isCJK(first) {
                text += line
            } else {
                text += " " + line
            }
        }
        return text
    }

    /// 英字のほとんどが大文字なら文頭だけ大文字の文に直す。全大文字だと固有名詞や略語と誤解されやすいため。
    static func normalizeCase(_ text: String) -> String {
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) && $0.isASCII }
        let uppercase = letters.filter { CharacterSet.uppercaseLetters.contains($0) }
        guard letters.count >= 4, Double(uppercase.count) / Double(letters.count) >= 0.8 else {
            return text
        }

        var result = ""
        var capitalizeNext = true
        for character in text.lowercased() {
            if capitalizeNext, character.isLetter {
                result += character.uppercased()
                capitalizeNext = false
            } else {
                result.append(character)
            }
            if ".!?".contains(character) {
                capitalizeNext = true
            }
        }
        // 一人称の I は常に大文字（I'm / I'll なども含む）。
        return result.replacingOccurrences(
            of: #"\bi\b"#,
            with: "I",
            options: .regularExpression
        )
    }

    private static func isCJK(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3000...0x30FF, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xFF00...0xFFEF:
                return true
            default:
                return false
            }
        }
    }
}
