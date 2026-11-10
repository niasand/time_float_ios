import AVFoundation
import AVKit
import CoreMedia
import UIKit

/// Inline source for Picture in Picture.
/// iOS has no Android-style overlay window. AVSampleBufferDisplayLayer is the supported way
/// to put arbitrary frames in the system PiP window (the same approach used by floating clocks).
/// The layer has to sit in the view hierarchy; the clock image the user sees is drawn on top.
final class PipHostView: UIView, AVPictureInPictureControllerDelegate, AVPictureInPictureSampleBufferPlaybackDelegate {
    let imageView = UIImageView()
    let displayLayer = AVSampleBufferDisplayLayer()

    var onActiveChange: ((Bool) -> Void)?
    var onDismissed: (() -> Void)?
    var onFailed: ((String) -> Void)?

    private var controller: AVPictureInPictureController?
    private var possibleObservation: NSKeyValueObservation?
    private var userIsRestoring = false
    private let videoLayerView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        imageView.contentMode = .scaleToFill
        imageView.layer.cornerRadius = 14
        imageView.layer.masksToBounds = true
        imageView.isUserInteractionEnabled = false
        addSubview(imageView)

        videoLayerView.isUserInteractionEnabled = false
        videoLayerView.backgroundColor = .clear
        // Alpha 0 still leaves the layer in the window, which is what PiP requires.
        // The image view on top is what the user actually sees inside the app.
        videoLayerView.alpha = 0
        addSubview(videoLayerView)
        sendSubviewToBack(videoLayerView)
        displayLayer.videoGravity = .resizeAspect
        displayLayer.backgroundColor = UIColor.clear.cgColor
        videoLayerView.layer.addSublayer(displayLayer)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
        videoLayerView.frame = bounds
        displayLayer.frame = videoLayerView.bounds
    }

    func show(_ image: UIImage) {
        imageView.image = image
        guard let buffer = SampleBufferFactory.make(from: image) else { return }
        if displayLayer.status == .failed {
            displayLayer.flush()
        }
        displayLayer.enqueue(buffer)
    }

    func startPictureInPicture() {
        if controller?.isPictureInPictureActive == true { return }
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            onFailed?("这台设备不支持画中画。模拟器通常不支持，请用真机。")
            return
        }
        let controller = ensureController()
        controller.requiresLinearPlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        if controller.isPictureInPicturePossible {
            DispatchQueue.main.async { [weak controller] in
                controller?.startPictureInPicture()
            }
        } else {
            possibleObservation = controller.observe(\.isPictureInPicturePossible, options: [.new]) { [weak self] controller, change in
                guard change.newValue == true else { return }
                self?.possibleObservation = nil
                DispatchQueue.main.async {
                    controller.startPictureInPicture()
                }
            }
        }
    }

    func stopPictureInPicture() {
        possibleObservation = nil
        if controller?.isPictureInPictureActive == true {
            controller?.stopPictureInPicture()
        }
    }

    private func ensureController() -> AVPictureInPictureController {
        if let controller { return controller }
        let created = AVPictureInPictureController(contentSource: .init(
            sampleBufferDisplayLayer: displayLayer,
            playbackDelegate: self
        ))
        created.delegate = self
        controller = created
        return created
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        onActiveChange?(true)
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        onActiveChange?(false)
        if userIsRestoring {
            userIsRestoring = false
        } else {
            onDismissed?()
        }
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        onFailed?(error.localizedDescription)
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        userIsRestoring = true
        completionHandler(true)
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        // The clock is not a pauseable video. Keep reporting playback so the system does not freeze the window.
    }

    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        // A long range keeps AVKit from treating the stream as finished.
        CMTimeRange(start: .zero, duration: CMTime(value: 60 * 60 * 24, timescale: 1))
    }

    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        false
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        didTransitionToRenderSize newRenderSize: CMVideoDimensions
    ) {}

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        skipByInterval skipInterval: CMTime,
        completion completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
