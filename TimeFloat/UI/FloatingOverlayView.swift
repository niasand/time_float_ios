import UIKit

/// Positions the clock with a UIKit pan so dragging does not rebuild the SwiftUI settings tree.
final class FloatingOverlayView: UIView, UIGestureRecognizerDelegate {
    let card = PipHostView()
    var onMoveEnd: ((CGPoint) -> Void)?
    var clamp: (CGPoint) -> CGPoint = { $0 }
    private(set) var isDragging = false
    private var panOrigin = CGPoint.zero
    private let pan = UIPanGestureRecognizer()

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

    /// Only the clock card is interactive. Everything else falls through to the settings screen.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        card.frame.contains(point)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard card.frame.contains(point) else { return nil }
        let local = convert(point, to: card)
        return card.hitTest(local, with: event) ?? card
    }

    required init?(coder: NSCoder) { return nil }

    private var desiredFrame = CGRect(x: 0, y: 40, width: 180, height: 88)

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !isDragging else { return }
        if card.frame.size == .zero || card.frame != desiredFrame {
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
