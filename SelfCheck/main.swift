import Foundation

var failures: [String] = []

func check(_ condition: Bool, _ message: String) {
    if !condition { failures.append(message) }
}

let defaults = CaptionRules.defaults
check(defaults.count == 12, "default caption count")
check(defaults.allSatisfy { $0.count <= CaptionRules.maxLength }, "default caption length")
check(defaults.first == "进入地下停车场前", "first default caption")
check(defaults.last == "离开地面停车场后", "last default caption")

func failed(_ result: Result<[String], CaptionRules.AddError>, _ error: CaptionRules.AddError) -> Bool {
    if case .failure(let got) = result { return got == error }
    return false
}

check(failed(CaptionRules.adding("  ", to: []), .empty), "blank caption")
check(failed(CaptionRules.adding(String(repeating: "字", count: 13), to: []), .tooLong(12)), "caption over 12")
check(failed(CaptionRules.adding("停车前", to: ["停车前"]), .duplicate), "duplicate caption")
check(failed(CaptionRules.adding("新", to: (0..<16).map { "甲\($0)" }), .full(16)), "caption list full")
if case .success(let list) = CaptionRules.adding(" 停车前 ", to: []) {
    check(list == ["停车前"], "trim caption")
} else {
    check(false, "add caption")
}
check(CaptionRules.sanitized([" a ", "a", "", "b"]) == ["a", "b"], "sanitize")

let red = RGB.hsv(h: 0, s: 1, v: 1)
check(red.hex == 0xFF0000, "hsv red \(String(red.hex, radix: 16))")
let green = RGB.hsv(h: 120, s: 1, v: 1)
check(green.hex == 0x00FF00, "hsv green")
let blue = RGB.hsv(h: 240, s: 1, v: 1)
check(blue.hex == 0x0000FF, "hsv blue")
let white = RGB.hsv(h: 40, s: 0, v: 1)
check(white.hex == 0xFFFFFF, "hsv white")
let gray = RGB.from(hex: 0x2E2E2E)
check(gray.prefersDarkText == false, "default gray uses white text")
check(RGB.from(hex: 0xFFFFFF).prefersDarkText, "white uses dark text")
let back = RGB.from(hex: red.hex).hsvComponents()
check(abs(back.h - 0) < 1 || abs(back.h - 360) < 1, "red hue roundtrip")
check(abs(back.s - 1) < 0.01, "red sat roundtrip")
let dim = red.blendedOverBlack(alpha: 0.5)
check(abs(dim.r - 0.5) < 0.01 && dim.g == 0 && dim.b == 0, "blend over black")

let instant = Date(timeIntervalSince1970: 1_700_000_000.5)
var packet = Data(count: 48)
NTPPacket.write(instant, into: &packet, at: 0)
let decoded = NTPPacket.read(packet, at: 0)
check(abs(decoded.timeIntervalSince(instant)) < 0.000_001, "ntp timestamp roundtrip")

let request = NTPPacket.clientRequest(sentAt: instant)
check(request.count == 48 && request[0] == 0x1B, "ntp client packet")
var server = Data(count: 48)
server[0] = 0x1C
NTPPacket.write(instant, into: &server, at: 24)
NTPPacket.write(instant.addingTimeInterval(0.2), into: &server, at: 32)
NTPPacket.write(instant.addingTimeInterval(0.3), into: &server, at: 40)
let parsed = try! NTPPacket.parse(server)
check(abs(parsed.transmit.timeIntervalSince(instant.addingTimeInterval(0.3))) < 0.000_001, "parse transmit")

let t1 = Date(timeIntervalSince1970: 1_000)
let t2 = Date(timeIntervalSince1970: 1_002)
let t3 = Date(timeIntervalSince1970: 1_002.1)
let t4 = Date(timeIntervalSince1970: 1_002.4)
let offset = NTPPacket.clockOffset(clientSend: t1, serverReceive: t2, serverTransmit: t3, clientReceive: t4)
let delay = NTPPacket.roundTripDelay(clientSend: t1, serverReceive: t2, serverTransmit: t3, clientReceive: t4)
check(abs(offset - 0.85) < 0.000_001, "offset \(offset)")
check(abs(delay - 2.3) < 0.000_001, "delay \(delay)")

let line = ClockFaceText.srtLine(date: instant, caption: "停车前", milliseconds: false)
check(line.hasSuffix("：停车前\n"), "srt suffix")
check(line.range(of: #"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}：停车前\n$"#, options: .regularExpression) != nil, "srt shape \(line)")
let msLine = ClockFaceText.srtLine(date: instant, caption: "停车前", milliseconds: true)
check(msLine.range(of: #"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}：停车前\n$"#, options: .regularExpression) != nil, "srt ms \(msLine)")
let clock = ClockFaceText.timeLine(instant, milliseconds: false)
check(clock.range(of: #"^\d{2}:\d{2}:\d{2}$"#, options: .regularExpression) != nil, "time line")
check(ClockFaceText.offsetLine(useNetworkTime: true, offset: 0.023) == "设备慢 23 ms", "offset text")
check(ClockFaceText.offsetLine(useNetworkTime: true, offset: -0.12) == "设备快 120 ms", "offset text fast")
check(ClockFaceText.offsetLine(useNetworkTime: false, offset: 1) == "设备时间", "offset off")

if failures.isEmpty {
    print("selfcheck ok")
} else {
    for failure in failures { print("FAIL \(failure)") }
    exit(1)
}
