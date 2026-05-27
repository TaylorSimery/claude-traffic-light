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
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.035, green: 0.037, blue: 0.041).opacity(0.96))
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white.opacity(0.035))
                        .blur(radius: 1.2)
                }
                .shadow(color: .black.opacity(0.42), radius: 12, x: 0, y: 7)
                .shadow(color: .black.opacity(0.22), radius: 22, x: 0, y: 16)

            VStack(spacing: 15) {
                BulbView(color: ClaudeState.error.color, isActive: monitor.snapshot.state == .error)
                BulbView(color: ClaudeState.running.color, isActive: monitor.snapshot.state == .running)
                BulbView(color: ClaudeState.success.color, isActive: monitor.snapshot.state == .success)
            }
            .padding(.vertical, 17)
        }
        .frame(width: 76, height: 204)
        .padding(14)
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
                        endRadius: 27
                    )
                )
                .overlay {
                    Circle()
                        .strokeBorder(Color.black.opacity(0.86), lineWidth: 3)
                }
                .shadow(color: isActive ? color.opacity(0.70) : .black.opacity(0.35), radius: isActive ? 15 : 4)
                .shadow(color: isActive ? color.opacity(0.24) : .clear, radius: 26)

            Circle()
                .fill(Color.white.opacity(isActive ? 0.32 : 0.08))
                .frame(width: 10, height: 10)
                .blur(radius: 1.6)
                .offset(x: 10, y: 9)
        }
        .frame(width: 48, height: 48)
    }
}
