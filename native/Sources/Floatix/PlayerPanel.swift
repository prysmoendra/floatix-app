import AppKit
import WebKit
import FloatixCore

private let safariUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"

private final class DragView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
}

// Container owns the hover tracking so the HUD shows over the web content.
private final class HoverView: NSView {
    var onHover: ((Bool) -> Void)?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }
    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }
}

final class PlayerPanel: NSPanel {
    var onClose: ((Double) -> Void)?
    private let webView: WKWebView
    private let hud = NSVisualEffectView()
    private var hideTimer: Timer?
    private let opacities: [CGFloat] = [1.0, 0.6, 0.3]
    private var opacityIndex = 0
    private var startTime = 0.0
    private var lastTime = 0.0
    private var generation = 0
    private var closing = false

    init() {
        let cfg = WKWebViewConfiguration()
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.allowsAirPlayForMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: cfg)
        webView.customUserAgent = safariUA
        super.init(contentRect: NSRect(x: 0, y: 0, width: 480, height: 270),
                   styleMask: [.borderless, .nonactivatingPanel, .resizable],
                   backing: .buffered, defer: false)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        backgroundColor = .black
        buildUI()
    }

    private func buildUI() {
        let root = HoverView(frame: NSRect(x: 0, y: 0, width: 480, height: 270))
        root.onHover = { [weak self] in self?.hover($0) }
        webView.frame = root.bounds
        webView.autoresizingMask = [.width, .height]
        root.addSubview(webView)

        hud.frame = NSRect(x: 0, y: root.bounds.height - 28, width: root.bounds.width, height: 28)
        hud.autoresizingMask = [.width, .minYMargin]
        hud.material = .hudWindow
        hud.blendingMode = .withinWindow
        hud.state = .active
        hud.alphaValue = 0
        let drag = DragView()
        let play = hudButton("⏯", #selector(playTapped))
        let opac = hudButton("◐", #selector(opacityTapped))
        let close = hudButton("✕", #selector(closeTapped))
        let stack = NSStackView(views: [drag, play, opac, close])
        stack.frame = hud.bounds
        stack.autoresizingMask = [.width, .height]
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 6, bottom: 0, right: 6)
        drag.setContentHuggingPriority(.defaultLow, for: .horizontal)
        hud.addSubview(stack)
        root.addSubview(hud)
        contentView = root
    }

    private func hudButton(_ title: String, _ action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.isBordered = false
        b.setContentHuggingPriority(.required, for: .horizontal)
        return b
    }

    private func hover(_ inside: Bool) {
        hideTimer?.invalidate()
        if inside {
            hud.animator().alphaValue = 1
        } else {
            hideTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                self?.hud.animator().alphaValue = 0
            }
        }
    }

    @objc private func playTapped() { togglePlay() }
    @objc private func opacityTapped() {
        opacityIndex = (opacityIndex + 1) % opacities.count
        alphaValue = opacities[opacityIndex]
    }
    @objc private func closeTapped() { requestClose() }

    override var canBecomeKey: Bool { true }

    func show(_ req: OpenRequest) {
        generation += 1; closing = false
        startTime = req.time; lastTime = req.time
        let ucc = webView.configuration.userContentController
        ucc.removeAllUserScripts()
        ucc.addUserScript(WKUserScript(source: isolatorScript(startTime: req.time),
                                       injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        webView.load(URLRequest(url: req.url))
        if !isVisible {
            let visible = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
            setFrame(initialFrame(visible: visible, aspect: req.aspect), display: true)
        }
        contentAspectRatio = NSSize(width: req.aspect, height: 1)
        orderFrontRegardless()
        makeKey()
    }

    func togglePlay() {
        webView.evaluateJavaScript("(() => { const v = window.__floatixVideo; if (!v) return; v.paused ? v.play() : v.pause(); })()")
    }

    func currentTime(_ done: @escaping (Double) -> Void) {
        let js = "(() => { const v = window.__floatixVideo; return v && v.readyState >= 1 && v.currentTime > 0 ? v.currentTime : -1; })()"
        webView.evaluateJavaScript(js) { [weak self] r, _ in
            // -1 or non-Double: video never started, keep the resume point
            if let t = r as? Double, t >= 0 { done(t) } else { done(self?.startTime ?? 0) }
        }
    }

    /// Reads time, reports via onClose once, hides, and blanks the page to stop audio.
    func requestClose() {
        if closing { return }
        if !isVisible { onClose?(lastTime); return }
        closing = true
        hideTimer?.invalidate(); hud.alphaValue = 0
        let gen = generation
        currentTime { [weak self] t in
            guard let self else { return }
            self.onClose?(t)
            guard gen == self.generation else { return }  // a newer show() owns the panel now
            self.lastTime = t
            self.closing = false
            self.orderOut(nil)
            self.webView.load(URLRequest(url: URL(string: "about:blank")!))
        }
    }

    override func close() { if isVisible { requestClose() } else { super.close() } }
    override func performClose(_ sender: Any?) { requestClose() }
    override func cancelOperation(_ sender: Any?) { requestClose() }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { requestClose() } else { super.keyDown(with: event) }
    }
}
