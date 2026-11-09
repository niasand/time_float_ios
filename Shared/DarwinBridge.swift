import Foundation

/// Cross-process ping. The widget extension posts it after a caption is logged; the running app
/// (kept alive by Picture in Picture) reloads the highlight and redraws the floating clock.
enum DarwinBridge {
    static func post() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(AppIdentity.darwinEventName as CFString),
            nil,
            nil,
            true
        )
    }
}
