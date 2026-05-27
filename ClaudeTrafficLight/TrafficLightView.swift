import SwiftUI

struct TrafficLightView: View {
    @EnvironmentObject private var monitor: StatusMonitor

    var body: some View {
        trafficLight
            .contextMenu {
                Button("退出 Claude Traffic Light") {
                    NSApp.terminate(nil)
                }
            }
            .help(monitor.snapshot.menuTitle)
    }

    private var trafficLight: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color(red: 0.035, green: 0.038, blue: 0.043).opacity(0.94),
                            Color.black
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8)
                }
                .background {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.42)
                }
                .shadow(color: .black.opacity(0.55), radius: 15, y: 8)

            VStack(spacing: 10) {
                BulbView(color: ClaudeState.error.color, isActive: monitor.snapshot.state == .error)
                BulbView(color: ClaudeState.running.color, isActive: monitor.snapshot.state == .running)
                BulbView(color: ClaudeState.success.color, isActive: monitor.snapshot.state == .success)
            }
            .padding(.vertical, 12)
        }
        .frame(width: 72, height: 164)
        .accessibilityLabel(monitor.snapshot.state.title)
    }
}

struct BulbView: View {
    let color: Color
    let isActive: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            Circle()
                .fill(
                    RadialGradient(
                        colors: isActive
                        ? [
                            Color.white.opacity(0.80),
                            color,
                            color.opacity(0.78)
                        ]
                        : [
                            color.opacity(0.26),
                            color.opacity(0.12),
                            Color.black.opacity(0.82)
                        ],
                        center: UnitPoint(x: 0.34, y: 0.28),
                        startRadius: 1,
                        endRadius: 23
                    )
                )
                .overlay {
                    Circle()
                        .strokeBorder(Color.black.opacity(0.82), lineWidth: 2.4)
                }
                .shadow(color: isActive ? color.opacity(0.72) : .black.opacity(0.35), radius: isActive ? 12 : 4)
                .shadow(color: isActive ? color.opacity(0.26) : .clear, radius: 22)

            Circle()
                .fill(Color.white.opacity(isActive ? 0.32 : 0.08))
                .frame(width: 8, height: 8)
                .blur(radius: 1.4)
                .offset(x: 9, y: 8)
        }
        .frame(width: 42, height: 42)
    }
}
