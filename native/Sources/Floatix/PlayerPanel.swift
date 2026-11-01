import AppKit
import WebKit
import FloatixCore

private let safariUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"

private final class DragView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// Borderless panel is nonactivating: buttons must act on the first click.
private final class HudButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
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
        animationBehavior = .none  // no fade-out lag on orderOut
        backgroundColor = .black
        buildUI()
    }

    private func buildUI() {
        let root = HoverView(frame: NSRect(x: 0, y: 0, width: 480, height: 270))
        root.onHover = { [weak self] in self?.hover($0) }
        webView.frame = root.bounds
        webView.autoresizingMask = [.width, .height]
        root.addSubview(webView)

        // Lapisan seret di atas video: panel bisa digeser dari mana saja (halaman tidak perlu diklik).
        let dragAll = DragView(frame: root.bounds)
        dragAll.autoresizingMask = [.width, .height]
        root.addSubview(dragAll)

        hud.frame = NSRect(x: 0, y: root.bounds.height - 28, width: root.bounds.width, height: 28)
        hud.autoresizingMask = [.width, .minYMargin]
        hud.material = .hudWindow
        hud.blendingMode = .withinWindow
        hud.state = .active
        hud.alphaValue = 0
        // Tombol langsung di dalam DragView: area kosong HUD ikut bisa diseret.
        let hudDrag = DragView(frame: hud.bounds)
        hudDrag.autoresizingMask = [.width, .height]
        for (i, (title, action)) in [("⏯", #selector(playTapped)), ("◐", #selector(opacityTapped)), ("✕", #selector(closeTapped))].enumerated() {
            let b = HudButton(title: title, target: self, action: action)
            b.isBordered = false
            b.frame = NSRect(x: 6 + CGFloat(i) * 28, y: 2, width: 24, height: 24)
            hudDrag.addSubview(b)
        }
        hud.addSubview(hudDrag)
        root.addSubview(hud)
        contentView = root
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
        webView.load(URLRequest(url: playbackURL(req.url, time: req.time)))
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
        let js = "(() => { const v = window.__floatixVideo; if (document.querySelector('.ad-showing')) return -1; return v && v.readyState >= 1 && v.currentTime > 0 ? v.currentTime : -1; })()"
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
        orderOut(nil)  // hide now; the JS read below may be slow or hang
        let gen = generation
        currentTime { [weak self] t in
            guard let self else { return }
            self.onClose?(t)
            guard gen == self.generation else { return }  // a newer show() owns the panel now
            self.lastTime = t
            self.closing = false
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
