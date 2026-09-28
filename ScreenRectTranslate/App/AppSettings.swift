import Combine
import Foundation

/// ユーザー設定。ホットキーは Carbon の keyCode / 修飾キーで保存する。
@MainActor
final class AppSettings: ObservableObject {
    enum Keys {
        static let keyCode = "hotkey.keyCode"
        static let modifiers = "hotkey.carbonModifiers"
        static let closesResultOnOutsideClick = "resultPanel.closesOnOutsideClick"
        static let resultPanelFrame = "resultPanel.frame"
    }

    /// ANSI T
    static let defaultKeyCode: UInt32 = 0x11
    /// optionKey | shiftKey
    static let defaultCarbonModifiers: UInt32 = CarbonModifier.option.rawValue | CarbonModifier.shift.rawValue

    @Published var keyCode: UInt32 {
        didSet {
            UserDefaults.standard.set(Int(keyCode), forKey: Keys.keyCode)
            onHotkeyChange?()
        }
    }

    @Published var carbonModifiers: UInt32 {
        didSet {
            UserDefaults.standard.set(Int(carbonModifiers), forKey: Keys.modifiers)
            onHotkeyChange?()
        }
    }

    /// 翻訳ウィンドウの外をクリックしたときに自動で閉じるか。
    @Published var closesResultOnOutsideClick: Bool {
        didSet {
            UserDefaults.standard.set(closesResultOnOutsideClick, forKey: Keys.closesResultOnOutsideClick)
        }
    }

    /// 翻訳ウィンドウを最後に表示した位置とサイズ（スクリーン座標）。
    var resultPanelFrame: NSRect? {
        get {
            UserDefaults.standard.string(forKey: Keys.resultPanelFrame).map(NSRectFromString)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(NSStringFromRect(newValue), forKey: Keys.resultPanelFrame)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.resultPanelFrame)
            }
        }
    }

    var onHotkeyChange: (() -> Void)?

    var combo: HotkeyCombo {
        HotkeyCombo(keyCode: keyCode, carbonModifiers: carbonModifiers)
    }

    init() {
        let storedCode = UserDefaults.standard.object(forKey: Keys.keyCode) as? Int
        let storedModifiers = UserDefaults.standard.object(forKey: Keys.modifiers) as? Int
        keyCode = storedCode.map { UInt32($0) } ?? Self.defaultKeyCode
        carbonModifiers = storedModifiers.map { UInt32($0) } ?? Self.defaultCarbonModifiers
        closesResultOnOutsideClick = UserDefaults.standard.object(forKey: Keys.closesResultOnOutsideClick) as? Bool ?? true
    }

    func resetHotkey() {
        keyCode = Self.defaultKeyCode
        carbonModifiers = Self.defaultCarbonModifiers
    }

    func apply(combo: HotkeyCombo) {
        keyCode = combo.keyCode
        carbonModifiers = combo.carbonModifiers
    }
}
