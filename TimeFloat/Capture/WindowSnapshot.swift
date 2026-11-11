import UIKit

enum WindowSnapshot {
    /// Captures what is on this app's screen: every visible window of the foreground scene,
    /// back to front. Other apps and the Home Screen are not included.
    static func save(caption: String, date: Date, afterScreenUpdates: Bool) -> String? {
        guard let scene = foregroundScene() else { return nil }
        let windows = scene.windows
            .filter { !$0.isHidden && $0.alpha > 0.01 && $0.bounds.width > 1 && $0.bounds.height > 1 }
            .sorted { $0.windowLevel.rawValue < $1.windowLevel.rawValue }
        guard !windows.isEmpty else { return nil }
        let canvas = scene.screen.bounds
        let scale = scene.screen.scale
        let screenSpace = scene.screen.coordinateSpace
        for window in windows {
            window.layoutIfNeeded()
            window.rootViewController?.view.layoutIfNeeded()
        }

        // Each window is snapped on its own so a clear overlay cannot paint the default
        // white bitmap over the app. The pieces are then stacked at screen scale.
        let shots: [(UIImage, CGRect)] = windows.map { window in
            let shot = image(of: window, scale: scale, afterScreenUpdates: afterScreenUpdates)
            let rect = window.convert(window.bounds, to: screenSpace)
            return (shot, rect)
        }
        guard !shots.isEmpty else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        let image = UIGraphicsImageRenderer(bounds: canvas, format: format).image { _ in
            for (shot, rect) in shots {
                shot.draw(in: rect)
            }
        }
        return write(image, caption: caption, date: date)
    }

    private static func foregroundScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }

    /// `drawHierarchy(in: window.bounds, afterScreenUpdates:)` keeps SwiftUI in the bitmap.
    /// A non-opaque format preserves transparency so compositing does not turn missed pixels white.
    private static func image(of window: UIWindow, scale: CGFloat, afterScreenUpdates: Bool) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let bounds = window.bounds
        return UIGraphicsImageRenderer(bounds: bounds, format: format).image { context in
            let drew = window.drawHierarchy(in: bounds, afterScreenUpdates: afterScreenUpdates)
            if drew { return }
            let root = window.rootViewController?.view
            let rootDrew = root?.drawHierarchy(in: bounds, afterScreenUpdates: false) ?? false
            if !rootDrew {
                window.layer.render(in: context.cgContext)
            }
        }
    }

    /// Draws the highlighted clock onto the latest full-screen frame (bottom-right), or returns the clock alone.
    static func compositeHighlightedClock(_ clock: UIImage, caption: String, date: Date) -> String? {
        let background = AppIdentity.latestScreenURL
        let base = UIImage(contentsOfFile: background.path)
        let canvasSize = base?.size ?? clock.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = base?.scale ?? 2
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: canvasSize, format: format).image { _ in
            if let base {
                base.draw(in: CGRect(origin: .zero, size: canvasSize))
            }
            let maxWidth = canvasSize.width * 0.46
            let scale = min(1, maxWidth / max(clock.size.width, 1))
            let size = CGSize(width: clock.size.width * scale, height: clock.size.height * scale)
            let origin = CGPoint(
                x: canvasSize.width - size.width - 12,
                y: canvasSize.height - size.height - 12
            )
            clock.draw(in: CGRect(origin: origin, size: size))
        }
        return write(image, caption: caption, date: date)
    }

    private static func write(_ image: UIImage, caption: String, date: Date) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return nil }
        let name = ScreenFrameStore.filename(caption: caption, date: date)
        let url = AppIdentity.screenshotsDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return name
        } catch {
            return nil
        }
    }
}
