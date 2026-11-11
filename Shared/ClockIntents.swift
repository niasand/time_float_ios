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

struct CaptionStringOptions: DynamicOptionsProvider {
    func results() async throws -> [String] {
        ClockPreferences.loadSettings().captions
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
        let caption = ClockPreferences.loadSettings().armedCaption
        guard !caption.isEmpty else {
            return .result(dialog: "还没有字幕")
        }
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

struct CycleCaptionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "切换下一条字幕"
    static var description = IntentDescription("切换外部按钮将要记录的字幕。")
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    func perform() async throws -> some IntentResult {
        CaptionLogger.cycleArmed()
        await LogArmedCaptionIntent.refreshActivities()
        return .result()
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

/// One Live Activity button per caption, and the Shortcuts action that takes a caption parameter.
struct LogCaptionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "记录指定字幕"
    static var description = IntentDescription("把一条指定字幕追加到 SRT 日志。")
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "字幕", optionsProvider: CaptionStringOptions())
    var caption: String

    static var parameterSummary: some ParameterSummary {
        Summary("记录 \(\.$caption)")
    }

    init() {
        caption = ""
    }

    init(caption: String) {
        self.caption = caption
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return .result(dialog: "还没有字幕")
        }
        await CaptionRecording.record(text)
        await LogArmedCaptionIntent.refreshActivities()
        return .result(dialog: "已记录 \(text)")
    }
}
