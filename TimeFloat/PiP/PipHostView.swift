import AVFoundation
import AVKit
import CoreMedia
import os
import UIKit

enum PipLog {
    private static let log = OSLog(subsystem: "TimeFloat", category: "PiP")

    static func info(_ message: String) {
        os_log("%{public}@", log: log, type: .info, message)
    }
}

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
    /// Set when we close PiP ourselves because the in-app card is taking over.
    private var suppressDismiss = false
    private var startRequested = false
    private var timebase: CMTimebase?
    private let videoLayerView = UIView()
    private var chipButtons: [UIButton] = []
    private var appliedChips: [ChipFrame] = []
    var onCaptionTap: ((String) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = true
        installTimebase()
        imageView.contentMode = .scaleToFill
        imageView.layer.cornerRadius = 14
        imageView.layer.masksToBounds = true
        imageView.isOpaque = false
        imageView.backgroundColor = .clear
        imageView.isUserInteractionEnabled = false
        addSubview(imageView)

        videoLayerView.isUserInteractionEnabled = false
        videoLayerView.backgroundColor = .clear
        // The sample-buffer layer is the PiP source. It must stay in the window at alpha 1.
        // Fading this view, or the layer's opacity, stops Picture in Picture from starting.
        // The image view on top is the in-app clock; its bitmap carries the opacity slider.
        videoLayerView.alpha = 1
        videoLayerView.isHidden = false
        addSubview(videoLayerView)
        sendSubviewToBack(videoLayerView)
        displayLayer.videoGravity = .resizeAspect
        displayLayer.opacity = 1
        displayLayer.isHidden = false
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

    var isPictureInPictureActive: Bool {
        controller?.isPictureInPictureActive == true
    }

    func showCard(_ image: UIImage) {
        imageView.image = image
    }

    func enqueuePip(_ image: UIImage) {
        // Opacity lives in the bitmap pixels only. Never multiply the source layer.
        displayLayer.opacity = 1
        let when = timebase.map { CMTimebaseGetTime($0) } ?? CMClockGetTime(CMClockGetHostTimeClock())
        guard let buffer = SampleBufferFactory.make(from: image, presentationTime: when) else {
            PipLog.info("PiP enqueue failed: no sample buffer")
            return
        }
        if displayLayer.status == .failed {
            displayLayer.flush()
            PipLog.info("PiP display layer was failed; flushed before enqueue")
        }
        displayLayer.enqueue(buffer)
    }

    /// Hide the in-app drawing without touching the PiP source layer.
    func setInlineChromeHidden(_ hidden: Bool) {
        imageView.isHidden = hidden
        chipButtons.forEach { $0.isHidden = hidden }
        keepSourceVisible()
    }

    /// Call immediately before starting Picture in Picture.
    func prepareVisibleSource() {
        keepSourceVisible()
        if bounds.width < 2 || bounds.height < 2 {
            let fallback = CGSize(width: max(bounds.width, 180), height: max(bounds.height, 88))
            bounds.size = fallback
            frame.size = fallback
        }
        layoutIfNeeded()
        PipLog.info("PiP source frame=\(Int(bounds.width))x\(Int(bounds.height)) layer=\(Int(displayLayer.bounds.width))x\(Int(displayLayer.bounds.height)) opacity=\(displayLayer.opacity) alpha=\(videoLayerView.alpha) hidden=\(isHidden) inWindow=\(window != nil)")
    }

    private func keepSourceVisible() {
        isHidden = false
        alpha = 1
        videoLayerView.isHidden = false
        videoLayerView.alpha = 1
        displayLayer.isHidden = false
        displayLayer.opacity = 1
    }

    func setChips(_ chips: [ChipFrame]) {
        guard chips != appliedChips else { return }
        appliedChips = chips
        chipButtons.forEach { $0.removeFromSuperview() }
        chipButtons = chips.map { chip in
            let button = UIButton(type: .custom)
            button.frame = chip.rect
            button.accessibilityLabel = chip.caption
            button.addAction(UIAction { [weak self] _ in
                self?.onCaptionTap?(chip.caption)
            }, for: .touchUpInside)
            addSubview(button)
            return button
        }
    }

    /// Create the controller while the app is still on screen.
    /// Automatic inline start is the reliable path when the user leaves; the in-app card is hidden then.
    func preparePictureInPicture() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            PipLog.info("PiP prepare skipped: not supported")
            return
        }
        let controller = ensureController()
        controller.requiresLinearPlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        PipLog.info("PiP prepare autoStart=true")
    }

    private func installTimebase() {
        var created: CMTimebase?
        let clock = CMClockGetHostTimeClock()
        CMTimebaseCreateWithSourceClock(allocator: kCFAllocatorDefault, sourceClock: clock, timebaseOut: &created)
        guard let created else { return }
        CMTimebaseSetTime(created, time: CMClockGetTime(clock))
        CMTimebaseSetRate(created, rate: 1)
        displayLayer.controlTimebase = created
        timebase = created
    }

    func startPictureInPicture() {
        if controller?.isPictureInPictureActive == true {
            PipLog.info("PiP start skipped: already active")
            return
        }
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            PipLog.info("PiP start skipped: not supported")
            onFailed?("这台设备不支持画中画。模拟器通常不支持，请用真机。")
            return
        }
        prepareVisibleSource()
        let controller = ensureController()
        controller.requiresLinearPlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        let possible = controller.isPictureInPicturePossible
        if startRequested {
            PipLog.info("PiP start skipped: already pending possible=\(possible)")
            return
        }
        PipLog.info("PiP start requested possible=\(possible)")
        startRequested = true
        if possible {
            DispatchQueue.main.async { [weak self, weak controller] in
                guard let self, self.startRequested else {
                    PipLog.info("PiP start cancelled before the call")
                    return
                }
                self.prepareVisibleSource()
                PipLog.info("PiP calling startPictureInPicture")
                controller?.startPictureInPicture()
            }
        } else {
            PipLog.info("PiP waiting until isPictureInPicturePossible")
            possibleObservation = controller.observe(\.isPictureInPicturePossible, options: [.new]) { [weak self] controller, change in
                guard change.newValue == true else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.startRequested else {
                        PipLog.info("PiP possible, but start was cancelled")
                        return
                    }
                    self.possibleObservation = nil
                    self.prepareVisibleSource()
                    PipLog.info("PiP calling startPictureInPicture after it became possible")
                    controller.startPictureInPicture()
                }
            }
        }
    }

    func stopPictureInPicture() {
        possibleObservation = nil
        startRequested = false
        if controller?.isPictureInPictureActive == true {
            controller?.stopPictureInPicture()
        }
    }

    /// Close the system window, or cancel a start that has not appeared yet,
    /// without treating it as the user turning the clock off.
    func stopPictureInPictureKeepingSession() {
        if controller?.isPictureInPictureActive == true {
            suppressDismiss = true
            stopPictureInPicture()
        } else {
            possibleObservation = nil
            startRequested = false
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
        startRequested = false
        PipLog.info("PiP did start")
        onActiveChange?(true)
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        startRequested = false
        PipLog.info("PiP did stop suppress=\(suppressDismiss) restoring=\(userIsRestoring)")
        onActiveChange?(false)
        if userIsRestoring || suppressDismiss {
            userIsRestoring = false
            suppressDismiss = false
        } else {
            onDismissed?()
        }
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        startRequested = false
        PipLog.info("PiP failedToStart: \(error.localizedDescription)")
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
