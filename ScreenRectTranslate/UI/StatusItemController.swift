import AppKit

@MainActor
final class StatusItemController: NSObject {
    private let settings: AppSettings
    private let statusItem: NSStatusItem
    private let onTranslate: () -> Void
    private let onPreferences: () -> Void
    private let onPermissions: () -> Void
    private let onPrepareTranslation: () -> Void
    private let onQuit: () -> Void

    init(
        settings: AppSettings,
        onTranslate: @escaping () -> Void,
        onPreferences: @escaping () -> Void,
        onPermissions: @escaping () -> Void,
        onPrepareTranslation: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.settings = settings
        self.onTranslate = onTranslate
        self.onPreferences = onPreferences
        self.onPermissions = onPermissions
        self.onPrepareTranslation = onPrepareTranslation
        self.onQuit = onQuit
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "ScreenRectTranslate")
            button.toolTip = "ScreenRectTranslate"
        }
        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(makeItem("範囲を選択して翻訳（\(settings.combo.displayString)）", #selector(translate)))
        menu.addItem(.separator())
        menu.addItem(makeItem("環境設定…", #selector(preferences)))
        menu.addItem(makeItem("権限の確認…", #selector(permissions)))
        menu.addItem(makeItem("翻訳言語を準備…", #selector(prepare)))
        menu.addItem(.separator())
        menu.addItem(makeItem("終了", #selector(quit), key: "q"))
        statusItem.menu = menu
    }

    private func makeItem(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func translate() { onTranslate() }
    @objc private func preferences() { onPreferences() }
    @objc private func permissions() { onPermissions() }
    @objc private func prepare() { onPrepareTranslation() }
    @objc private func quit() { onQuit() }
}
