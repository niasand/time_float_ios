import Foundation

/// RGB in 0...1. The floating clock stores the background as a 0xRRGGBB integer, matching the Android app.
struct RGB: Equatable {
    var r: Double
    var g: Double
    var b: Double

    var hex: Int {
        func byte(_ channel: Double) -> Int {
            Int((min(1, max(0, channel)) * 255).rounded())
        }
        return (byte(r) << 16) | (byte(g) << 8) | byte(b)
    }

    static func from(hex: Int) -> RGB {
        RGB(
            r: Double((hex >> 16) & 0xFF) / 255,
            g: Double((hex >> 8) & 0xFF) / 255,
            b: Double(hex & 0xFF) / 255
        )
    }

    /// Same weights as the Android overlay (`0.299 R + 0.587 G + 0.114 B`).
    var luminance: Double { 0.299 * r + 0.587 * g + 0.114 * b }

    /// Android uses white text unless the background luminance is above 0.6.
    var prefersDarkText: Bool { luminance > 0.6 }

    /// Hue 0...360, saturation 0...1, value 0...1. Value is ignored by the color wheel, same as Android.
    static func hsv(h: Double, s: Double, v: Double) -> RGB {
        let hue = ((h.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
        let sat = min(1, max(0, s))
        let val = min(1, max(0, v))
        let sector = hue / 60
        let c = val * sat
        let x = c * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
        let m = val - c
        let prime: (Double, Double, Double)
        switch Int(sector) {
        case 0: prime = (c, x, 0)
        case 1: prime = (x, c, 0)
        case 2: prime = (0, c, x)
        case 3: prime = (0, x, c)
        case 4: prime = (x, 0, c)
        default: prime = (c, 0, x)
        }
        return RGB(r: prime.0 + m, g: prime.1 + m, b: prime.2 + m)
    }

    func hsvComponents() -> (h: Double, s: Double, v: Double) {
        let maxV = max(r, g, b)
        let minV = min(r, g, b)
        let delta = maxV - minV
        let sat = maxV == 0 ? 0 : delta / maxV
        var hue = 0.0
        if delta > 0.00001 {
            if maxV == r {
                hue = 60 * (((g - b) / delta).truncatingRemainder(dividingBy: 6))
            } else if maxV == g {
                hue = 60 * (((b - r) / delta) + 2)
            } else {
                hue = 60 * (((r - g) / delta) + 4)
            }
        }
        if hue < 0 { hue += 360 }
        return (hue, sat, maxV)
    }

    /// Blend this color over black by `alpha` (0...1) and return an opaque result.
    /// Picture in Picture does not composite a transparent video over other apps.
    func blendedOverBlack(alpha: Double) -> RGB {
        let a = min(1, max(0, alpha))
        return RGB(r: r * a, g: g * a, b: b * a)
    }
}
