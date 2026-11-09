import ActivityKit
import SwiftUI
import WidgetKit

struct ClockLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClockActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.dateText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(context.state.timeText)
                            .font(.title.bold())
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    Spacer(minLength: 8)
                    Text(context.state.offsetDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if !context.state.highlightedCaption.isEmpty {
                    Text(context.state.highlightedCaption)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(red: 102 / 255, green: 187 / 255, blue: 106 / 255), in: Capsule())
                }
                HStack {
                    Button(intent: CycleCaptionIntent()) {
                        Label("下一条", systemImage: "arrow.right")
                    }
                    Button(intent: LogArmedCaptionIntent()) {
                        Text(context.state.armedCaption.isEmpty ? "记录" : "记录 \(context.state.armedCaption)")
                            .lineLimit(1)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 102 / 255, green: 187 / 255, blue: 106 / 255))
                    Button(intent: StopFloatingIntent()) {
                        Label("关闭", systemImage: "xmark")
                    }
                }
                .font(.caption)
            }
            .padding(.horizontal, 4)
            .activityBackgroundTint(Color(white: 0.12))
            .widgetURL(URL(string: "timefloat://open"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.dateText)
                        .font(.caption2)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.shortTimeText)
                        .font(.headline.bold())
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Button(intent: CycleCaptionIntent()) {
                            Text("下一条")
                        }
                        Button(intent: LogArmedCaptionIntent()) {
                            Text(context.state.armedCaption.isEmpty ? "记录" : context.state.armedCaption)
                                .lineLimit(1)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 102 / 255, green: 187 / 255, blue: 106 / 255))
                        Button(intent: StopFloatingIntent()) {
                            Text("关闭")
                        }
                    }
                    .font(.caption)
                }
            } compactLeading: {
                Image(systemName: "clock.fill")
            } compactTrailing: {
                Text(context.state.shortTimeText)
                    .font(.caption2.bold())
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
            } minimal: {
                Image(systemName: "clock.fill")
            }
            .widgetURL(URL(string: "timefloat://open"))
        }
    }
}
