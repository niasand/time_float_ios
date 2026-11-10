import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: FloatingClockSession
    @State private var draftCaption = ""
    @State private var confirmClear = false

    private var srtFileURL: URL { AppIdentity.srtURL }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    readout
                    if !session.appGroupReady {
                        notice(
                            "没有读到 App Group。主 App 里的时钟和记录仍然可用；小组件、锁屏按钮要和主 App 共用字幕，需要在两个 Target 上都签上 App Group。",
                            tint: .orange
                        )
                    }
                    floatingSection
                    appearanceSection
                    timeSection
                    captionSection
                    srtSection
                }
                .padding(16)
            }
            .navigationTitle("悬浮时钟")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { session.syncDocuments() }
            .confirmationDialog("清空全部 SRT 记录？", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("清空", role: .destructive) { session.clearSRT() }
                Button("取消", role: .cancel) {}
            }
        }
    }

    private var readout: some View {
        TimelineView(.periodic(from: .now, by: session.settings.showMilliseconds ? 0.03 : 0.2)) { context in
            let corrected = session.settings.corrected(context.date, offset: session.sync.offset)
            VStack(alignment: .leading, spacing: 4) {
                Text(ClockFaceText.dateLine(corrected))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(ClockFaceText.timeLine(corrected, milliseconds: session.settings.showMilliseconds))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(session.settings.useNetworkTime ? "网络校正开" : "设备时间")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var floatingSection: some View {
        card {
            Text(session.statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Toggle("显示悬浮窗", isOn: Binding(
                get: { session.isEnabled },
                set: { session.setEnabled($0) }
            ))
            .font(.body.weight(.semibold))
            if session.isPipActive {
                Label("画中画正在其他 App 上层", systemImage: "pip")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Toggle("悬浮窗包含字幕", isOn: binding(\.showCaptionsInFloat))
            Toggle("停留在本页时保持屏幕常亮", isOn: binding(\.keepAwake))
            Toggle("悬浮时不打断其他 App 的声音", isOn: binding(\.mixWithOtherAudio))
            Text("关掉上一行会独占音频，音乐被暂停，但时钟在后台更不容易被系统停掉。控制中心的暂停键也会关闭悬浮窗。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("重置悬浮位置") { session.resetPosition() }
                .font(.subheadline)
        }
    }

    private var appearanceSection: some View {
        card {
            Text("背景颜色")
                .font(.headline)
            Text("拖动圆盘选色。色相沿圆周，饱和度向外。圆盘只选最亮的颜色，和原版一样。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            ColorWheelRepresentable(colorHex: session.settings.colorHex) { hex in
                session.updateSettings { $0.colorHex = hex }
            }
            .frame(width: 240, height: 240)
            .frame(maxWidth: .infinity)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: session.settings.colorHex).opacity(Double(session.settings.alphaPercent) / 100))
                .frame(width: 120, height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12))
                )
                .frame(maxWidth: .infinity)
            sliderRow(
                title: "不透明度",
                value: alphaBinding,
                range: Double(ClockSettings.minAlpha)...Double(ClockSettings.maxAlpha),
                label: "\(session.settings.alphaPercent)%"
            )
            Text("画中画窗口本身不透明。低于 100% 时，颜色会按这个比例混进黑色，而不是透出后面的 App。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            sliderRow(
                title: "时间字号",
                value: fontBinding,
                range: Double(ClockSettings.minFont)...Double(ClockSettings.maxFont),
                label: "\(session.settings.fontSize)"
            )
            Button("恢复默认深灰") {
                session.updateSettings {
                    $0.colorHex = ClockSettings.defaultColor
                    $0.alphaPercent = 100
                }
            }
            .font(.subheadline)
        }
    }

    private var timeSection: some View {
        card {
            Text("时间")
                .font(.headline)
            Toggle("显示毫秒", isOn: binding(\.showMilliseconds))
            Toggle("使用网络时间校正", isOn: binding(\.useNetworkTime))
            Text(session.syncStatus)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            if let at = session.sync.at {
                Text("上次成功：\(at.formatted(date: .omitted, time: .standard))")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            Button {
                Task { await session.refreshSync() }
            } label: {
                if session.isSyncing {
                    ProgressView()
                } else {
                    Text("立即对时")
                }
            }
            .buttonStyle(.bordered)
            Text("优先用 SNTP（time.apple.com、Cloudflare、阿里云、NTP 池），失败再读 HTTPS 响应里的 Date。HTTP 只能到秒。毫秒显示按渲染时刻取值，大约每秒 30 帧，数字会跳而不是逐毫秒加一。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var captionSection: some View {
        card {
            Text("字幕标记")
                .font(.headline)
            Text("最多 \(CaptionRules.maxCount) 条，每条最多 \(CaptionRules.maxLength) 个字。点悬浮卡片上的字幕，或点下面的「记录」，都会高亮 3 秒并追加一条 SRT。外部按钮记录带星的那条。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField("输入字幕，如 停车前", text: $draftCaption)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit(addDraft)
                Button("添加", action: addDraft)
                    .buttonStyle(.borderedProminent)
            }
            if session.settings.captions.isEmpty {
                Text("还没有字幕。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(session.settings.captions, id: \.self) { caption in
                HStack(spacing: 8) {
                    Button {
                        session.arm(caption)
                    } label: {
                        Image(systemName: caption == session.settings.armedCaption ? "star.fill" : "star")
                            .foregroundStyle(caption == session.settings.armedCaption ? Color.orange : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(caption == session.settings.armedCaption ? "当前外部记录" : "设为外部记录")
                    Text(caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("记录") { session.logCaption(caption) }
                        .buttonStyle(.bordered)
                    Button("删除") { session.deleteCaption(caption) }
                        .buttonStyle(.bordered)
                        .tint(.red)
                }
            }
        }
    }

    private var srtSection: some View {
        card {
            Text("SRT 记录")
                .font(.headline)
            Text("共 \(session.srtCount) 条。文件名 road_test_srt.srt。在「文件」App 的「我的 iPhone / 悬浮时钟 / TimeFloat」里。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack {
                if session.srtCount > 0 {
                    ShareLink(item: srtFileURL) {
                        Text("分享")
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button("清空", role: .destructive) { confirmClear = true }
                    .buttonStyle(.bordered)
                    .disabled(session.srtCount == 0)
            }
            if session.srtLines.isEmpty {
                Text("还没有记录。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(session.srtLines.joined(separator: "\n"))
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
    }

    private func addDraft() {
        let trimmed = draftCaption.trimmingCharacters(in: .whitespacesAndNewlines)
        session.addCaption(draftCaption)
        if session.settings.captions.contains(trimmed) {
            draftCaption = ""
        }
    }

    private func binding(_ keyPath: WritableKeyPath<ClockSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { session.settings[keyPath: keyPath] },
            set: { newValue in
                session.updateSettings { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    private var alphaBinding: Binding<Double> {
        Binding(
            get: { Double(session.settings.alphaPercent) },
            set: { newValue in
                session.updateSettings { $0.alphaPercent = Int(newValue.rounded()) }
            }
        )
    }

    private var fontBinding: Binding<Double> {
        Binding(
            get: { Double(session.settings.fontSize) },
            set: { newValue in
                session.updateSettings { $0.fontSize = Int(newValue.rounded()) }
            }
        )
    }

    private func sliderRow(title: String, value: Binding<Double>, range: ClosedRange<Double>, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text(label)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: 1)
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func notice(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(tint)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private extension Color {
    init(hex: Int) {
        let rgb = RGB.from(hex: hex)
        self.init(red: rgb.r, green: rgb.g, blue: rgb.b)
    }
}

