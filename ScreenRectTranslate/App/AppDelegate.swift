import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    let translationService = TranslationService()

    private var coordinator: AppCoordinator!
    private var hotkey: HotkeyManager!
    private var statusItem: StatusItemController!
    private var translationHost: TranslationHostController!
    private var preferences: PreferencesWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        translationHost = TranslationHostController(service: translationService)
        coordinator = AppCoordinator(settings: settings, translation: translationService)
        preferences = PreferencesWindowController(settings: settings, translation: translationService)
        statusItem = StatusItemController(
            settings: settings,
            onTranslate: { [weak self] in self?.coordinator.runFlow() },
            onPreferences: { [weak self] in self?.preferences.show() },
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
}
