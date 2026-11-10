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
        card.addGestureRecognizer(pan)
    }

    required init?(coder: NSCoder) { return nil }

    func place(origin: CGPoint, size: CGSize) {
        guard !isDragging else { return }
        card.frame = CGRect(origin: origin, size: size)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        !(touch.view is UIButton)
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
