import SwiftUI
import WidgetKit

struct ClockEntry: TimelineEntry {
    let date: Date
    let colorHex: Int
    let offsetMs: Int
    let networkOn: Bool
    let armedCaption: String
    let syncSource: String
}

struct ClockProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClockEntry { makeEntry(at: Date()) }

    func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        completion(makeEntry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        let now = Date()
        let entries = (0..<180).compactMap { minute -> ClockEntry? in
            guard let date = Calendar(identifier: .gregorian).date(byAdding: .minute, value: minute, to: now) else { return nil }
            return makeEntry(at: date)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func makeEntry(at date: Date) -> ClockEntry {
        let settings = ClockPreferences.loadSettings()
        let sync = ClockPreferences.loadSync()
        let corrected = settings.corrected(date, offset: sync.offset)
        return ClockEntry(
            date: corrected,
            colorHex: settings.colorHex,
            offsetMs: Int((sync.offset * 1000).rounded()),
            networkOn: settings.useNetworkTime && sync.hasValue,
            armedCaption: settings.armedCaption,
            syncSource: sync.source
        )
    }
}

struct TimeFloatClockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "timefloat.clock", provider: ClockProvider()) { entry in
            ClockWidgetView(entry: entry)
        }
        .configurationDisplayName("悬浮时钟")
        .description("主屏幕和锁屏上的日期与时间。秒和毫秒请看 App 或画中画。")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

private struct ClockWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: ClockEntry

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if family == .systemSmall || family == .systemMedium {
                    Color(hex: entry.colorHex)
                } else {
                    AccessoryWidgetBackground()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Text(ClockFaceText.timeLine(entry.date, milliseconds: false))
                .multilineTextAlignment(.center)
        case .accessoryCircular:
            Text(ClockFaceText.timeLine(entry.date, milliseconds: false))
                .font(.headline.bold())
                .monospacedDigit()
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        case .accessoryRectangular:
            VStack(spacing: 2) {
                Text(ClockFaceText.dateLine(entry.date))
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                Text(ClockFaceText.timeLine(entry.date, milliseconds: false))
                    .font(.headline.bold())
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .multilineTextAlignment(.center)
                Button(intent: LogArmedCaptionIntent()) {
                    Text(recordTitle)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        case .systemMedium:
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(ClockFaceText.dateLine(entry.date))
                        .font(.subheadline)
                    Text(ClockFaceText.timeLine(entry.date, milliseconds: false))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(statusLine)
                        .font(.caption)
                }
                Spacer(minLength: 8)
                Button(intent: LogArmedCaptionIntent()) {
                    Text(recordTitle)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(width: 108)
                }
                .buttonStyle(.bordered)
            }
            .foregroundStyle(foreground)
        default:
            VStack(alignment: .leading, spacing: 6) {
                Text(ClockFaceText.dateLine(entry.date))
                    .font(.caption)
                Text(ClockFaceText.timeLine(entry.date, milliseconds: false))
                    .font(.title.bold())
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(statusLine)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .foregroundStyle(foreground)
        }
    }

    private var recordTitle: String {
        entry.armedCaption.isEmpty ? "记录" : "记录 \(entry.armedCaption)"
    }

    private var statusLine: String {
        guard entry.networkOn else { return "设备时间" }
        if abs(entry.offsetMs) < 5 { return "已校正" }
        return entry.offsetMs > 0 ? "设备慢 \(entry.offsetMs) ms" : "设备快 \(-entry.offsetMs) ms"
    }

    private var foreground: Color {
        RGB.from(hex: entry.colorHex).prefersDarkText ? .black : .white
    }
}

private extension Color {
    init(hex: Int) {
        let rgb = RGB.from(hex: hex)
        self.init(red: rgb.r, green: rgb.g, blue: rgb.b)
    }
}
