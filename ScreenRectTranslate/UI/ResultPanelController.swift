import AppKit
import SwiftUI

@MainActor
final class ResultPanelController: NSObject, NSWindowDelegate {
    private let model: ResultPanelModel
    private var panel: NSPanel?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(translation: TranslationService) {
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

        let panel = self.panel ?? makePanel()
        panel.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        let fitting = hosting.fittingSize
        panel.setContentSize(NSSize(width: max(fitting.width, 440), height: min(max(fitting.height, 280), 560)))
        position(panel, near: anchorRect)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
        installMonitors(for: panel)
        AppLog.ui.info("Result panel shown")
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 360),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
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
            guard let self, let panel = self.panel, panel.isVisible else { return }
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

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        dismiss()
        return false
    }
}
