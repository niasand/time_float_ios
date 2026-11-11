import Foundation

enum CaptionRules {
    static let maxCount = 16
    static let maxLength = 12

    /// The only caption. Saved lists are rewritten to this on load.
    static let fixedCaption = "状态变化时间点"
    static let defaults: [String] = [fixedCaption]

    enum AddError: Error, Equatable {
        case empty
        case tooLong(Int)
        case duplicate
        case full(Int)

        var message: String {
            switch self {
            case .empty: return "字幕不能为空"
            case .tooLong(let limit): return "最多 \(limit) 个字"
            case .duplicate: return "该字幕已存在"
            case .full(let limit): return "最多 \(limit) 条字幕"
            }
        }
    }

    static func sanitized(_ list: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in list {
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, !seen.contains(text) else { continue }
            seen.insert(text)
            result.append(text)
            if result.count == maxCount { break }
        }
        return result
    }

    static func adding(_ raw: String, to list: [String]) -> Result<[String], AddError> {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return .failure(.empty) }
        if text.count > maxLength { return .failure(.tooLong(maxLength)) }
        if list.contains(text) { return .failure(.duplicate) }
        if list.count >= maxCount { return .failure(.full(maxCount)) }
        return .success(list + [text])
    }
}
