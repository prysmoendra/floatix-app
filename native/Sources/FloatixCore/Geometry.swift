import CoreGraphics

public func initialFrame(visible: CGRect, aspect: Double) -> CGRect {
    let w = 480.0, margin = 24.0
    return CGRect(x: visible.maxX - margin - w, y: visible.minY + margin, width: w, height: w / aspect)
}
