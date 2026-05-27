import SwiftUI
import AppKit

struct MatteBlackBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        v.wantsLayer = true
        v.layer?.cornerRadius = 30
        v.layer?.cornerCurve = .continuous
        v.layer?.masksToBounds = true
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct TrafficLightView: View {
    @ObservedObject var monitor: ClaudeMonitor

    private var active: ClaudeStatus { monitor.status }

    var body: some View {
        ZStack {
            MatteBlackBackground()

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.black.opacity(0.55))

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)

            VStack(spacing: 20) {
                Light(color: Color(red: 1.00, green: 0.27, blue: 0.27),
                      isOn: active == .error,   pulse: false)
                Light(color: Color(red: 1.00, green: 0.78, blue: 0.10),
                      isOn: active == .running, pulse: true)
                Light(color: Color(red: 0.18, green: 0.82, blue: 0.45),
                      isOn: active == .success, pulse: false)
            }
            .padding(.vertical, 24)
        }
        .frame(width: 88, height: 232)
        .contextMenu {
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }
}

private struct Light: View {
    let color: Color
    let isOn: Bool
    let pulse: Bool
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 52, height: 52)

            Circle()
                .fill(isOn ? color : color.opacity(0.18))
                .frame(width: 44, height: 44)
                .overlay(
                    Circle().stroke(Color.white.opacity(isOn ? 0.18 : 0.05), lineWidth: 0.5)
                )
                .shadow(color: isOn ? color.opacity(0.75) : .clear, radius: isOn ? 12 : 0)
                .shadow(color: isOn ? color.opacity(0.45) : .clear, radius: isOn ? 22 : 0)

            if isOn && pulse {
                Circle()
                    .stroke(color.opacity(0.55 - phase * 0.55), lineWidth: 1.5)
                    .frame(width: 44 + phase * 28, height: 44 + phase * 28)
            }
        }
        .frame(width: 52, height: 52)
        .animation(.easeInOut(duration: 0.3), value: isOn)
        .onAppear {
            guard pulse else { return }
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}
