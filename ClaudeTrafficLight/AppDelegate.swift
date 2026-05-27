import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = StatusMonitor.shared
    private var panel: NSPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        createWidgetPanel()
        monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }

    private func createWidgetPanel() {
        let size = NSSize(width: 104, height: 232)
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = NSPoint(
            x: visibleFrame.maxX - size.width - 28,
            y: visibleFrame.maxY - size.height - 58
        )

        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true

        let rootView = TrafficLightView()
            .environmentObject(monitor)
            .frame(width: size.width, height: size.height)

        panel.contentView = DragHostingView(rootView: AnyView(rootView))
        panel.orderFrontRegardless()
        self.panel = panel
    }
}

final class DragHostingView: NSHostingView<AnyView> {
    override var mouseDownCanMoveWindow: Bool {
        true
    }
}
