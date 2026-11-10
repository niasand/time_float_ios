import ActivityKit
import AVFoundation
import AVKit
import Combine
import MediaPlayer
import UIKit
import WidgetKit

@MainActor
final class FloatingClockSession: NSObject, ObservableObject {
    @Published var settings = ClockSettings()
    @Published var sync = SyncRecord()
    @Published var isEnabled = false
    @Published var isPipActive = false
    @Published var statusText = "悬浮窗已关闭"
    @Published var syncStatus = "尚未对时"
    @Published var isSyncing = false
    @Published var layout = ClockLayout(
        size: CGSize(width: 180, height: 88),
        dateFrame: .zero,
        timeFrame: .zero,
        chips: []
    )
    @Published var origin = CGPoint.zero
    @Published var viewport = CGSize.zero
    @Published var srtLines: [String] = []
    @Published var srtCount = 0
    @Published var banner: String?
    @Published var appGroupReady = true
    /// True while Picture in Picture should be the only clock the user sees.
    @Published var hidesInAppClock = false

    private var storedOrigin = CGPoint(x: -1, y: -1)
    private let audio = SilentAudioEngine()
    private var host: PipHostView?
    private var renderTimer: Timer?
    private var syncTimer: Timer?
    private var bootstrapped = false
    private var ignoreDismiss = false
    private var commandsInstalled = false
    private var lastActivitySecond = -1
    private var lastRenderKey = ""
    private var sceneIsActive = true
    private var restoreAttempts = 0
    private var userStopped = false
    private var darwin: DarwinObserver?

    func bootstrap() {
        guard !bootstrapped else { return }
        bootstrapped = true
        appGroupReady = AppIdentity.usesAppGroup
        settings = ClockPreferences.loadSettings()
        sync = ClockPreferences.loadSync()
        refreshSyncLabel()
        let saved = ClockPreferences.loadPosition()
        storedOrigin = CGPoint(x: saved.x, y: saved.y)
        isEnabled = ClockPreferences.isEnabled()
        recomputeLayout()
        reloadSRT()
        installRemoteCommands()
        darwin = DarwinObserver { [weak self] in
            Task { @MainActor in
                self?.reloadFromExternal()
            }
        }
        syncTimer = Timer(timeInterval: 600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshSync()
            }
        }
        if let syncTimer {
            RunLoop.main.add(syncTimer, forMode: .common)
        }
        Task { await refreshSync() }
        if isEnabled {
            turnOn()
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    func updateViewport(_ size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        viewport = size
        placeOrigin()
    }

    func move(to point: CGPoint) {
        let clamped = clamp(point)
        origin = clamped
        storedOrigin = clamped
    }

    /// Used while a finger is down so the drag does not publish through the settings screen.
    func clampedOrigin(_ point: CGPoint) -> CGPoint {
        clamp(point)
    }

    func finishMove() {
        ClockPreferences.savePosition(x: origin.x, y: origin.y)
    }

    func resetPosition() {
        storedOrigin = CGPoint(x: -1, y: -1)
        ClockPreferences.savePosition(x: -1, y: -1)
        placeOrigin()
    }

    func setEnabled(_ on: Bool) {
        if on { turnOn() } else { turnOff() }
    }

    func sceneBecameActive() {
        sceneIsActive = true
        restoreAttempts = 0
        // Do not stop Picture in Picture here. Closing it on foreground was dismissing the floating clock.
        hidesInAppClock = host?.isPictureInPictureActive == true
        reloadFromExternal()
        DocumentsMirror.sync()
        PhotoLibrarySaver.exportPendingIfNeeded()
        if let at = sync.at, Date().timeIntervalSince(at) < 600 { return }
        Task { await refreshSync() }
    }

    func sceneWentBackground() {
        sceneIsActive = false
        guard isEnabled, !userStopped else { return }
        hidesInAppClock = true
        restoreAttempts = 0
        host?.startPictureInPicture()
    }

    func updateSettings(_ body: (inout ClockSettings) -> Void) {
        let previous = settings
        body(&settings)
        settings.alphaPercent = min(ClockSettings.maxAlpha, max(ClockSettings.minAlpha, settings.alphaPercent))
        settings.fontSize = min(ClockSettings.maxFont, max(ClockSettings.minFont, settings.fontSize))
        settings.captions = CaptionRules.sanitized(settings.captions)
        if !settings.captions.indices.contains(settings.armedIndex) {
            settings.armedIndex = 0
        }
        ClockPreferences.save(settings)
        if previous.mixWithOtherAudio != settings.mixWithOtherAudio {
            audio.mixWithOthers = settings.mixWithOtherAudio
            if isEnabled { audio.restartIfNeeded() }
        }
        if isEnabled {
            if previous.showMilliseconds != settings.showMilliseconds {
                restartRenderTimer()
            }
            renderFrame()
            updateActivity()
        }
        applyIdleTimer()
        refreshSyncLabel()
        recomputeLayout()
        placeOrigin()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func addCaption(_ raw: String) {
        switch CaptionRules.adding(raw, to: settings.captions) {
        case .success(let list):
            updateSettings { $0.captions = list }
        case .failure(let error):
            showBanner(error.message)
        }
    }

    func deleteCaption(_ caption: String) {
        updateSettings { settings in
            settings.captions.removeAll { $0 == caption }
        }
    }

    func arm(_ caption: String) {
        guard let index = settings.captions.firstIndex(of: caption) else { return }
        updateSettings { $0.armedIndex = index }
    }

    func logCaption(_ caption: String) {
        let shot = windowShotIfNeeded(caption: caption)
        if let error = CaptionLogger.log(caption: caption, screenshotFilename: shot) {
            showBanner(error)
            return
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showBanner(shot == nil ? "已记录 \(caption)" : "已记录 \(caption)，并保存截图")
        PhotoLibrarySaver.exportPendingIfNeeded()
        reloadFromExternal()
    }

    private func windowShotIfNeeded(caption: String) -> String? {
        guard settings.screenshotOnCaption, !ScreenFrameStore.latestIsFresh() else { return nil }
        guard sceneIsActive else { return nil }
        let stamped = settings.corrected(Date(), offset: sync.offset)
        return WindowSnapshot.save(caption: caption, date: stamped)
    }

    func refreshSync() async {
        guard !isSyncing else { return }
        isSyncing = true
        syncStatus = "正在对时…"
        let result = await NetworkTimeSync.sync()
        isSyncing = false
        switch result {
        case .success(let sample):
            sync = SyncRecord(offset: sample.offset, delay: sample.delay, source: sample.source, at: Date())
            ClockPreferences.saveSync(sync)
            refreshSyncLabel()
            if isEnabled { updateActivity() }
            WidgetCenter.shared.reloadAllTimelines()
        case .failure:
            syncStatus = sync.hasValue ? "对时失败，沿用上次结果" : "对时失败，当前显示设备时间"
        }
    }

    func clearSRT() {
        try? SrtLog.clear()
        try? TextLog.clear()
        DocumentsMirror.sync()
        reloadSRT()
        showBanner("已清空记录")
    }

    func syncDocuments() {
        DocumentsMirror.sync()
    }

    func attach(host: PipHostView) {
        guard self.host !== host else { return }
        self.host = host
        host.onActiveChange = { [weak self] active in
            Task { @MainActor in
                self?.isPipActive = active
                if active {
                    self?.hidesInAppClock = true
                    self?.restoreAttempts = 0
                }
            }
        }
        host.onDismissed = { [weak self] in
            Task { @MainActor in
                guard let self, !self.ignoreDismiss, self.isEnabled, !self.userStopped else { return }
                self.scheduleRestore()
            }
        }
        audio.onRecovered = { [weak self] in
            Task { @MainActor in self?.scheduleRestore() }
        }
        host.onFailed = { [weak self] message in
            Task { @MainActor in
                self?.statusText = message
            }
        }
        renderFrame()
        host.preparePictureInPicture()
    }

    func renderFrame() {
        let now = Date()
        let highlighted = ClockPreferences.currentHighlight(now: now)
        let corrected = settings.corrected(now, offset: sync.offset)
        let dateText = ClockFaceText.dateLine(corrected)
        let timeText = ClockFaceText.timeLine(corrected, milliseconds: settings.showMilliseconds)
        let second = Int(corrected.timeIntervalSince1970)
        if second != lastActivitySecond {
            lastActivitySecond = second
            updateActivity(now: now)
        }
        // Redraw only when the pixels would change. A 10–30 fps full-buffer upload
        // on the main thread is what made the PiP window stutter while it was dragged.
        let key = "\(dateText)\u{1}\(timeText)\u{1}\(highlighted ?? "")\u{1}\(settings.colorHex)\u{1}\(settings.alphaPercent)\u{1}\(settings.fontSize)\u{1}\(settings.showCaptionsInFloat)\u{1}\(settings.captions.joined(separator: "\u{1}"))"
        if key == lastRenderKey { return }
        lastRenderKey = key
        let pip = ClockDrawing.pipImage(settings: settings, dateText: dateText, timeText: timeText)
        host?.enqueuePip(pip)
        if hidesInAppClock { return }
        let (image, nextLayout) = ClockDrawing.image(
            settings: settings,
            dateText: dateText,
            timeText: timeText,
            highlighted: highlighted,
            scale: 2
        )
        if nextLayout != layout {
            layout = nextLayout
            placeOrigin()
        }
        host?.showCard(image)
    }

    private func turnOn() {
        isEnabled = true
        userStopped = false
        ClockPreferences.setEnabled(true)
        audio.mixWithOthers = settings.mixWithOtherAudio
        do {
            try audio.start()
            statusText = AVPictureInPictureController.isPictureInPictureSupported()
                ? "已打开。本页只留这一块，离开 App 后它会浮到其他 App 上。"
                : "已打开。这台设备不能画中画，时钟只显示在本页。"
        } catch {
            statusText = "保活音频没能启动。留在本页可以看时钟，离开后可能停住。"
        }
        applyIdleTimer()
        updateNowPlaying()
        restartRenderTimer()
        lastRenderKey = ""
        renderFrame()
        startActivity()
    }

    private func turnOff() {
        ignoreDismiss = true
        userStopped = true
        isEnabled = false
        isPipActive = false
        hidesInAppClock = false
        ClockPreferences.setEnabled(false)
        renderTimer?.invalidate()
        renderTimer = nil
        host?.stopPictureInPicture()
        host = nil
        lastRenderKey = ""
        audio.stop()
        applyIdleTimer()
        updateNowPlaying()
        endActivities()
        statusText = "悬浮窗已关闭"
        WidgetCenter.shared.reloadAllTimelines()
        DispatchQueue.main.async { [weak self] in
            self?.ignoreDismiss = false
        }
    }

    private func scheduleRestore() {
        guard isEnabled, !userStopped, !sceneIsActive else { return }
        guard host?.isPictureInPictureActive != true else { return }
        guard restoreAttempts < 3 else { return }
        restoreAttempts += 1
        audio.restartIfNeeded()
        let delay = 0.35 * Double(restoreAttempts)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.isEnabled, !self.userStopped, !self.sceneIsActive else { return }
            guard self.host?.isPictureInPictureActive != true else { return }
            self.host?.startPictureInPicture()
        }
    }

    private func reloadFromExternal() {
        let shouldRun = ClockPreferences.isEnabled()
        settings = ClockPreferences.loadSettings()
        sync = ClockPreferences.loadSync()
        refreshSyncLabel()
        reloadSRT()
        DocumentsMirror.sync()
        PhotoLibrarySaver.exportPendingIfNeeded()
        recomputeLayout()
        WidgetCenter.shared.reloadAllTimelines()
        if isEnabled && !shouldRun {
            turnOff()
        } else if isEnabled {
            renderFrame()
            updateActivity()
        }
    }

    private func reloadSRT() {
        srtLines = SrtLog.tail(maxLines: 30)
        srtCount = SrtLog.lineCount()
    }

    private func restartRenderTimer() {
        renderTimer?.invalidate()
        let timer = Timer(timeInterval: frameInterval, target: self, selector: #selector(renderTick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        renderTimer = timer
    }

    @objc private func renderTick() {
        renderFrame()
    }

    private var frameInterval: TimeInterval { 0.1 }

    private func recomputeLayout() {
        let corrected = settings.corrected(Date(), offset: sync.offset)
        let next = ClockDrawing.layout(
            settings: settings,
            dateText: ClockFaceText.dateLine(corrected),
            timeText: ClockFaceText.timeLine(corrected, milliseconds: settings.showMilliseconds),
            highlighted: ClockPreferences.currentHighlight()
        )
        if next != layout { layout = next }
    }

    private func placeOrigin() {
        guard viewport.width > 1 else { return }
        if storedOrigin.x < 0 || storedOrigin.y < 0 {
            origin = clamp(CGPoint(
                x: (viewport.width - layout.size.width) / 2,
                y: viewport.height * 0.06
            ))
            return
        }
        origin = clamp(storedOrigin)
    }

    private func clamp(_ point: CGPoint) -> CGPoint {
        guard viewport.width > 1 else { return point }
        let maxX = max(0, viewport.width - layout.size.width)
        let maxY = max(0, viewport.height - layout.size.height)
        return CGPoint(
            x: min(max(0, point.x), maxX),
            y: min(max(0, point.y), maxY)
        )
    }

    private func applyIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = isEnabled && settings.keepAwake
    }

    private func startActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = ClockActivityAttributes.currentState()
        let content = ActivityContent(state: state, staleDate: nil)
        if let existing = Activity<ClockActivityAttributes>.activities.first {
            Task { await existing.update(content) }
            return
        }
        let attributes = ClockActivityAttributes(title: "悬浮时钟")
        activityRequest(attributes: attributes, content: content)
    }

    private func activityRequest(attributes: ClockActivityAttributes, content: ActivityContent<ClockActivityAttributes.ContentState>) {
        do {
            _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
        } catch {
            // PiP still works when Live Activities are disabled for this app.
        }
    }

    private func updateActivity(now: Date = Date()) {
        guard isEnabled else { return }
        let content = ActivityContent(state: ClockActivityAttributes.currentState(now: now), staleDate: nil)
        for activity in Activity<ClockActivityAttributes>.activities {
            Task { await activity.update(content) }
        }
    }

    private func endActivities() {
        for activity in Activity<ClockActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private func refreshSyncLabel() {
        guard sync.hasValue else {
            syncStatus = "尚未对时"
            return
        }
        let ms = Int((sync.offset * 1000).rounded())
        let rtt = Int((sync.delay * 1000).rounded())
        let applied = settings.useNetworkTime ? "已用于时钟" : "未应用到时钟"
        let direction: String
        if abs(ms) < 5 {
            direction = "与网络时间基本一致（\(ms) ms）"
        } else if ms > 0 {
            direction = "设备慢 \(ms) ms"
        } else {
            direction = "设备快 \(-ms) ms"
        }
        syncStatus = "\(sync.source) · \(direction) · 往返 \(rtt) ms · \(applied)"
    }

    private func showBanner(_ text: String) {
        banner = text
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if self?.banner == text { self?.banner = nil }
        }
    }

    private func installRemoteCommands() {
        guard !commandsInstalled else { return }
        commandsInstalled = true
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = false
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false
        center.stopCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.stopCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.setEnabled(false) }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.setEnabled(false) }
            return .success
        }
    }

    private func updateNowPlaying() {
        if isEnabled {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = [
                MPMediaItemPropertyTitle: "悬浮时钟",
                MPMediaItemPropertyArtist: "TimeFloat",
                MPNowPlayingInfoPropertyIsLiveStream: true,
                MPNowPlayingInfoPropertyPlaybackRate: 1.0
            ]
        } else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        }
    }
}

enum DocumentsMirror {
    static var documentsSRT: URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(AppIdentity.srtDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(AppIdentity.srtFileName)
    }

    static func sync() {
        let sourceRoot = AppIdentity.storageDirectory.standardizedFileURL
        let documentsRoot = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(AppIdentity.srtDirectoryName, isDirectory: true)
            .standardizedFileURL
        if sourceRoot == documentsRoot { return }
        try? FileManager.default.createDirectory(at: documentsRoot, withIntermediateDirectories: true)
        copyFile(named: AppIdentity.srtFileName, from: sourceRoot, to: documentsRoot)
        copyFile(named: AppIdentity.textLogFileName, from: sourceRoot, to: documentsRoot)
        let shots = sourceRoot.appendingPathComponent(AppIdentity.screenshotsDirectoryName, isDirectory: true)
        let shotDest = documentsRoot.appendingPathComponent(AppIdentity.screenshotsDirectoryName, isDirectory: true)
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: shots.path) else { return }
        try? FileManager.default.createDirectory(at: shotDest, withIntermediateDirectories: true)
        for name in names where name.hasSuffix(".jpg") {
            copyFile(named: name, from: shots, to: shotDest)
        }
    }

    private static func copyFile(named name: String, from sourceDir: URL, to destDir: URL) {
        let source = sourceDir.appendingPathComponent(name)
        let destination = destDir.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: source.path) else { return }
        try? FileManager.default.removeItem(at: destination)
        try? FileManager.default.copyItem(at: source, to: destination)
    }
}

final class DarwinObserver {
    private let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                let object = Unmanaged<DarwinObserver>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async {
                    object.handler()
                }
            },
            AppIdentity.darwinEventName as CFString,
            nil,
            .deliverImmediately
        )
    }

    deinit {
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            CFNotificationName(AppIdentity.darwinEventName as CFString),
            nil
        )
    }
}
