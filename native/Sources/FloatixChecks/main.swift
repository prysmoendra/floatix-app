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

// --- checks above this line ---
if failures > 0 { print("\(failures) CHECK GAGAL"); exit(1) }
print("ALL CHECKS PASSED")
