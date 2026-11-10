import UIKit

struct ChipFrame: Equatable {
    var caption: String
    var rect: CGRect
    var highlighted: Bool
}

struct ClockLayout: Equatable {
    var size: CGSize
    var dateFrame: CGRect
    var timeFrame: CGRect
    var chips: [ChipFrame]
}

enum ClockDrawing {
    static let highlight = UIColor(red: 102 / 255, green: 187 / 255, blue: 106 / 255, alpha: 1)
    private static let corner: CGFloat = 14
    private static let horizontalPad: CGFloat = 16
    private static let verticalPad: CGFloat = 10
    private static let columnGap: CGFloat = 10
    private static let chipGap: CGFloat = 4
    private static let chipPadX: CGFloat = 10
    private static let chipPadY: CGFloat = 4

    static func layout(settings: ClockSettings, dateText: String, timeText: String, highlighted: String?) -> ClockLayout {
        let timeFont = UIFont.monospacedDigitSystemFont(ofSize: CGFloat(settings.fontSize), weight: .bold)
        let dateFont = UIFont.monospacedDigitSystemFont(ofSize: CGFloat(settings.fontSize) * 0.55, weight: .regular)
        let chipPoint = max(9, CGFloat(settings.fontSize) * 0.5)
        let dateSize = measure(dateText, font: dateFont)
        let timeSize = measure(timeText, font: timeFont)
        let columnWidth = max(dateSize.width, timeSize.width)
        let dateFrame = CGRect(x: 0, y: 0, width: columnWidth, height: dateSize.height)
        let timeFrame = CGRect(x: 0, y: dateSize.height + 2, width: columnWidth, height: timeSize.height)
        let columnHeight = timeFrame.maxY

        let captions = settings.showCaptionsInFloat ? settings.captions : []
        var chips: [ChipFrame] = []
        var chipsWidth: CGFloat = 0
        var chipsHeight: CGFloat = 0
        for caption in captions {
            let highlightedChip = caption == highlighted
            let font = UIFont.monospacedDigitSystemFont(ofSize: chipPoint, weight: highlightedChip ? .bold : .regular)
            let text = measure(caption, font: font)
            let size = CGSize(width: text.width + chipPadX * 2, height: text.height + chipPadY * 2)
            chipsWidth = max(chipsWidth, size.width)
            chipsHeight += size.height
            chips.append(ChipFrame(caption: caption, rect: CGRect(origin: .zero, size: size), highlighted: highlightedChip))
        }
        if chips.count > 1 {
            chipsHeight += chipGap * CGFloat(chips.count - 1)
        }

        let contentHeight = max(columnHeight, chipsHeight)
        var width = horizontalPad * 2 + columnWidth
        if !chips.isEmpty {
            width += columnGap + chipsWidth
        }
        let height = verticalPad * 2 + contentHeight
        let size = CGSize(width: ceil(max(width, 180)), height: ceil(max(height, 88)))

        let extraX = size.width - width
        let columnX = horizontalPad + extraX / 2
        let columnY = verticalPad + (contentHeight - columnHeight) / 2
        let placedDate = dateFrame.offsetBy(dx: columnX, dy: columnY)
        let placedTime = timeFrame.offsetBy(dx: columnX, dy: columnY)

        var placedChips: [ChipFrame] = []
        if !chips.isEmpty {
            var y = verticalPad + (contentHeight - chipsHeight) / 2
            let chipX = columnX + columnWidth + columnGap
            for chip in chips {
                let rect = CGRect(x: chipX, y: y, width: chip.rect.width, height: chip.rect.height)
                placedChips.append(ChipFrame(caption: chip.caption, rect: rect, highlighted: chip.highlighted))
                y += chip.rect.height + chipGap
            }
        }

        return ClockLayout(size: size, dateFrame: placedDate, timeFrame: placedTime, chips: placedChips)
    }

    static func image(
        settings: ClockSettings,
        dateText: String,
        timeText: String,
        highlighted: String?,
        scale: CGFloat
    ) -> (UIImage, ClockLayout) {
        let layout = layout(settings: settings, dateText: dateText, timeText: timeText, highlighted: highlighted)
        let base = RGB.from(hex: settings.colorHex)
        let blended = base.blendedOverBlack(alpha: Double(settings.alphaPercent) / 100)
        let background = uiColor(blended)
        let textColor: UIColor = base.prefersDarkText ? .black : .white
        let chipPoint = max(9, CGFloat(settings.fontSize) * 0.5)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: layout.size, format: format)
        let image = renderer.image { context in
            background.setFill()
            context.fill(CGRect(origin: .zero, size: layout.size))

            let dateFont = UIFont.monospacedDigitSystemFont(ofSize: CGFloat(settings.fontSize) * 0.55, weight: .regular)
            let timeFont = UIFont.monospacedDigitSystemFont(ofSize: CGFloat(settings.fontSize), weight: .bold)
            draw(dateText, in: layout.dateFrame, font: dateFont, color: textColor, alignment: .center)
            draw(timeText, in: layout.timeFrame, font: timeFont, color: textColor, alignment: .center)

            for chip in layout.chips {
                let chipColor: UIColor = chip.highlighted
                    ? highlight
                    : (base.prefersDarkText ? UIColor.black.withAlphaComponent(0x22 / 255) : UIColor.white.withAlphaComponent(0x33 / 255))
                let path = UIBezierPath(roundedRect: chip.rect, cornerRadius: 8)
                chipColor.setFill()
                path.fill()
                let font = UIFont.monospacedDigitSystemFont(
                    ofSize: chipPoint,
                    weight: chip.highlighted ? .bold : .regular
                )
                let chipText: UIColor = chip.highlighted ? .white : textColor
                draw(chip.caption, in: chip.rect, font: font, color: chipText, alignment: .center)
            }
        }
        return (image, layout)
    }

    private static func measure(_ text: String, font: UIFont) -> CGSize {
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: 2000, height: 400),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return CGSize(width: ceil(bounds.width), height: ceil(bounds.height))
    }

    private static func draw(_ text: String, in rect: CGRect, font: UIFont, color: UIColor, alignment: NSTextAlignment) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style
        ]
        let bounds = (text as NSString).boundingRect(
            with: rect.size,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        let origin = CGRect(
            x: rect.minX,
            y: rect.minY + (rect.height - ceil(bounds.height)) / 2,
            width: rect.width,
            height: ceil(bounds.height)
        )
        (text as NSString).draw(in: origin, withAttributes: attributes)
    }

    private static func uiColor(_ rgb: RGB) -> UIColor {
        UIColor(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1)
    }
}
