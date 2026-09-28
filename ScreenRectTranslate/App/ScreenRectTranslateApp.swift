import SwiftUI

@main
struct ScreenRectTranslateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView()
                .environmentObject(appDelegate.settings)
                .environmentObject(appDelegate.translationService)
        }
    }
}
