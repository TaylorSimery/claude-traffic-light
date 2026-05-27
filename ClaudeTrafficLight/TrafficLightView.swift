import SwiftUI
import AppKit

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        v.wantsLayer = true
        v.layer?.cornerRadius = 28
        v.layer?.cornerCurve = .continuous
        v.layer?.masksToBounds = true
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct TrafficLightView: View {
    @ObservedObject var monitor: ClaudeMonitor

    private var active: ClaudeStatus { monitor.status }

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .blendMode(.plusLighter)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 0.6)

            VStack(spacing: 14) {
                Light(color: .red,    isOn: active == .error,   pulse: false)
                Light(color: .yellow, isOn: active == .running, pulse: true)
                Light(color: .green,  isOn: active == .success, pulse: false)

                Text(monitor.detail)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 16)
        }
        .frame(width: 92, height: 220)
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
                .fill(Color.black.opacity(0.55))
                .frame(width: 50, height: 50)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                )

            Circle()
                .fill(
                    RadialGradient(
                        colors: isOn
                            ? [color.opacity(0.95), color.opacity(0.55)]
                            : [color.opacity(0.18), color.opacity(0.06)],
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
                .fill(Color.white.opacity(isOn ? 0.55 : 0.10))
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
