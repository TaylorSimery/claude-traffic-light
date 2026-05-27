import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = StatusMonitor.shared
    private var statusItem: NSStatusItem?
    private var cancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        setupStatusItem()
        monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        item.button?.target = self
        item.button?.action = #selector(openMainWindow)
        item.button?.imagePosition = .imageLeading
        item.button?.font = .systemFont(ofSize: 13, weight: .semibold)

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "显示 Claude Traffic Light", action: #selector(openMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "打开 Claude 日志目录", action: #selector(openLogsFolder), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu

        cancellable = monitor.$snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.updateStatusItem(snapshot)
            }
    }

    private func updateStatusItem(_ snapshot: StatusSnapshot) {
        statusItem?.button?.image = StatusSymbolRenderer.image(for: snapshot.state)
        statusItem?.button?.toolTip = snapshot.menuTitle
    }

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.contentViewController != nil || $0.contentView != nil }) {
            window.makeKeyAndOrderFront(nil)
            return
        }
        NSApp.sendAction(Selector(("showMainWindow:")), to: nil, from: nil)
    }

    @objc private func openLogsFolder() {
        NSWorkspace.shared.open(StatusPaths.projectsDirectory)
    }
}

enum StatusSymbolRenderer {
    @MainActor
    static func image(for state: ClaudeState) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let rect = NSRect(x: 3, y: 3, width: 12, height: 12)
        let color = NSColor(state.color)
        color.withAlphaComponent(0.28).setFill()
        NSBezierPath(ovalIn: rect.insetBy(dx: -2, dy: -2)).fill()
        color.setFill()
        NSBezierPath(ovalIn: rect).fill()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
