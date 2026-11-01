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

// --- checks above this line ---
if failures > 0 { print("\(failures) CHECK GAGAL"); exit(1) }
print("ALL CHECKS PASSED")
