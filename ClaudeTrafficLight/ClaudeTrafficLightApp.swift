import SwiftUI

@main
struct ClaudeTrafficLightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var monitor = StatusMonitor.shared

    var body: some Scene {
        WindowGroup {
            TrafficLightView()
                .environmentObject(monitor)
                .frame(minWidth: 300, idealWidth: 340, maxWidth: 420, minHeight: 520, idealHeight: 600)
        }
        .windowResizability(.contentSize)

        Settings {
            EmptyView()
        }
    }
}
