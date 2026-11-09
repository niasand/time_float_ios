import Foundation

/// Bundle id, App Group, and on-disk locations shared by the app and the widget.
/// The group id is written into both Info.plists from `APP_GROUP_ID` in Config/Shared.xcconfig.
enum AppIdentity {
    static let fallbackAppGroupID = "group.com.yourname.timefloat"
    static let darwinEventName = "com.yourname.timefloat.event"
    static let srtDirectoryName = "TimeFloat"
    static let srtFileName = "road_test_srt.srt"

    static var appGroupID: String {
        let raw = Bundle.main.object(forInfoDictionaryKey: "TimeFloatAppGroup") as? String
        guard let raw, !raw.isEmpty, !raw.contains("$") else { return fallbackAppGroupID }
        return raw
    }

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    /// Nil when the App Group entitlement is missing or the profile does not include it.
    static var groupContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    static var usesAppGroup: Bool { groupContainerURL != nil }

    /// Source of truth for the SRT file. Widget intents can only see this when the App Group exists.
    static var storageDirectory: URL {
        let base: URL
        if let container = groupContainerURL {
            base = container
        } else {
            base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        }
        let dir = base.appendingPathComponent(srtDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var srtURL: URL {
        storageDirectory.appendingPathComponent(srtFileName)
    }
}
