import Foundation
import os.log

/// アプリ全体のログ。例外を握りつぶさず、失敗は必ずここに残す。
enum AppLog {
    static let subsystem = "com.personal.ScreenRectTranslate"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let flow = Logger(subsystem: subsystem, category: "flow")
    static let hotkey = Logger(subsystem: subsystem, category: "hotkey")
    static let overlay = Logger(subsystem: subsystem, category: "overlay")
    static let capture = Logger(subsystem: subsystem, category: "capture")
    static let ocr = Logger(subsystem: subsystem, category: "ocr")
    static let language = Logger(subsystem: subsystem, category: "language")
    static let translate = Logger(subsystem: subsystem, category: "translate")
    static let permission = Logger(subsystem: subsystem, category: "permission")
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
