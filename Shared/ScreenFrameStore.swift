import Foundation

/// The broadcast extension overwrites `latest_screen.jpg`. A caption tap copies that file
/// when it is fresh. This type is Foundation-only so the widget can use it too.
enum ScreenFrameStore {
    static let freshInterval: TimeInterval = 2

    static func latestIsFresh(now: Date = Date()) -> Bool {
        guard let values = try? AppIdentity.latestScreenURL.resourceValues(forKeys: [.contentModificationDateKey]),
              let modified = values.contentModificationDate else { return false }
        return now.timeIntervalSince(modified) <= freshInterval
    }

    /// Copies the broadcast frame into Screenshots/ and returns the file name, or nil.
    static func adoptLatest(caption: String, date: Date, enabled: Bool, now: Date = Date()) -> String? {
        guard enabled, latestIsFresh(now: now) else { return nil }
        let name = filename(caption: caption, date: date)
        let destination = AppIdentity.screenshotsDirectory.appendingPathComponent(name)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: AppIdentity.latestScreenURL, to: destination)
            return name
        } catch {
            return nil
        }
    }

    static func filename(caption: String, date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let stamp = String(
            format: "%04d-%02d-%02d_%02d-%02d-%02d",
            c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0, c.second ?? 0
        )
        let safe = caption.unicodeScalars.map { scalar -> Character in
            let cjk = (0x4E00...0x9FFF).contains(scalar.value)
            if CharacterSet.alphanumerics.contains(scalar) || scalar == "_" || cjk {
                return Character(scalar)
            }
            return "_"
        }
        let trimmed = String(safe).prefix(24)
        return "\(stamp)_\(trimmed).jpg"
    }
}
