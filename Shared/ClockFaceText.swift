import Foundation

/// Thread-safe clock strings. Avoids DateFormatter, which is not safe to share across the render loop and widget intents.
enum ClockFaceText {
    static func dateLine(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .current
        calendar.timeZone = .current
        let c = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
        let weekdayIndex = max(1, min(7, c.weekday ?? 1)) - 1
        let weekday = calendar.shortWeekdaySymbols[weekdayIndex]
        return String(format: "%04d-%02d-%02d %@", c.year ?? 0, c.month ?? 0, c.day ?? 0, weekday)
    }

    static func timeLine(_ date: Date, milliseconds: Bool) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        if !milliseconds {
            let c = calendar.dateComponents([.hour, .minute, .second], from: date)
            return String(format: "%02d:%02d:%02d", c.hour ?? 0, c.minute ?? 0, c.second ?? 0)
        }
        let msEpoch = Int((date.timeIntervalSince1970 * 1000).rounded())
        let shown = Date(timeIntervalSince1970: Double(msEpoch) / 1000)
        let c = calendar.dateComponents([.hour, .minute, .second], from: shown)
        let ms = ((msEpoch % 1000) + 1000) % 1000
        return String(format: "%02d:%02d:%02d.%03d", c.hour ?? 0, c.minute ?? 0, c.second ?? 0, ms)
    }

    static func srtLine(date: Date, caption: String, milliseconds: Bool) -> String {
        let stamped = milliseconds
            ? Date(timeIntervalSince1970: (date.timeIntervalSince1970 * 1000).rounded() / 1000)
            : date
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let c = calendar.dateComponents([.year, .month, .day], from: stamped)
        let day = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        let clock = timeLine(stamped, milliseconds: milliseconds)
        // Fullwidth colon, matching the Android file: "2026-11-07 14:25:30：停车前"
        return "\(day) \(clock)：\(caption)\n"
    }

    static func offsetLine(useNetworkTime: Bool, offset: TimeInterval) -> String {
        let ms = Int((offset * 1000).rounded())
        if !useNetworkTime { return "设备时间" }
        if abs(ms) < 5 { return "已校正 \(ms) ms" }
        if ms > 0 { return "设备慢 \(ms) ms" }
        return "设备快 \(-ms) ms"
    }
}
