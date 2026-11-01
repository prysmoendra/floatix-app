import Foundation

public struct OpenRequest: Codable, Equatable {
    public let url: URL
    public let time: Double
    public let aspect: Double
    public init(url: URL, time: Double, aspect: Double) {
        self.url = url; self.time = time; self.aspect = aspect
    }
}

public enum InboundMessage: Equatable {
    case open(OpenRequest)
    case close
    case togglePlay
}

public enum OutboundMessage: Equatable {
    case ready
    case closed(time: Double)
    case error(String)
}

private struct RawInbound: Decodable {
    let type: String
    let url: String?
    let time: Double?
    let aspect: Double?
}

public func decodeInbound(_ data: Data) throws -> InboundMessage {
    let raw: RawInbound
    do { raw = try JSONDecoder().decode(RawInbound.self, from: data) }
    catch { throw FloatixError.invalidMessage("JSON rusak") }
    switch raw.type {
    case "close": return .close
    case "togglePlay": return .togglePlay
    case "open":
        guard let s = raw.url, let url = URL(string: s),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https"
        else { throw FloatixError.invalidURL(raw.url ?? "") }
        let t = raw.time ?? 0
        let time = t.isFinite && t > 0 ? t : 0
        let a = raw.aspect ?? 16.0 / 9
        let aspect = a.isFinite ? min(max(a, 0.25), 4) : 16.0 / 9
        return .open(OpenRequest(url: url, time: time, aspect: aspect))
    default: throw FloatixError.invalidMessage("type tak dikenal: \(raw.type)")
    }
}

public func encodeOutbound(_ m: OutboundMessage) -> Data {
    let obj: [String: Any]
    switch m {
    case .ready: obj = ["type": "ready"]
    case .closed(let t): obj = ["type": "closed", "time": t.isFinite ? t : 0]
    case .error(let msg): obj = ["type": "error", "message": msg]
    }
    return (try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])) ?? Data("{}".utf8)
}
