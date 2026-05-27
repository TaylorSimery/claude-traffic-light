import SwiftUI
import AppKit

struct MatteBlackBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .underWindowBackground
        v.blendingMode = .behindWindow
        v.state = .active
        v.wantsLayer = true
        v.layer?.cornerRadius = 28
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

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.10).opacity(0.95),
                            Color(white: 0.02).opacity(0.98)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.white.opacity(0.0)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .blendMode(.plusLighter)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.6)

            VStack(spacing: 18) {
                Light(color: .red,    isOn: active == .error,   pulse: false)
                Light(color: .yellow, isOn: active == .running, pulse: true)
                Light(color: .green,  isOn: active == .success, pulse: false)
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
                .fill(Color.black.opacity(0.65))
                .frame(width: 50, height: 50)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )

            Circle()
                .fill(
                    RadialGradient(
                        colors: isOn
                            ? [color.opacity(0.95), color.opacity(0.55)]
                            : [color.opacity(0.16), color.opacity(0.04)],
                        center: .init(x: 0.35, y: 0.30),
                        startRadius: 1, endRadius: 28
                    )
                )
                .frame(width: 44, height: 44)
                .shadow(color: isOn ? color.opacity(0.85) : .clear,
                        radius: isOn ? 14 : 0)
                .shadow(color: isOn ? color.opacity(0.55) : .clear,
                        radius: isOn ? 24 : 0)

            Circle()
                .fill(Color.white.opacity(isOn ? 0.55 : 0.08))
                .frame(width: 12, height: 8)
                .blur(radius: 3)
                .offset(x: -8, y: -10)

            if isOn && pulse {
                Circle()
                    .stroke(color.opacity(0.6 - phase * 0.6), lineWidth: 2)
                    .frame(width: 44 + phase * 26, height: 44 + phase * 26)
            }
        }
        .frame(width: 50, height: 50)
        .animation(.easeInOut(duration: 0.35), value: isOn)
        .onAppear {
            guard pulse else { return }
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}
