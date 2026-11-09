import AppIntents

struct TimeFloatShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogArmedCaptionIntent(),
            phrases: [
                "用\(.applicationName)记录字幕",
                "用\(.applicationName)记一条"
            ],
            shortTitle: "记录字幕",
            systemImageName: "clock.badge.checkmark"
        )
    }
}
