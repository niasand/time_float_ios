import Foundation

/// Minimal SNTP codec (RFC 5905). 48-byte client packets, timestamps in seconds since 1900.
enum NTPPacket {
    static let epochOffset: TimeInterval = 2_208_988_800
    static let packetSize = 48

    struct Timestamps: Equatable {
        var originate: Date
        var receive: Date
        var transmit: Date
    }

    enum ParseError: Error, Equatable {
        case shortPacket
        case unsynchronized
    }

    static func clientRequest(sentAt: Date) -> Data {
        var data = Data(count: packetSize)
        data[0] = 0x1B // LI = 0, VN = 3, Mode = client
        write(sentAt, into: &data, at: 40)
        return data
    }

    static func parse(_ data: Data) throws -> Timestamps {
        guard data.count >= packetSize else { throw ParseError.shortPacket }
        // Leap indicator 3 means the server clock is unsynchronized.
        if data[0] >> 6 == 3 { throw ParseError.unsynchronized }
        return Timestamps(
            originate: read(data, at: 24),
            receive: read(data, at: 32),
            transmit: read(data, at: 40)
        )
    }

    /// ((T2 - T1) + (T3 - T4)) / 2. Positive means the device clock is behind the server.
    static func clockOffset(clientSend: Date, serverReceive: Date, serverTransmit: Date, clientReceive: Date) -> TimeInterval {
        let toServer = serverReceive.timeIntervalSince(clientSend)
        let fromServer = serverTransmit.timeIntervalSince(clientReceive)
        return (toServer + fromServer) / 2
    }

    static func roundTripDelay(clientSend: Date, serverReceive: Date, serverTransmit: Date, clientReceive: Date) -> TimeInterval {
        clientReceive.timeIntervalSince(clientSend) - serverTransmit.timeIntervalSince(serverReceive)
    }

    static func write(_ date: Date, into data: inout Data, at offset: Int) {
        let ntp = date.timeIntervalSince1970 + epochOffset
        let seconds = UInt32(max(0, floor(ntp)))
        let fraction = UInt32(min(4_294_967_295, (ntp - floor(ntp)) * 4_294_967_296))
        put(seconds, into: &data, at: offset)
        put(fraction, into: &data, at: offset + 4)
    }

    static func read(_ data: Data, at offset: Int) -> Date {
        let seconds = Double(get(data, at: offset))
        let fraction = Double(get(data, at: offset + 4)) / 4_294_967_296
        return Date(timeIntervalSince1970: seconds + fraction - epochOffset)
    }

    private static func put(_ value: UInt32, into data: inout Data, at index: Int) {
        data[index] = UInt8((value >> 24) & 0xFF)
        data[index + 1] = UInt8((value >> 16) & 0xFF)
        data[index + 2] = UInt8((value >> 8) & 0xFF)
        data[index + 3] = UInt8(value & 0xFF)
    }

    private static func get(_ data: Data, at index: Int) -> UInt32 {
        (UInt32(data[index]) << 24)
            | (UInt32(data[index + 1]) << 16)
            | (UInt32(data[index + 2]) << 8)
            | UInt32(data[index + 3])
    }
}
