import AppKit
import Carbon
import Foundation

/// Carbon 修飾キー。Carbon.framework を設定側に引きずらないための値。
enum CarbonModifier: UInt32 {
    case cmd = 256
    case shift = 512
    case option = 2048
    case control = 4096
}

struct HotkeyCombo: Equatable, Sendable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    var displayString: String {
        var parts: [String] = []
        if carbonModifiers & CarbonModifier.control.rawValue != 0 { parts.append("⌃") }
        if carbonModifiers & CarbonModifier.option.rawValue != 0 { parts.append("⌥") }
        if carbonModifiers & CarbonModifier.shift.rawValue != 0 { parts.append("⇧") }
        if carbonModifiers & CarbonModifier.cmd.rawValue != 0 { parts.append("⌘") }
        parts.append(Self.keyName(keyCode: keyCode))
        return parts.joined()
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var value: UInt32 = 0
        if flags.contains(.control) { value |= CarbonModifier.control.rawValue }
        if flags.contains(.option) { value |= CarbonModifier.option.rawValue }
        if flags.contains(.shift) { value |= CarbonModifier.shift.rawValue }
        if flags.contains(.command) { value |= CarbonModifier.cmd.rawValue }
        return value
    }

    static func keyName(keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Escape: return "Esc"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default:
            return "Key\(keyCode)"
        }
    }
}

/// グローバルホットキー。Carbon `RegisterEventHotKey` を使う（アクセシビリティなしでも登録できる）。
@MainActor
final class HotkeyManager {
    private let settings: AppSettings
    private let onHotkey: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: fourCharCode("SRTR"), id: 1)

    init(settings: AppSettings, onHotkey: @escaping () -> Void) {
        self.settings = settings
        self.onHotkey = onHotkey
    }

    func register() {
        unregister()

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotkeyHandler,
            1,
            &spec,
            userData,
            &handlerRef
        )
        if status != noErr {
            AppLog.hotkey.error("InstallEventHandler failed: \(status)")
        }

        var ref: EventHotKeyRef?
        let registerStatus = RegisterEventHotKey(
            settings.keyCode,
            settings.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if registerStatus != noErr {
            AppLog.hotkey.error("RegisterEventHotKey failed: \(registerStatus). combo=\(self.settings.combo.displayString, privacy: .public)")
            return
        }
        hotKeyRef = ref
        AppLog.hotkey.info("Registered hotkey \(self.settings.combo.displayString, privacy: .public)")
    }

    func unregister() {
        if let hotKeyRef {
            let status = UnregisterEventHotKey(hotKeyRef)
            if status != noErr {
                AppLog.hotkey.error("UnregisterEventHotKey failed: \(status)")
            }
            self.hotKeyRef = nil
        }
        if let handlerRef {
            let status = RemoveEventHandler(handlerRef)
            if status != noErr {
                AppLog.hotkey.error("RemoveEventHandler failed: \(status)")
            }
            self.handlerRef = nil
        }
    }

    fileprivate func handlePress() {
        AppLog.hotkey.info("Hotkey pressed")
        onHotkey()
    }

    deinit {
        // Carbon 参照の解放は MainActor 上で行う。終了時は applicationWillTerminate からも呼ぶ。
    }
}

private func fourCharCode(_ string: String) -> FourCharCode {
    var result: FourCharCode = 0
    for scalar in string.unicodeScalars.prefix(4) {
        result = (result << 8) + FourCharCode(scalar.value)
    }
    return result
}

private func carbonHotkeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else {
        return OSStatus(eventNotHandledErr)
    }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async {
        manager.handlePress()
    }
    return noErr
}
