import Foundation

public enum FloatixError: Error, Equatable {
    case frameTooLarge(Int)
    case invalidMessage(String)
    case invalidURL(String)
}

/// 4 byte panjang (UInt32 little-endian) + payload.
public func encodeFrame(_ payload: Data) -> Data {
    var len = UInt32(payload.count).littleEndian
    return Data(bytes: &len, count: 4) + payload
}

public struct FrameDecoder {
    private var buffer = Data()
    private let maxLength: Int

    public init(maxLength: Int = 64 * 1024 * 1024) { self.maxLength = maxLength }

    /// Mengembalikan payload lengkap; header terlalu besar setelah frame valid ditahan dan dilempar di panggilan berikutnya (lalu terus dilempar).
    public mutating func append(_ chunk: Data) throws -> [Data] {
        buffer.append(chunk)
        var out: [Data] = []
        while buffer.count >= 4 {
            let b = buffer.startIndex
            let raw = UInt32(buffer[b]) | UInt32(buffer[b + 1]) << 8
                | UInt32(buffer[b + 2]) << 16 | UInt32(buffer[b + 3]) << 24
            let len = Int(raw)
            if len > maxLength {
                if out.isEmpty { throw FloatixError.frameTooLarge(len) }
                break
            }
            guard buffer.count >= 4 + len else { break }
            out.append(Data(buffer[(b + 4)..<(b + 4 + len)]))
            buffer = Data(buffer.dropFirst(4 + len))
        }
        return out
    }
}
