import AppKit
import FloatixCore

final class PlayerPanel: NSPanel {
    var onClose: ((Double) -> Void)?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 480, height: 270),
                   styleMask: [.borderless, .nonactivatingPanel, .resizable],
                   backing: .buffered, defer: false)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        backgroundColor = .black
    }

    override var canBecomeKey: Bool { true }

    func show(_ req: OpenRequest) {
        let visible = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        setFrame(initialFrame(visible: visible, aspect: req.aspect), display: true)
        contentAspectRatio = NSSize(width: req.aspect, height: 1)
        orderFrontRegardless()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onClose?(0) } else { super.keyDown(with: event) }
    }
}
