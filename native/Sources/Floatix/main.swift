import AppKit
import FloatixCore

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

var bridge: StdioBridge!
var panelStore: PlayerPanel?
var panel: PlayerPanel {
    if let p = panelStore { return p }
    let p = PlayerPanel()
    p.onClose = { t in
        p.orderOut(nil)
        bridge.send(.closed(time: t))
    }
    panelStore = p
    return p
}

bridge = StdioBridge(
    onMessage: { m in
        switch m {
        case .open(let req): panel.show(req)
        case .close: panel.onClose?(0)
        case .togglePlay: break
        }
    },
    onEOF: { NSApp.terminate(nil) })
bridge.start()
bridge.send(.ready)
app.run()
