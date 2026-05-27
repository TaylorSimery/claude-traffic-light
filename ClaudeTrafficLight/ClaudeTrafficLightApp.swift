import SwiftUI
import AppKit

@main
struct ClaudeTrafficLightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPanel?
    private let monitor = ClaudeMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let view = TrafficLightView(monitor: monitor)
            .environmentObject(monitor)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 92, height: 220)

        let p = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 92, height: 220),
            backing: .buffered,
            defer: false
        )
        p.contentView = hosting
        p.center()
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            p.setFrameOrigin(NSPoint(x: f.maxX - 120, y: f.maxY - 260))
        }
        p.makeKeyAndOrderFront(nil)
        self.panel = p
        monitor.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
