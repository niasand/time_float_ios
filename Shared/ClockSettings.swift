import Foundation

struct ClockSettings: Equatable {
    var colorHex: Int = 0x2E2E2E
    var alphaPercent: Int = 100
    var fontSize: Int = 24
    var captions: [String] = CaptionRules.defaults
    var showMilliseconds: Bool = false
    var useNetworkTime: Bool = true
    var showCaptionsInFloat: Bool = true
    var keepAwake: Bool = true
    var mixWithOtherAudio: Bool = true
    var armedIndex: Int = 0

    static let minAlpha = 20
    static let maxAlpha = 100
    static let minFont = 12
    static let maxFont = 48
    static let defaultColor = 0x2E2E2E

    var armedCaption: String {
        guard captions.indices.contains(armedIndex) else { return captions.first ?? "" }
        return captions[armedIndex]
    }

    func corrected(_ date: Date, offset: TimeInterval) -> Date {
        useNetworkTime ? date.addingTimeInterval(offset) : date
    }
}

struct SyncRecord: Equatable {
    var offset: TimeInterval = 0
    var delay: TimeInterval = 0
    var source: String = ""
    var at: Date?

    var hasValue: Bool { at != nil && !source.isEmpty }
}

/// UserDefaults keys shared with the widget extension. Highlight and time-sync are stored separately
/// so a settings save cannot clobber a caption tap that landed in the other process.
enum ClockPreferences {
    private enum Key {
        static let seeded = "captions_seeded"
        static let enabled = "enabled"
        static let color = "color"
        static let alpha = "alpha"
        static let font = "font_sp"
        static let posX = "pos_x"
        static let posY = "pos_y"
        static let captions = "captions"
        static let showMilliseconds = "show_ms"
        static let useNetworkTime = "use_network_time"
        static let showCaptions = "show_captions_in_float"
        static let keepAwake = "keep_awake"
        static let mixAudio = "mix_audio"
        static let armedIndex = "armed_index"
        static let highlightCaption = "highlight_caption"
        static let highlightUntil = "highlight_until"
        static let offset = "offset_sec"
        static let delay = "sync_delay"
        static let syncSource = "sync_source"
        static let syncAt = "sync_at"
    }

    private static var defaults: UserDefaults { AppIdentity.sharedDefaults }

    static func isEnabled() -> Bool { defaults.bool(forKey: Key.enabled) }

    static func setEnabled(_ value: Bool) {
        defaults.set(value, forKey: Key.enabled)
        defaults.synchronize()
    }

    static func loadSettings() -> ClockSettings {
        var settings = ClockSettings()
        if defaults.object(forKey: Key.color) != nil {
            settings.colorHex = defaults.integer(forKey: Key.color)
        }
        if defaults.object(forKey: Key.alpha) != nil {
            settings.alphaPercent = defaults.integer(forKey: Key.alpha)
        }
        if defaults.object(forKey: Key.font) != nil {
            settings.fontSize = defaults.integer(forKey: Key.font)
        }
        settings.alphaPercent = min(ClockSettings.maxAlpha, max(ClockSettings.minAlpha, settings.alphaPercent))
        settings.fontSize = min(ClockSettings.maxFont, max(ClockSettings.minFont, settings.fontSize))
        settings.showMilliseconds = defaults.bool(forKey: Key.showMilliseconds)
        if defaults.object(forKey: Key.useNetworkTime) != nil {
            settings.useNetworkTime = defaults.bool(forKey: Key.useNetworkTime)
        }
        if defaults.object(forKey: Key.showCaptions) != nil {
            settings.showCaptionsInFloat = defaults.bool(forKey: Key.showCaptions)
        }
        if defaults.object(forKey: Key.keepAwake) != nil {
            settings.keepAwake = defaults.bool(forKey: Key.keepAwake)
        }
        if defaults.object(forKey: Key.mixAudio) != nil {
            settings.mixWithOtherAudio = defaults.bool(forKey: Key.mixAudio)
        }
        settings.captions = loadCaptions()
        settings.armedIndex = defaults.integer(forKey: Key.armedIndex)
        if !settings.captions.indices.contains(settings.armedIndex) {
            settings.armedIndex = 0
        }
        return settings
    }

    static func save(_ settings: ClockSettings) {
        var settings = settings
        settings.alphaPercent = min(ClockSettings.maxAlpha, max(ClockSettings.minAlpha, settings.alphaPercent))
        settings.fontSize = min(ClockSettings.maxFont, max(ClockSettings.minFont, settings.fontSize))
        settings.captions = CaptionRules.sanitized(settings.captions)
        if !settings.captions.indices.contains(settings.armedIndex) {
            settings.armedIndex = 0
        }
        defaults.set(settings.colorHex, forKey: Key.color)
        defaults.set(settings.alphaPercent, forKey: Key.alpha)
        defaults.set(settings.fontSize, forKey: Key.font)
        defaults.set(settings.showMilliseconds, forKey: Key.showMilliseconds)
        defaults.set(settings.useNetworkTime, forKey: Key.useNetworkTime)
        defaults.set(settings.showCaptionsInFloat, forKey: Key.showCaptions)
        defaults.set(settings.keepAwake, forKey: Key.keepAwake)
        defaults.set(settings.mixWithOtherAudio, forKey: Key.mixAudio)
        defaults.set(settings.armedIndex, forKey: Key.armedIndex)
        if let data = try? JSONEncoder().encode(settings.captions) {
            defaults.set(data, forKey: Key.captions)
        }
        defaults.set(true, forKey: Key.seeded)
        defaults.synchronize()
    }

    static func loadPosition() -> (x: Double, y: Double) {
        if defaults.object(forKey: Key.posX) == nil { return (-1, -1) }
        return (defaults.double(forKey: Key.posX), defaults.double(forKey: Key.posY))
    }

    static func savePosition(x: Double, y: Double) {
        defaults.set(x, forKey: Key.posX)
        defaults.set(y, forKey: Key.posY)
        defaults.synchronize()
    }

    static func setHighlight(caption: String, until: Date) {
        defaults.set(caption, forKey: Key.highlightCaption)
        defaults.set(until.timeIntervalSince1970, forKey: Key.highlightUntil)
        defaults.synchronize()
    }

    static func currentHighlight(now: Date = Date()) -> String? {
        guard let caption = defaults.string(forKey: Key.highlightCaption), !caption.isEmpty else { return nil }
        let until = defaults.double(forKey: Key.highlightUntil)
        guard until > now.timeIntervalSince1970 else { return nil }
        return caption
    }

    static func loadSync() -> SyncRecord {
        var record = SyncRecord()
        record.offset = defaults.double(forKey: Key.offset)
        record.delay = defaults.double(forKey: Key.delay)
        record.source = defaults.string(forKey: Key.syncSource) ?? ""
        let stamp = defaults.double(forKey: Key.syncAt)
        if stamp > 0 { record.at = Date(timeIntervalSince1970: stamp) }
        return record
    }

    static func saveSync(_ record: SyncRecord) {
        defaults.set(record.offset, forKey: Key.offset)
        defaults.set(record.delay, forKey: Key.delay)
        defaults.set(record.source, forKey: Key.syncSource)
        defaults.set(record.at?.timeIntervalSince1970 ?? 0, forKey: Key.syncAt)
        defaults.synchronize()
    }

    private static func loadCaptions() -> [String] {
        guard defaults.bool(forKey: Key.seeded) || defaults.data(forKey: Key.captions) != nil else {
            return CaptionRules.defaults
        }
        guard let data = defaults.data(forKey: Key.captions),
              let list = try? JSONDecoder().decode([String].self, from: data) else {
            return CaptionRules.defaults
        }
        return CaptionRules.sanitized(list)
    }
}
