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
                captionButtons(context.state.recordableCaptions(limit: 8), highlighted: context.state.highlightedCaption, prominent: context.state.armedCaption)
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
                        captionButtons(context.state.recordableCaptions(limit: 4), highlighted: context.state.highlightedCaption, prominent: context.state.armedCaption)
                    }
                }
            } compactLeading: {
                armedRecordButton(context.state, showsTitle: true)
            } compactTrailing: {
                Text(context.state.shortTimeText)
                    .font(.caption2.bold())
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
            } minimal: {
                armedRecordButton(context.state, showsTitle: false)
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
    } else if !state.armedCaption.isEmpty {
        Text("选中 \(state.armedCaption)")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .multilineTextAlignment(.center)
    }
}

@ViewBuilder
private func captionButtons(_ captions: [String], highlighted: String, prominent: String) -> some View {
    if captions.isEmpty {
        Text("还没有字幕")
            .font(.caption2)
            .foregroundStyle(.secondary)
    } else {
        let rows = stride(from: 0, to: captions.count, by: 4).map { start in
            Array(captions[start..<min(start + 4, captions.count)])
        }
        VStack(spacing: 4) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 4) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, caption in
                        Button(intent: LogCaptionIntent(caption: caption)) {
                            Text(caption)
                                .font(.caption2.weight(caption == highlighted ? .bold : .regular))
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(caption == highlighted || caption == prominent ? captionGreen : Color.white.opacity(0.35))
                    }
                }
            }
        }
    }
}

@ViewBuilder
private func armedRecordButton(_ state: ClockActivityAttributes.ContentState, showsTitle: Bool) -> some View {
    let caption = state.armedCaption.isEmpty ? (state.captions.first ?? "") : state.armedCaption
    let shown = state.highlightedCaption.isEmpty ? caption : state.highlightedCaption
    if caption.isEmpty {
        Image(systemName: "clock.fill")
    } else if showsTitle {
        Button(intent: LogCaptionIntent(caption: caption)) {
            Text(String(shown.prefix(3)))
                .font(.caption2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .buttonStyle(.plain)
    } else {
        Button(intent: LogCaptionIntent(caption: caption)) {
            Image(systemName: state.highlightedCaption.isEmpty ? "checkmark.circle" : "checkmark.circle.fill")
        }
        .buttonStyle(.plain)
    }
}
