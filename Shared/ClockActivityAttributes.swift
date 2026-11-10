import ActivityKit
import Foundation

struct ClockActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var dateText: String
        var timeText: String
        var shortTimeText: String
        var armedCaption: String
        var highlightedCaption: String
        var offsetDescription: String
    }

    var title: String

    static func currentState(now: Date = Date()) -> ContentState {
        let settings = ClockPreferences.loadSettings()
        let sync = ClockPreferences.loadSync()
        let corrected = settings.corrected(now, offset: sync.offset)
        return ContentState(
            dateText: ClockFaceText.dateLine(corrected),
            timeText: ClockFaceText.timeLine(corrected, milliseconds: settings.showMilliseconds),
            shortTimeText: ClockFaceText.timeLine(corrected, milliseconds: false),
            armedCaption: settings.armedCaption,
            highlightedCaption: ClockPreferences.currentHighlight(now: now) ?? "",
            offsetDescription: ClockFaceText.offsetLine(
                useNetworkTime: settings.useNetworkTime,
                offset: sync.offset
            )
        )
    }
}
