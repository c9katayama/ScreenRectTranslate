import Foundation
import Vision

struct OCRResult: Sendable {
    let text: String
    let lines: [String]
}

enum OCRError: LocalizedError {
    case visionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .visionFailed(let error):
            return "文字認識に失敗しました。\(error.localizedDescription)"
        }
    }
}

/// Vision `VNRecognizeTextRequest` による OCR。翻訳とは独立した工程。
final class OCRService: Sendable {
    func recognize(image: CGImage) async throws -> OCRResult {
        do {
            return try await perform(image: image, languages: ["en-US", "ja-JP"])
        } catch {
            AppLog.ocr.error("OCR with en-US+ja-JP failed: \(error.localizedDescription, privacy: .public). Retrying with en-US only.")
            return try await perform(image: image, languages: ["en-US"])
        }
    }

    private func perform(image: CGImage, languages: [String]) async throws -> OCRResult {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = languages
            request.automaticallyDetectsLanguage = true

            let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
            do {
                try handler.perform([request])
            } catch {
                AppLog.ocr.error("VNImageRequestHandler.perform failed: \(error.localizedDescription, privacy: .public)")
                throw OCRError.visionFailed(error)
            }

            let observations = request.results ?? []
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            let text = lines.joined(separator: "\n")
            AppLog.ocr.info("OCR finished. languages=\(languages.joined(separator: ","), privacy: .public) lines=\(lines.count) chars=\(text.count)")
            return OCRResult(text: text, lines: lines)
        }.value
    }
}
