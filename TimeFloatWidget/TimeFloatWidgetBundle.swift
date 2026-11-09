import SwiftUI
import WidgetKit

@main
struct TimeFloatWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimeFloatClockWidget()
        ClockLiveActivity()
        if #available(iOS 18.0, *) {
            LogCaptionControl()
        }
    }
}
