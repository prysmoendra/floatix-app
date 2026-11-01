import Foundation

/// URL yang dimuat panel. Video YouTube dinormalkan ke `watch?v=ID&t=Ns`, sehingga player YouTube
/// sendiri yang lompat ke detik itu (juga setelah iklan) dan tidak autoplay playlist/radio.
public func playbackURL(_ url: URL, time: Double) -> URL {
    guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false), let host = c.host?.lowercased() else { return url }
    let id: String?
    if host == "youtu.be" {
        id = c.path.split(separator: "/").first.map(String.init)
    } else if host == "youtube.com" || host.hasSuffix(".youtube.com"), c.path == "/watch" {
        id = c.queryItems?.first { $0.name == "v" }?.value
    } else {
        return url
    }
    guard let id, !id.isEmpty else { return url }
    var out = URLComponents(string: "https://www.youtube.com/watch")!
    out.queryItems = [URLQueryItem(name: "v", value: id)]
    let secs = time.isFinite ? Int(time) : 0
    if secs > 0 { out.queryItems?.append(URLQueryItem(name: "t", value: "\(secs)s")) }
    return out.url ?? url
}
