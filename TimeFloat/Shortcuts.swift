import AppIntents

struct TimeFloatShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogArmedCaptionIntent(),
            phrases: [
                "用\(.applicationName)记录字幕",
                "用\(.applicationName)记录当前字幕",
                "用\(.applicationName)记一条"
            ],
            shortTitle: "记录字幕",
            systemImageName: "clock.badge.checkmark"
        )
        AppShortcut(
            intent: LogCaptionIntent(),
            phrases: [
                "用\(.applicationName)记录\(\.$caption)",
                "用\(.applicationName)记下\(\.$caption)"
            ],
            shortTitle: "记录指定字幕",
            systemImageName: "text.badge.checkmark"
        )
    }
}
