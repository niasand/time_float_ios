import SwiftUI

@main
struct TimeFloatApp: App {
    @StateObject private var session = FloatingClockSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .tint(Color(red: 63 / 255, green: 81 / 255, blue: 181 / 255))
        }
    }
}
