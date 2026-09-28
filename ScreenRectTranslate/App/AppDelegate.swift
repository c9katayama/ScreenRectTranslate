import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    let translationService = TranslationService()

    private var coordinator: AppCoordinator!
    private var hotkey: HotkeyManager!
    private var statusItem: StatusItemController!
    private var translationHost: TranslationHostController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        translationHost = TranslationHostController(service: translationService)
        coordinator = AppCoordinator(settings: settings, translation: translationService)
        statusItem = StatusItemController(
            settings: settings,
            onTranslate: { [weak self] in self?.coordinator.runFlow() },
            onPreferences: { Self.openSettings() },
            onPermissions: { [weak self] in self?.coordinator.showPermissions() },
            onPrepareTranslation: { [weak self] in self?.coordinator.prepareTranslationLanguages() },
            onQuit: { NSApp.terminate(nil) }
        )
        hotkey = HotkeyManager(settings: settings) { [weak self] in
            self?.coordinator.runFlow()
        }
        settings.onHotkeyChange = { [weak self] in
            self?.hotkey.register()
            self?.statusItem.rebuildMenu()
        }
        hotkey.register()

        Task { await translationService.refreshAvailability() }
        AppLog.app.info("ScreenRectTranslate launched. hotkey=\(self.settings.combo.displayString, privacy: .public)")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkey?.unregister()
        AppLog.app.info("ScreenRectTranslate terminating")
    }

    static func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
