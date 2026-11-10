import Photos

enum PhotoLibrarySaver {
    private static var exported: String?
    private static var inFlight: Set<String> = []

    static func exportPendingIfNeeded() {
        guard ClockPreferences.loadSettings().saveScreenshotsToPhotos else { return }
        guard let name = AppIdentity.sharedDefaults.string(forKey: "last_screenshot_name"),
              name != exported, !inFlight.contains(name) else { return }
        let url = AppIdentity.screenshotsDirectory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        inFlight.insert(name)
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                inFlight.remove(name)
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
            } completionHandler: { success, _ in
                inFlight.remove(name)
                if success { exported = name }
            }
        }
    }
}
