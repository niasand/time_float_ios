import UIKit

/// Full-screen clear view. Only the clock card takes touches, and the settings switch is
/// punched out even when the card sits on that row.
final class FloatingOverlayView: UIView, UIGestureRecognizerDelegate {
    let card = PipHostView()
    var onMoveEnd: ((CGPoint) -> Void)?
    var clamp: (CGPoint) -> CGPoint = { $0 }
    /// Window coordinates of the "显示悬浮窗" switch row. Touches here always fall through.
    var passThroughInWindow: CGRect = .zero
    private(set) var isDragging = false
    private var panOrigin = CGPoint.zero
    private let pan = UIPanGestureRecognizer()
    private var desiredFrame = CGRect(x: 16, y: 160, width: 180, height: 88)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        addSubview(card)
        card.layer.cornerRadius = 14
        card.layer.masksToBounds = false
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.28
        card.layer.shadowRadius = 12
        card.layer.shadowOffset = CGSize(width: 0, height: 5)
        pan.addTarget(self, action: #selector(handlePan(_:)))
        pan.delegate = self
        pan.cancelsTouchesInView = false
        card.addGestureRecognizer(pan)
    }

    required init?(coder: NSCoder) { return nil }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard card.frame.contains(point), !isPassThrough(point) else { return false }
        return true
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard point(inside: point, with: event) else { return nil }
        let local = convert(point, to: card)
        return card.hitTest(local, with: event) ?? card
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !isDragging else { return }
        if card.frame != desiredFrame {
            card.frame = desiredFrame
        }
    }

    func place(origin: CGPoint, size: CGSize) {
        let safe = CGSize(width: max(size.width, 1), height: max(size.height, 1))
        desiredFrame = CGRect(origin: origin, size: safe)
        guard !isDragging else { return }
        card.frame = desiredFrame
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let point = touch.location(in: self)
        guard card.frame.contains(point), !isPassThrough(point) else { return false }
        var view = touch.view
        while let current = view {
            if current is UIButton { return false }
            if current === card { return true }
            view = current.superview
        }
        return false
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        false
    }

    private func isPassThrough(_ point: CGPoint) -> Bool {
        guard passThroughInWindow.width > 1, passThroughInWindow.height > 1, window != nil else { return false }
        let inWindow = convert(point, to: window)
        return passThroughInWindow.contains(inWindow)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        switch gesture.state {
        case .began:
            isDragging = true
            panOrigin = card.frame.origin
        case .changed:
            card.frame.origin = clamp(CGPoint(x: panOrigin.x + translation.x, y: panOrigin.y + translation.y))
        case .ended, .cancelled, .failed:
            isDragging = false
            onMoveEnd?(card.frame.origin)
        default:
            break
        }
    }
}

/// Reports the settings switch row in UIKit window coordinates, and never takes the tap itself.
final class WindowFrameProbeView: UIView {
    var onFrame: ((CGRect) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) { return nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        report()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        report()
    }

    func report() {
        guard window != nil, bounds.width > 1, bounds.height > 1 else { return }
        onFrame?(convert(bounds, to: window))
    }
}

struct WindowFrameProbe: UIViewRepresentable {
    var onFrame: (CGRect) -> Void

    func makeUIView(context: Context) -> WindowFrameProbeView {
        let view = WindowFrameProbeView()
        view.onFrame = onFrame
        return view
    }

    func updateUIView(_ uiView: WindowFrameProbeView, context: Context) {
        uiView.onFrame = onFrame
        uiView.report()
    }
}
