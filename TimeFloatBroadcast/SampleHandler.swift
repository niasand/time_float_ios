import CoreImage
import CoreMedia
import Foundation
import ReplayKit

/// System screen broadcast. The user has to start it from the picker or Control Center.
/// Each recent video frame is written over one JPEG in the App Group so a caption tap can copy it.
class SampleHandler: RPBroadcastSampleHandler {
    private let context = CIContext()
    private var lastWrite = Date.distantPast

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        lastWrite = .distantPast
    }

    override func broadcastFinished() {
        try? FileManager.default.removeItem(at: FramePath.latest)
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }
        let now = Date()
        guard now.timeIntervalSince(lastWrite) >= 0.4 else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastWrite = now
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        try? FileManager.default.createDirectory(
            at: FramePath.latest.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = context.jpegRepresentation(of: image, colorSpace: CGColorSpaceCreateDeviceRGB(), options: [:])
        try? data?.write(to: FramePath.latest, options: .atomic)
    }
}

private enum FramePath {
    static var latest: URL {
        let group = Bundle.main.object(forInfoDictionaryKey: "TimeFloatAppGroup") as? String
        let identifier = (group?.isEmpty == false && group?.contains("$") == false) ? group! : "group.com.yourname.timefloat"
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("TimeFloat/latest_screen.jpg")
    }
}
