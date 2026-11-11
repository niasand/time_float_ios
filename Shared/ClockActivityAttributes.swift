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
        var captions: [String]
        var armedIndex: Int

        /// Armed caption first, then the rest, capped so the island and Lock Screen can lay them out.
        func recordableCaptions(limit: Int) -> [String] {
            guard limit > 0 else { return [] }
            var ordered: [String] = []
            if captions.indices.contains(armedIndex) {
                ordered.append(captions[armedIndex])
            } else if !armedCaption.isEmpty {
                ordered.append(armedCaption)
            }
            for caption in captions where !ordered.contains(caption) {
                ordered.append(caption)
            }
            if ordered.isEmpty, !armedCaption.isEmpty {
                ordered.append(armedCaption)
            }
            return Array(ordered.prefix(limit))
        }

        private enum CodingKeys: String, CodingKey {
            case dateText, timeText, shortTimeText, armedCaption, highlightedCaption, offsetDescription, captions, armedIndex
        }

        init(
            dateText: String,
            timeText: String,
            shortTimeText: String,
            armedCaption: String,
            highlightedCaption: String,
            offsetDescription: String,
            captions: [String],
            armedIndex: Int
        ) {
            self.dateText = dateText
            self.timeText = timeText
            self.shortTimeText = shortTimeText
            self.armedCaption = armedCaption
            self.highlightedCaption = highlightedCaption
            self.offsetDescription = offsetDescription
            self.captions = captions
            self.armedIndex = armedIndex
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            dateText = try container.decodeIfPresent(String.self, forKey: .dateText) ?? ""
            timeText = try container.decodeIfPresent(String.self, forKey: .timeText) ?? ""
            shortTimeText = try container.decodeIfPresent(String.self, forKey: .shortTimeText) ?? ""
            armedCaption = try container.decodeIfPresent(String.self, forKey: .armedCaption) ?? ""
            highlightedCaption = try container.decodeIfPresent(String.self, forKey: .highlightedCaption) ?? ""
            offsetDescription = try container.decodeIfPresent(String.self, forKey: .offsetDescription) ?? ""
            captions = try container.decodeIfPresent([String].self, forKey: .captions) ?? []
            armedIndex = try container.decodeIfPresent(Int.self, forKey: .armedIndex) ?? 0
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(dateText, forKey: .dateText)
            try container.encode(timeText, forKey: .timeText)
            try container.encode(shortTimeText, forKey: .shortTimeText)
            try container.encode(armedCaption, forKey: .armedCaption)
            try container.encode(highlightedCaption, forKey: .highlightedCaption)
            try container.encode(offsetDescription, forKey: .offsetDescription)
            try container.encode(captions, forKey: .captions)
            try container.encode(armedIndex, forKey: .armedIndex)
        }
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
            ),
            captions: settings.captions,
            armedIndex: settings.armedIndex
        )
    }
}
