import Foundation

enum TextLog {
    private static let lock = NSLock()

    static func append(caption: String, at date: Date, milliseconds: Bool, screenshot: String?) throws {
        let line = ClockFaceText.textLogLine(
            date: date,
            caption: caption,
            milliseconds: milliseconds,
            screenshot: screenshot
        )
        guard let data = line.data(using: .utf8) else { return }
        let url = AppIdentity.textLogURL
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
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

    static func clear() throws {
        let url = AppIdentity.textLogURL
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
