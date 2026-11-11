import ActivityKit
import SwiftUI
import WidgetKit

private let captionGreen = Color(red: 102 / 255, green: 187 / 255, blue: 106 / 255)

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
                    recordedLine(context.state)
                }
                .frame(maxWidth: .infinity)
                recordButton
                HStack {
                    Spacer(minLength: 0)
                    Button(intent: StopFloatingIntent()) {
                        Label("关闭", systemImage: "xmark")
                    }
                    Spacer(minLength: 0)
                }
                .font(.caption2)
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
                    VStack(spacing: 6) {
                        recordedLine(context.state)
                        recordButton
                    }
                }
            } compactLeading: {
                Button(intent: LogArmedCaptionIntent()) {
                    Text("状态")
                        .font(.caption2.weight(.bold))
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            } compactTrailing: {
                Text(context.state.shortTimeText)
                    .font(.caption2.bold())
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
            } minimal: {
                Button(intent: LogArmedCaptionIntent()) {
                    Image(systemName: context.state.highlightedCaption.isEmpty ? "checkmark.circle" : "checkmark.circle.fill")
                }
                .buttonStyle(.plain)
            }
            .widgetURL(URL(string: "timefloat://open"))
        }
    }
}

@ViewBuilder
private func recordedLine(_ state: ClockActivityAttributes.ContentState) -> some View {
    if !state.highlightedCaption.isEmpty {
        Text("已记录 \(state.highlightedCaption)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(captionGreen, in: Capsule())
    } else {
        Text(CaptionRules.fixedCaption)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .multilineTextAlignment(.center)
    }
}

private var recordButton: some View {
    Button(intent: LogArmedCaptionIntent()) {
        Text(CaptionRules.fixedCaption)
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity)
    }
    .buttonStyle(.bordered)
    .tint(captionGreen)
}
