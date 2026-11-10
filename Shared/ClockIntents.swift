import ActivityKit
import AppIntents
import Foundation

/// Runs inside the widget extension as well as the app, so it works from the Lock Screen,
/// Dynamic Island, Home Screen widget, Control Center, and Shortcuts without a push entitlement.
struct LogArmedCaptionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "记录当前字幕"
    static var description = IntentDescription("把悬浮时钟当前选中的字幕追加到 SRT 日志。")
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    func perform() async throws -> some IntentResult {
        CaptionLogger.logArmed()
        await Self.refreshActivities()
        return .result()
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

/// Shortcuts can pass a specific marker, for example a Back Tap or Action Button shortcut per caption.
struct LogCaptionIntent: AppIntent {
    static var title: LocalizedStringResource = "记录指定字幕"
    static var description = IntentDescription("把一条指定字幕追加到 SRT 日志。")
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "字幕")
    var caption: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        if let error = CaptionLogger.log(caption: caption) {
            return .result(dialog: "\(error)")
        }
        await LogArmedCaptionIntent.refreshActivities()
        return .result(dialog: "已记录 \(caption)")
    }
}
