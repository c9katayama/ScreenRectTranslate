import AppKit
import Foundation

/// 全画面の半透明オーバーレイで矩形選択する。Esc でキャンセル、マウスアップで確定。
@MainActor
final class SelectionOverlayController {
    private var windows: [SelectionWindow] = []
    private var continuation: CheckedContinuation<CGRect?, Never>?
    private var localMonitor: Any?
    private var isFinishing = false

    func selectRectangle() async -> CGRect? {
        if continuation != nil {
            AppLog.overlay.notice("Selection already in progress")
            return nil
        }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            self.present()
        }
    }

    private func present() {
        isFinishing = false
        NSApp.activate(ignoringOtherApps: true)

        windows = NSScreen.screens.map { screen in
            let window = SelectionWindow(screen: screen)
            window.onComplete = { [weak self] rect in
                self?.finish(rect)
            }
            window.onCancel = { [weak self] in
                self?.finish(nil)
            }
            return window
        }

        windows.forEach { $0.orderFrontRegardless() }
        windows.first?.makeKey()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == UInt16(kVK_Escape) {
                self?.finish(nil)
                return nil
            }
            return event
        }
        AppLog.overlay.info("Selection overlay presented on \(self.windows.count) screen(s)")
    }

    private func finish(_ rect: CGRect?) {
        guard !isFinishing else { return }
        isFinishing = true
        guard let continuation else {
            AppLog.overlay.error("finish called without an active continuation")
            return
        }
        self.continuation = nil
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        if let rect {
            AppLog.overlay.info("Selection completed \(Int(rect.width))x\(Int(rect.height))")
        } else {
            AppLog.overlay.info("Selection cancelled")
        }
        continuation.resume(returning: rect)
    }
}

private let kVK_Escape: Int = 53

private final class SelectionWindow: NSWindow {
    var onComplete: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        setFrame(screen.frame, display: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        animationBehavior = .none
        isReleasedWhenClosed = false
        hidesOnDeactivate = false

        let view = SelectionOverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.onComplete = { [weak self] rectInView in
            guard let self else { return }
            let screenRect = self.convertToScreen(rectInView)
            self.onComplete?(screenRect)
        }
        view.onCancel = { [weak self] in
            self?.onCancel?()
        }
        contentView = view
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class SelectionOverlayView: NSView {
    var onComplete: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        NSCursor.crosshair.push()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            NSCursor.pop()
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let overlay = NSBezierPath(rect: bounds)
        if let selection = selectionRect, selection.width > 0, selection.height > 0 {
            overlay.append(NSBezierPath(rect: selection))
            overlay.windingRule = .evenOdd
        }
        NSColor.black.withAlphaComponent(0.48).setFill()
        overlay.fill()

        if let selection = selectionRect, selection.width > 1, selection.height > 1 {
            NSColor.white.setStroke()
            let border = NSBezierPath(rect: selection.insetBy(dx: 0.5, dy: 0.5))
            border.lineWidth = 2
            border.stroke()

            NSColor.systemTeal.setStroke()
            let inner = NSBezierPath(rect: selection.insetBy(dx: 2, dy: 2))
            inner.lineWidth = 1
            inner.stroke()

            drawSizeLabel(for: selection)
        } else {
            drawHint()
        }
    }

    private func drawHint() {
        let text = "ドラッグして範囲を選択   Esc でキャンセル"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.92)
        ]
        let size = text.size(withAttributes: attrs)
        let point = CGPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
        text.draw(at: point, withAttributes: attrs)
    }

    private func drawSizeLabel(for selection: CGRect) {
        let text = "\(Int(selection.width.rounded())) × \(Int(selection.height.rounded()))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.black
        ]
        let size = text.size(withAttributes: attrs)
        var labelOrigin = CGPoint(x: selection.minX, y: selection.maxY + 6)
        if labelOrigin.y + size.height + 6 > bounds.maxY {
            labelOrigin.y = max(selection.minY - size.height - 10, 8)
        }
        let background = NSRect(
            x: labelOrigin.x,
            y: labelOrigin.y - 3,
            width: size.width + 10,
            height: size.height + 6
        )
        NSColor.white.withAlphaComponent(0.9).setFill()
        NSBezierPath(roundedRect: background, xRadius: 4, yRadius: 4).fill()
        text.draw(at: CGPoint(x: labelOrigin.x + 5, y: labelOrigin.y), withAttributes: attrs)
    }

    private var selectionRect: CGRect? {
        guard let startPoint, let currentPoint else { return nil }
        return CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
        guard let rect = selectionRect, rect.width >= 8, rect.height >= 8 else {
            onCancel?()
            return
        }
        onComplete?(rect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
