import AVFoundation
import Foundation

/// Picture in Picture stays alive only while the app is still executing. A near-silent loop,
/// plus the Audio background mode, is what keeps the clock process running after it leaves the screen.
/// The tone is far below conversation level. Mixing is on by default so music is not interrupted.
final class SilentAudioEngine {
    private var player: AVAudioPlayer?
    private var interruptionObserver: NSObjectProtocol?
    private(set) var isRunning = false
    var mixWithOthers = true
    var onInterrupted: (() -> Void)?
    var onRecovered: (() -> Void)?
    private var routeObserver: NSObjectProtocol?
    private var resetObserver: NSObjectProtocol?

    func start() throws {
        try configureSession()
        if player == nil {
            let url = try Self.toneURL()
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0.01
            player.prepareToPlay()
            self.player = player
        }
        guard player?.play() == true else {
            throw CocoaError(.fileReadCorruptFile)
        }
        isRunning = true
        observeInterruptions()
    }

    func stop() {
        isRunning = false
        player?.stop()
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
            self.interruptionObserver = nil
        }
        if let routeObserver {
            NotificationCenter.default.removeObserver(routeObserver)
            self.routeObserver = nil
        }
        if let resetObserver {
            NotificationCenter.default.removeObserver(resetObserver)
            self.resetObserver = nil
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    func restartIfNeeded() {
        guard isRunning else { return }
        if player == nil {
            try? start()
            return
        }
        try? configureSession()
        if player?.isPlaying != true {
            player?.play()
        }
    }

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        var options: AVAudioSession.CategoryOptions = []
        if mixWithOthers { options.insert(.mixWithOthers) }
        try session.setCategory(.playback, mode: .moviePlayback, options: options)
        try session.setActive(true)
    }

    private func observeInterruptions() {
        guard interruptionObserver == nil else { return }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let type = raw.flatMap { AVAudioSession.InterruptionType(rawValue: $0) }
            if type == .began {
                self.onInterrupted?()
            } else if type == .ended {
                self.restartIfNeeded()
                self.onRecovered?()
            }
        }
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] _ in
            self?.restartIfNeeded()
            self?.onRecovered?()
        }
        resetObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] _ in
            self?.player = nil
            self?.restartIfNeeded()
            self?.onRecovered?()
        }
    }

    /// 220 Hz at a very low integer amplitude, looped. Pure digital silence gets suspended by iOS.
    private static func toneURL() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("timefloat-keepalive.wav")
        if FileManager.default.fileExists(atPath: url.path) { return url }
        let sampleRate = 44_100
        let frames = sampleRate
        var samples = [Int16](repeating: 0, count: frames)
        let amplitude: Double = 40
        for index in 0..<frames {
            let theta = 2 * Double.pi * 220 * Double(index) / Double(sampleRate)
            samples[index] = Int16(sin(theta) * amplitude)
        }
        var data = Data()
        data.appendWAV("RIFF")
        let chunkSize = UInt32(36 + frames * 2)
        data.append(littleEndian: chunkSize)
        data.appendWAV("WAVE")
        data.appendWAV("fmt ")
        data.append(littleEndian: UInt32(16))
        data.append(littleEndian: UInt16(1)) // PCM
        data.append(littleEndian: UInt16(1)) // mono
        data.append(littleEndian: UInt32(sampleRate))
        data.append(littleEndian: UInt32(sampleRate * 2))
        data.append(littleEndian: UInt16(2))
        data.append(littleEndian: UInt16(16))
        data.appendWAV("data")
        data.append(littleEndian: UInt32(frames * 2))
        for sample in samples {
            data.append(littleEndian: sample)
        }
        try data.write(to: url, options: .atomic)
        return url
    }
}

private extension Data {
    mutating func appendWAV(_ ascii: String) {
        append(contentsOf: Array(ascii.utf8))
    }

    mutating func append(littleEndian value: UInt32) {
        var le = value.littleEndian
        append(contentsOf: Swift.withUnsafeBytes(of: &le) { Data($0) })
    }

    mutating func append(littleEndian value: UInt16) {
        var le = value.littleEndian
        append(contentsOf: Swift.withUnsafeBytes(of: &le) { Data($0) })
    }

    mutating func append(littleEndian value: Int16) {
        var le = value.littleEndian
        append(contentsOf: Swift.withUnsafeBytes(of: &le) { Data($0) })
    }
}
