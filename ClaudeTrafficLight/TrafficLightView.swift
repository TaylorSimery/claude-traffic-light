import SwiftUI
import AppKit

enum TrafficLightLayout {
    static let windowWidth: CGFloat = 98
    static let windowHeight: CGFloat = 224
    static let bodyWidth: CGFloat = 92
    static let bodyHeight: CGFloat = 218
    static let cornerRadius: CGFloat = 26
    static let lightOuterSize: CGFloat = 58
    static let lightSize: CGFloat = 46
}

struct MatteBlackBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        v.wantsLayer = true
        v.layer?.cornerRadius = TrafficLightLayout.cornerRadius
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

            RoundedRectangle(cornerRadius: TrafficLightLayout.cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.13, green: 0.14, blue: 0.16),
                            Color(red: 0.04, green: 0.05, blue: 0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            RoundedRectangle(cornerRadius: TrafficLightLayout.cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.5)

            VStack(spacing: 18) {
                Light(color: Color(red: 1.00, green: 0.27, blue: 0.27),
                      isOn: active == .error,   pulse: false)
                Light(color: Color(red: 1.00, green: 0.82, blue: 0.18),
                      isOn: active == .running, pulse: true)
                Light(color: Color(red: 0.18, green: 0.82, blue: 0.45),
                      isOn: active == .success, pulse: false)
            }
            .padding(.vertical, 24)
        }
        .frame(width: TrafficLightLayout.bodyWidth, height: TrafficLightLayout.bodyHeight)
        .clipShape(RoundedRectangle(cornerRadius: TrafficLightLayout.cornerRadius, style: .continuous))
        .padding(2)
        .frame(width: TrafficLightLayout.windowWidth, height: TrafficLightLayout.windowHeight)
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
                .fill(Color.black.opacity(0.58))
                .frame(width: TrafficLightLayout.lightOuterSize, height: TrafficLightLayout.lightOuterSize)
                .shadow(color: .black.opacity(0.55), radius: 2, x: 0, y: 1)

            Circle()
                .fill(isOn ? color.opacity(0.28) : .clear)
                .frame(width: TrafficLightLayout.lightOuterSize + 22, height: TrafficLightLayout.lightOuterSize + 22)
                .blur(radius: 12)

            Circle()
                .fill(isOn ? color : color.opacity(0.12))
                .frame(width: TrafficLightLayout.lightSize, height: TrafficLightLayout.lightSize)
                .overlay(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(isOn ? 0.48 : 0.16),
                                    .clear
                                ],
                                center: UnitPoint(x: 0.34, y: 0.25),
                                startRadius: 0,
                                endRadius: 18
                            )
                        )
                        .clipShape(Circle())
                )
                .overlay(
                    Circle().stroke(Color.black.opacity(0.42), lineWidth: 3)
                )
                .shadow(color: isOn ? color.opacity(0.7) : .clear, radius: isOn ? 14 : 0)
                .shadow(color: isOn ? color.opacity(0.35) : .clear, radius: isOn ? 24 : 0)

            if isOn && pulse {
                Circle()
                    .stroke(color.opacity(0.42 - phase * 0.42), lineWidth: 1)
                    .frame(
                        width: TrafficLightLayout.lightSize + phase * 30,
                        height: TrafficLightLayout.lightSize + phase * 30
                    )
            }
        }
        .frame(width: TrafficLightLayout.lightOuterSize, height: TrafficLightLayout.lightOuterSize)
        .animation(.easeInOut(duration: 0.3), value: isOn)
        .onAppear {
            guard pulse else { return }
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}
