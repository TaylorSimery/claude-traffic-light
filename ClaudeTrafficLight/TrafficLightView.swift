import SwiftUI

struct TrafficLightView: View {
    @EnvironmentObject private var monitor: StatusMonitor

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.10),
                    Color(red: 0.02, green: 0.02, blue: 0.025)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                trafficLight

                VStack(spacing: 7) {
                    Text(monitor.snapshot.state.title)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(monitor.snapshot.state.detail)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }

                statusPanel
            }
            .padding(.vertical, 28)
            .padding(.horizontal, 24)
        }
    }

    private var trafficLight: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 48, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color(red: 0.02, green: 0.025, blue: 0.03),
                            Color.black
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 48, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.55), radius: 24, y: 18)

            VStack(spacing: 22) {
                BulbView(color: ClaudeState.error.color, isActive: monitor.snapshot.state == .error)
                BulbView(color: ClaudeState.running.color, isActive: monitor.snapshot.state == .running)
                BulbView(color: ClaudeState.success.color, isActive: monitor.snapshot.state == .success)
            }
            .padding(.vertical, 22)
        }
        .frame(width: 176, height: 378)
        .accessibilityLabel(monitor.snapshot.state.title)
    }

    private var statusPanel: some View {
        VStack(spacing: 10) {
            HStack {
                Label(monitor.snapshot.state.shortTitle, systemImage: "circle.fill")
                    .foregroundStyle(monitor.snapshot.state.color)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(Self.relativeFormatter.localizedString(for: monitor.snapshot.updatedAt, relativeTo: Date()))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Divider()
                .overlay(Color.white.opacity(0.12))

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                infoRow(title: "来源", value: monitor.snapshot.source)
                infoRow(title: "状态", value: monitor.snapshot.rawValue ?? monitor.snapshot.state.rawValue)
                if let transcriptPath = monitor.snapshot.transcriptPath {
                    infoRow(title: "日志", value: URL(fileURLWithPath: transcriptPath).lastPathComponent)
                }
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                }
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        GridRow {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.42))
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "zh_Hans")
        return formatter
    }()
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
                            Color.white.opacity(0.95),
                            color,
                            color.opacity(0.78)
                        ]
                        : [
                            color.opacity(0.30),
                            color.opacity(0.12),
                            Color.black.opacity(0.82)
                        ],
                        center: UnitPoint(x: 0.34, y: 0.28),
                        startRadius: 2,
                        endRadius: 58
                    )
                )
                .overlay {
                    Circle()
                        .strokeBorder(Color.black.opacity(0.78), lineWidth: 5)
                }
                .shadow(color: isActive ? color.opacity(0.75) : .black.opacity(0.45), radius: isActive ? 28 : 8)
                .shadow(color: isActive ? color.opacity(0.32) : .clear, radius: 54)

            Circle()
                .fill(Color.white.opacity(isActive ? 0.34 : 0.10))
                .frame(width: 22, height: 22)
                .blur(radius: 3)
                .offset(x: 22, y: 18)
        }
        .frame(width: 106, height: 106)
    }
}
