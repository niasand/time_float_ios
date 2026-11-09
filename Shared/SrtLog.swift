import Foundation

enum SrtLog {
    private static let lock = NSLock()

    static func append(caption: String, at date: Date, milliseconds: Bool) throws {
        let line = ClockFaceText.srtLine(date: date, caption: caption, milliseconds: milliseconds)
        guard let data = line.data(using: .utf8) else { return }
        let url = AppIdentity.srtURL
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forMerging, error: &coordinationError) { writingURL in
            lock.lock()
            defer { lock.unlock() }
            do {
                if FileManager.default.fileExists(atPath: writingURL.path) {
                    let handle = try FileHandle(forWritingTo: writingURL)
                    defer { try? handle.close() }
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                } else {
                    try data.write(to: writingURL, options: .atomic)
                }
            } catch {
                writeError = error
            }
        }
        if let coordinationError { throw coordinationError }
        if let writeError { throw writeError }
    }

    static func tail(maxLines: Int) -> [String] {
        let url = AppIdentity.srtURL
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        return Array(lines.suffix(maxLines))
    }

    static func lineCount() -> Int {
        let url = AppIdentity.srtURL
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return 0 }
        return text.split(whereSeparator: \.isNewline).count
    }

    static func clear() throws {
        let url = AppIdentity.srtURL
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

enum CaptionLogger {
    /// Wall-clock highlight duration, same 3 seconds as the Android overlay.
    static let highlightSeconds: TimeInterval = 3

    @discardableResult
    static func log(caption: String, now: Date = Date()) -> String? {
        let text = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "字幕不能为空" }
        let settings = ClockPreferences.loadSettings()
        let sync = ClockPreferences.loadSync()
        let stamped = settings.corrected(now, offset: sync.offset)
        do {
            try SrtLog.append(caption: text, at: stamped, milliseconds: settings.showMilliseconds)
        } catch {
            return "SRT 写入失败"
        }
        ClockPreferences.setHighlight(caption: text, until: Date().addingTimeInterval(highlightSeconds))
        DarwinBridge.post()
        return nil
    }

    @discardableResult
    static func logArmed(now: Date = Date()) -> String? {
        let settings = ClockPreferences.loadSettings()
        guard !settings.armedCaption.isEmpty else { return "还没有字幕" }
        return log(caption: settings.armedCaption, now: now)
    }

    static func cycleArmed() {
        var settings = ClockPreferences.loadSettings()
        guard !settings.captions.isEmpty else { return }
        settings.armedIndex = (settings.armedIndex + 1) % settings.captions.count
        ClockPreferences.save(settings)
        DarwinBridge.post()
    }
}
