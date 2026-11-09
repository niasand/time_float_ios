import SwiftUI
import UIKit

struct ColorWheelRepresentable: UIViewRepresentable {
    var colorHex: Int
    var onPick: (Int) -> Void

    func makeUIView(context: Context) -> WheelUIView {
        let view = WheelUIView()
        view.setColor(hex: colorHex)
        view.onColorPicked = onPick
        return view
    }

    func updateUIView(_ uiView: WheelUIView, context: Context) {
        uiView.onColorPicked = onPick
        if !uiView.isTracking {
            uiView.setColor(hex: colorHex)
        }
    }
}

/// HSV disc: angle is hue, radius is saturation, value stays 1. Same model as the Android ColorWheelView.
final class WheelUIView: UIView {
    var onColorPicked: ((Int) -> Void)?
    private(set) var isTracking = false
    private var hue: CGFloat = 0
    private var saturation: CGFloat = 1
    private var wheelImage: UIImage?
    private var builtSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { return nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != builtSize, bounds.width > 2, bounds.height > 2 {
            builtSize = bounds.size
            let scale = max(1, traitCollection.displayScale)
            wheelImage = Self.makeWheel(diameter: floor(min(bounds.width, bounds.height) * scale), scale: scale)
        }
        setNeedsDisplay()
    }

    func setColor(hex: Int) {
        let hsv = RGB.from(hex: hex).hsvComponents()
        hue = hsv.h
        saturation = hsv.s
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let wheelImage else { return }
        let side = min(bounds.width, bounds.height)
        let origin = CGPoint(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2)
        wheelImage.draw(in: CGRect(x: origin.x, y: origin.y, width: side, height: side))
        let radius = side / 2 - 12
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let angle = hue * .pi / 180
        let point = CGPoint(
            x: center.x + cos(angle) * saturation * radius,
            y: center.y + sin(angle) * saturation * radius
        )
        let pointer = UIBezierPath(arcCenter: point, radius: 12, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        UIColor.white.setFill()
        pointer.fill()
        UIColor.black.setStroke()
        pointer.lineWidth = 2
        pointer.stroke()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        isTracking = true
        apply(touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        apply(touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        apply(touches)
        isTracking = false
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isTracking = false
    }

    private func apply(_ touches: Set<UITouch>) {
        guard let point = touches.first?.location(in: self) else { return }
        let side = min(bounds.width, bounds.height)
        let radius = side / 2 - 12
        guard radius > 0 else { return }
        let dx = point.x - bounds.midX
        let dy = point.y - bounds.midY
        let distance = min(radius, hypot(dx, dy))
        hue = (atan2(dy, dx) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
        saturation = distance / radius
        onColorPicked?(RGB.hsv(h: hue, s: saturation, v: 1).hex)
        setNeedsDisplay()
    }

    private static func makeWheel(diameter: CGFloat, scale: CGFloat) -> UIImage? {
        let dimension = Int(diameter)
        guard dimension > 2 else { return nil }
        let radius = Double(dimension) / 2 - 12
        let half = Double(dimension) / 2
        var pixels = [UInt8](repeating: 0, count: dimension * dimension * 4)
        for y in 0..<dimension {
            for x in 0..<dimension {
                let dx = Double(x) + 0.5 - half
                let dy = Double(y) + 0.5 - half
                let distance = hypot(dx, dy)
                let index = (y * dimension + x) * 4
                guard distance <= radius else { continue }
                let hue = (atan2(dy, dx) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
                let rgb = RGB.hsv(h: hue, s: distance / radius, v: 1)
                pixels[index] = UInt8((rgb.r * 255).rounded())
                pixels[index + 1] = UInt8((rgb.g * 255).rounded())
                pixels[index + 2] = UInt8((rgb.b * 255).rounded())
                pixels[index + 3] = 255
            }
        }
        let data = Data(pixels)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        guard let image = CGImage(
            width: dimension,
            height: dimension,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: dimension * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else { return nil }
        return UIImage(cgImage: image, scale: scale, orientation: .up)
    }
}
