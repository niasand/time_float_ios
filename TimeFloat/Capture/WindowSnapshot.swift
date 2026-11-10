import UIKit

enum WindowSnapshot {
    /// Captures this app's own window only. Other apps and the Home Screen are not included.
    static func save(caption: String, date: Date, afterScreenUpdates: Bool) -> String? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.flatMap(\.windows).first
        guard let window else { return nil }
        window.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: afterScreenUpdates)
        }
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
