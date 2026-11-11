import SwiftUI
import WidgetKit

@available(iOS 18.0, *)
struct LogCaptionControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "timefloat.logCaption") {
            ControlWidgetButton(action: LogArmedCaptionIntent()) {
                Label("记录字幕", systemImage: "clock.badge.checkmark")
            }
        }
        .displayName("记录字幕")
        .description("把悬浮时钟当前选中的字幕写入 SRT 和 time_float.txt。")
    }
}
