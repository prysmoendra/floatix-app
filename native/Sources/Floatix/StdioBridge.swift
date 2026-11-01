import Foundation
import FloatixCore

func log(_ s: String) { FileHandle.standardError.write(Data((s + "\n").utf8)) }

final class StdioBridge {
    private let onMessage: (InboundMessage) -> Void
    private let onEOF: () -> Void
    private let lock = NSLock()

    init(onMessage: @escaping (InboundMessage) -> Void, onEOF: @escaping () -> Void) {
        self.onMessage = onMessage; self.onEOF = onEOF
    }

    func start() {
        Thread.detachNewThread { [self] in
            var decoder = FrameDecoder()
            while true {
                let chunk = FileHandle.standardInput.availableData
                if chunk.isEmpty { break }
                do {
                    for payload in try decoder.append(chunk) { handle(payload) }
                } catch {
                    // stream poisoned: reply, then stop reading and quit
                    send(.error("\(error)"))
                    DispatchQueue.main.async { self.onEOF() }
                    return
                }
            }
            DispatchQueue.main.async { self.onEOF() }
        }
    }

    private func handle(_ payload: Data) {
        do {
            let m = try decodeInbound(payload)
            DispatchQueue.main.async { self.onMessage(m) }
        } catch {
            send(.error("\(error)"))
        }
    }

    func send(_ m: OutboundMessage) {
        var m = m
        if case .error(let s) = m { m = .error(String(s.prefix(1000))) }
        let frame = encodeFrame(encodeOutbound(m))
        guard frame.count - 4 <= 1_048_576 else { log("frame keluar > 1 MB, dibuang"); return }
        lock.lock(); defer { lock.unlock() }
        FileHandle.standardOutput.write(frame)
    }
}
