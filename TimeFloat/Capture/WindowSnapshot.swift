import UIKit

enum WindowSnapshot {
    /// Captures this app's own window only. Other apps and the Home Screen are not included.
    static func save(caption: String, date: Date) -> String? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.flatMap(\.windows).first
        guard let window else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
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
