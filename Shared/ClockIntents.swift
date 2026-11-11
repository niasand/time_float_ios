import ActivityKit
import AppIntents
import Foundation

/// The widget extension and the app both compile this file.
/// Live Activity and Shortcuts run the intent in the app when it is alive (Picture in Picture keeps it alive).
/// The app installs `handler` so the tap hits the same session path as an in-app caption button.
/// If the handler is not installed yet, the App Group write still records the line and the highlight.
final class CaptionRecordingBox: @unchecked Sendable {
    var handler: (@MainActor (String) -> Void)?
}

enum CaptionRecording {
    static let box = CaptionRecordingBox()

    @MainActor
    static func record(_ caption: String) {
        let text = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if let handler = box.handler {
            handler(text)
        } else {
            _ = CaptionLogger.log(caption: text)
        }
    }
}

/// Runs inside the widget extension as well as the app, so it works from the Lock Screen,
/// Dynamic Island, Home Screen widget, Control Center, and Shortcuts without a push entitlement.
struct LogArmedCaptionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "记录当前字幕"
    static var description = IntentDescription("把悬浮时钟当前选中的字幕追加到 SRT 日志。")
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let caption = CaptionRules.fixedCaption
        await CaptionRecording.record(caption)
        await Self.refreshActivities()
        return .result(dialog: "已记录 \(caption)")
    }

    static func refreshActivities() async {
        let state = ClockActivityAttributes.currentState()
        let content = ActivityContent(state: state, staleDate: nil)
        for activity in Activity<ClockActivityAttributes>.activities {
            await activity.update(content)
        }
    }
}

struct StopFloatingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "关闭悬浮时钟"
    static var description = IntentDescription("关闭画中画悬浮时钟。")
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    func perform() async throws -> some IntentResult {
        ClockPreferences.setEnabled(false)
        DarwinBridge.post()
        for activity in Activity<ClockActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return .result()
    }
}

