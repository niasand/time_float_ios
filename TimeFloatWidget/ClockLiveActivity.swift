import ActivityKit
import SwiftUI
import WidgetKit

struct ClockLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClockActivityAttributes.self) { context in
            VStack(spacing: 8) {
                VStack(spacing: 2) {
                    Text(context.state.dateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text(context.state.timeText)
                        .font(.title.bold())
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .multilineTextAlignment(.center)
                    Text(context.state.offsetDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                if !context.state.highlightedCaption.isEmpty {
                    Text(context.state.highlightedCaption)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(red: 102 / 255, green: 187 / 255, blue: 106 / 255), in: Capsule())
                } else if !context.state.armedCaption.isEmpty {
                    Text(context.state.armedCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                HStack {
                    Spacer(minLength: 0)
                    Button(intent: CycleCaptionIntent()) {
                        Label("下一条", systemImage: "arrow.right")
                    }
                    Button(intent: LogArmedCaptionIntent()) {
                        Text(context.state.armedCaption.isEmpty ? "记录" : "记录 \(context.state.armedCaption)")
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 102 / 255, green: 187 / 255, blue: 106 / 255))
                    Button(intent: StopFloatingIntent()) {
                        Label("关闭", systemImage: "xmark")
                    }
                    Spacer(minLength: 0)
                }
                .font(.caption)
            }
            .frame(maxWidth: .infinity)
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
