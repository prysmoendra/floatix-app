import Foundation
import FloatixCore

var failures = 0
func check(_ ok: Bool, _ name: String) {
    if ok { print("ok   \(name)") } else { failures += 1; print("FAIL \(name)") }
}

let hello = Data(#"{"a":1}"#.utf8)
let f = encodeFrame(hello)
check(f.prefix(4) == Data([7, 0, 0, 0]), "encode: panjang LE")
check(f.dropFirst(4) == hello, "encode: payload utuh")

var d = FrameDecoder()
check(try! d.append(f.prefix(3)).isEmpty, "decode: header terpotong ditahan")
check(try! d.append(f.dropFirst(3) + f) == [hello, hello], "decode: sisa + frame kedua")

var small = FrameDecoder(maxLength: 8)
do { _ = try small.append(Data([9, 0, 0, 0])); check(false, "decode: tolak > max") }
catch { check(error as? FloatixError == .frameTooLarge(9), "decode: tolak > max") }

var t = FrameDecoder()
check(try! t.append(f.prefix(6)).isEmpty, "decode: payload terpotong ditahan")
check(try! t.append(f.dropFirst(6)) == [hello], "decode: payload dilengkapi")

var one = FrameDecoder()
var got: [Data] = []
for byte in f { got += try! one.append(Data([byte])) }
check(got == [hello], "decode: chunk 1 byte")

var z = FrameDecoder()
check(try! z.append(Data([0, 0, 0, 0])) == [Data()], "decode: frame panjang nol")

var mix = FrameDecoder(maxLength: 8)
check(try! mix.append(f + Data([9, 0, 0, 0])) == [hello], "decode: frame valid dikembalikan dulu")
do { _ = try mix.append(Data()); check(false, "decode: header besar dilempar kemudian") }
catch { check(error as? FloatixError == .frameTooLarge(9), "decode: header besar dilempar kemudian") }
do { _ = try mix.append(Data([1])); check(false, "decode: lempar ulang") }
catch { check(error as? FloatixError == .frameTooLarge(9), "decode: lempar ulang") }

let open = try! decodeInbound(Data(#"{"type":"open","url":"https://youtu.be/x","time":-3}"#.utf8))
check(open == .open(OpenRequest(url: URL(string: "https://youtu.be/x")!, time: 0, aspect: 16.0/9)), "open: default + clamp time")
check(try! decodeInbound(Data(#"{"type":"open","url":"https://a.b","time":1,"aspect":99}"#.utf8))
      == .open(OpenRequest(url: URL(string: "https://a.b")!, time: 1, aspect: 4)), "open: clamp aspect")
check(try! decodeInbound(Data(#"{"type":"close"}"#.utf8)) == .close, "close")
check(try! decodeInbound(Data(#"{"type":"togglePlay"}"#.utf8)) == .togglePlay, "togglePlay")
check((try? decodeInbound(Data(#"{"type":"open","url":"file:///etc/passwd","time":0}"#.utf8))) == nil, "tolak file://")
check((try? decodeInbound(Data(#"{"type":"open","time":0}"#.utf8))) == nil, "tolak url hilang")
check((try? decodeInbound(Data(#"{"type":"zzz"}"#.utf8))) == nil, "tolak type tak dikenal")
check((try? decodeInbound(Data("{".utf8))) == nil, "tolak JSON rusak")
let out = String(decoding: encodeOutbound(.closed(time: 12.5)), as: UTF8.self)
check(out.contains(#""type":"closed""#) && out.contains("12.5"), "encode closed")
check(String(decoding: encodeOutbound(.ready), as: UTF8.self) == #"{"type":"ready"}"#, "encode ready")
check(String(decoding: encodeOutbound(.error("a\"b")), as: UTF8.self).contains(#""message":"a\"b""#), "encode error escape")
check(isolatorScript(startTime: 42.5).contains("42.5"), "isolator memuat waktu mulai")
check(isolatorScript(startTime: -1).contains("const start = 0.0;") && isolatorScript(startTime: .nan).contains("const start = 0.0;"), "isolator: negatif/NaN jadi 0")
check(initialFrame(visible: CGRect(x: 0, y: 0, width: 1440, height: 900), aspect: 16.0/9)
      == CGRect(x: 936, y: 24, width: 480, height: 270), "frame awal kanan bawah")

let yt = URL(string: "https://www.youtube.com/watch?v=B452TVVco2Q&list=RDB452TVVco2Q&start_radio=1")!
check(playbackURL(yt, time: 42.7) == URL(string: "https://www.youtube.com/watch?v=B452TVVco2Q&t=42s")!, "youtube: buang list, tambah t")
check(playbackURL(URL(string: "https://youtu.be/abc?si=x")!, time: 5) == URL(string: "https://www.youtube.com/watch?v=abc&t=5s")!, "youtu.be dinormalkan")
check(playbackURL(URL(string: "https://www.youtube.com/watch?v=abc")!, time: 0) == URL(string: "https://www.youtube.com/watch?v=abc")!, "youtube t=0 tanpa param t")
check(playbackURL(URL(string: "https://vimeo.com/1?x=1")!, time: 9) == URL(string: "https://vimeo.com/1?x=1")!, "non-youtube tidak diubah")
check(isolatorScript(startTime: 1).contains("ad-showing"), "isolator: tunda seek selama iklan youtube")
check(isolatorScript(startTime: 1).contains("['overflow', 'visible']"), "isolator: induk video tidak memotong video fixed")

check(adBlockScript.contains("adPlacements") && adBlockScript.contains("JSON.parse") && adBlockScript.contains("ytInitialPlayerResponse"), "adblock: scriptlet buang jadwal iklan")
let rules = (try? JSONSerialization.jsonObject(with: Data(adBlockRules.utf8))) as? [[String: Any]]
check(rules != nil && rules!.count >= 3, "adblock: aturan blokir JSON valid")
check(adBlockRules.contains("doubleclick") && adBlockRules.contains("pagead"), "adblock: blokir server iklan")
check(volumeScript(42).contains("setVolume(42)") && volumeScript(-5).contains("setVolume(0)") && volumeScript(500).contains("setVolume(100)"), "volume: di-clamp 0..100")

// --- checks above this line ---
if failures > 0 { print("\(failures) CHECK GAGAL"); exit(1) }
print("ALL CHECKS PASSED")
