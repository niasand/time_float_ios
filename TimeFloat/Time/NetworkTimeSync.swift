import Foundation
import Network

struct TimeSample: Equatable {
    var offset: TimeInterval
    var delay: TimeInterval
    var source: String
}

enum NetworkTimeSync {
    private static let ntpHosts = [
        "time.apple.com",
        "time.cloudflare.com",
        "ntp.aliyun.com",
        "cn.pool.ntp.org"
    ]
    private static let httpHosts = [
        "https://www.cloudflare.com",
        "https://www.apple.com",
        "https://www.baidu.com",
        "https://www.aliyun.com"
    ]

    static func sync() async -> Result<TimeSample, Error> {
        if let best = await bestNTP() {
            return .success(best)
        }
        if let http = await firstHTTP() {
            return .success(http)
        }
        return .failure(SyncFailure())
    }

    private static func bestNTP() async -> TimeSample? {
        await withTaskGroup(of: TimeSample?.self) { group in
            for host in ntpHosts {
                group.addTask { try? await ntpQuery(host: host) }
            }
            var best: TimeSample?
            for await sample in group {
                guard let sample, sample.delay >= 0, sample.delay < 2, abs(sample.offset) < 86_400 else { continue }
                if best == nil || sample.delay < best!.delay {
                    best = sample
                }
            }
            return best
        }
    }

    private static func ntpQuery(host: String) async throws -> TimeSample {
        let connection = NWConnection(host: NWEndpoint.Host(host), port: 123, using: .udp)
        return try await withCheckedThrowingContinuation { continuation in
            let box = ResumeOnce(continuation)
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let sent = Date()
                    connection.send(content: NTPPacket.clientRequest(sentAt: sent), completion: .contentProcessed { error in
                        if let error {
                            box.resume(throwing: error)
                            connection.cancel()
                            return
                        }
                        connection.receiveMessage { data, _, _, error in
                            defer { connection.cancel() }
                            if let error {
                                box.resume(throwing: error)
                                return
                            }
                            guard let data else {
                                box.resume(throwing: SyncFailure())
                                return
                            }
                            let received = Date()
                            do {
                                let parsed = try NTPPacket.parse(data)
                                let offset = NTPPacket.clockOffset(
                                    clientSend: sent,
                                    serverReceive: parsed.receive,
                                    serverTransmit: parsed.transmit,
                                    clientReceive: received
                                )
                                let delay = NTPPacket.roundTripDelay(
                                    clientSend: sent,
                                    serverReceive: parsed.receive,
                                    serverTransmit: parsed.transmit,
                                    clientReceive: received
                                )
                                box.resume(returning: TimeSample(offset: offset, delay: delay, source: "NTP \(host)"))
                            } catch {
                                box.resume(throwing: error)
                            }
                        }
                    })
                case .failed(let error):
                    box.resume(throwing: error)
                    connection.cancel()
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .userInitiated))
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 2.5) {
                box.resume(throwing: SyncFailure())
                connection.cancel()
            }
        }
    }

    private static func firstHTTP() async -> TimeSample? {
        for urlString in httpHosts {
            if let sample = try? await httpDate(urlString: urlString) {
                return sample
            }
        }
        return nil
    }

    private static func httpDate(urlString: String) async throws -> TimeSample {
        guard let url = URL(string: urlString) else { throw SyncFailure() }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 4
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let started = Date()
        let (_, response) = try await URLSession.shared.data(for: request)
        let finished = Date()
        guard let http = response as? HTTPURLResponse,
              let header = http.value(forHTTPHeaderField: "Date"),
              let serverDate = parseHTTPDate(header) else {
            throw SyncFailure()
        }
        let midpoint = started.addingTimeInterval(finished.timeIntervalSince(started) / 2)
        let host = url.host ?? urlString
        return TimeSample(
            offset: serverDate.timeIntervalSince(midpoint),
            delay: finished.timeIntervalSince(started),
            source: "HTTP \(host)"
        )
    }

    private static func parseHTTPDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss zzz"
        return formatter.date(from: value)
    }
}

private struct SyncFailure: Error {}

private final class ResumeOnce<T>: @unchecked Sendable {
    private var continuation: CheckedContinuation<T, Error>?
    private let lock = NSLock()

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    func resume(returning value: T) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(returning: value)
    }

    func resume(throwing error: Error) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(throwing: error)
    }
}
