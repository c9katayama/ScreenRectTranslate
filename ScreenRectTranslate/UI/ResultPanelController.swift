import AppKit
import SwiftUI

@MainActor
final class ResultPanelController: NSObject, NSWindowDelegate {
    private let settings: AppSettings
    private let model: ResultPanelModel
    private var panel: NSPanel?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(settings: AppSettings, translation: TranslationService) {
        self.settings = settings
        self.model = ResultPanelModel(translation: translation)
    }

    func showOCR(text: String, detection: LanguageDetectionResult, anchorRect: CGRect) {
        model.presentOCR(text, detection: detection)
        present(anchorRect: anchorRect)
    }

    func showError(_ error: Error, anchorRect: CGRect?) {
        model.presentError(error.localizedDescription)
        present(anchorRect: anchorRect)
    }

    func dismiss() {
        removeMonitors()
        panel?.orderOut(nil)
        AppLog.ui.info("Result panel dismissed")
    }

    private func present(anchorRect: CGRect?) {
        let view = ResultPanelView(model: model, translation: model.translation) { [weak self] in
            self?.dismiss()
        }
        let hosting = NSHostingView(rootView: view)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        // 内容に合わせてウィンドウを伸縮させない。ユーザーが決めたサイズを保つため。
        hosting.sizingOptions = [.minSize]

        let panel = self.panel ?? makePanel()
        panel.contentView = hosting
        if let saved = savedFrame() {
            panel.setFrame(saved, display: true)
        } else {
            hosting.layoutSubtreeIfNeeded()
            let fitting = hosting.fittingSize
            panel.setContentSize(NSSize(width: max(fitting.width, 440), height: min(max(fitting.height, 280), 560)))
            position(panel, near: anchorRect)
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
        installMonitors(for: panel)
        AppLog.ui.info("Result panel shown")
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 360),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "ScreenRectTranslate"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.delegate = self
        return panel
    }

    /// 保存済みの frame。いまつながっている画面から大きく外れる場合は使わない。
    private func savedFrame() -> NSRect? {
        guard let frame = settings.resultPanelFrame, frame.width > 0, frame.height > 0 else { return nil }
        let onScreen = NSScreen.screens.contains { screen in
            let visible = screen.visibleFrame.intersection(frame)
            return visible.width >= 80 && visible.height >= 80
        }
        return onScreen ? frame : nil
    }

    private func position(_ panel: NSPanel, near rect: CGRect?) {
        let screen = rect.flatMap(ScreenGeometry.screen(containing:)) ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 80, y: 80, width: 800, height: 600)
        var frame = panel.frame
        if let rect {
            frame.origin.x = min(max(rect.minX, visible.minX + 12), visible.maxX - frame.width - 12)
            let below = rect.minY - frame.height - 12
            if below > visible.minY {
                frame.origin.y = below
            } else {
                frame.origin.y = min(rect.maxY + 12, visible.maxY - frame.height - 12)
            }
        } else {
            frame.origin.x = visible.midX - frame.width / 2
            frame.origin.y = visible.midY - frame.height / 2
        }
        panel.setFrame(frame, display: true)
    }

    private func installMonitors(for panel: NSPanel) {
        removeMonitors()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.settings.closesResultOnOutsideClick,
                  let panel = self.panel, panel.isVisible else { return }
            if !panel.frame.contains(NSEvent.mouseLocation) {
                self.dismiss()
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.dismiss()
                return nil
            }
            return event
        }
    }

    private func removeMonitors() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    func windowDidMove(_ notification: Notification) {
        saveFrame()
    }

    func windowDidResize(_ notification: Notification) {
        saveFrame()
    }

    private func saveFrame() {
        guard let panel, panel.isVisible else { return }
        settings.resultPanelFrame = panel.frame
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        dismiss()
        return false
    }
}
