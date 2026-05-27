import Foundation
import SwiftUI

enum ClaudeState: String, CaseIterable {
    case running
    case success
    case error
    case idle

    var color: Color {
        switch self {
        case .running:
            Color(red: 1.0, green: 0.78, blue: 0.18)
        case .success:
            Color(red: 0.23, green: 0.94, blue: 0.30)
        case .error:
            Color(red: 1.0, green: 0.20, blue: 0.16)
        case .idle:
            Color(red: 0.32, green: 0.36, blue: 0.40)
        }
    }

    var title: String {
        switch self {
        case .running:
            "Claude 正在工作"
        case .success:
            "上一轮已完成"
        case .error:
            "需要你处理"
        case .idle:
            "等待 Claude"
        }
    }

    var shortTitle: String {
        switch self {
        case .running:
            "工作中"
        case .success:
            "已完成"
        case .error:
            "需处理"
        case .idle:
            "待机"
        }
    }

    var detail: String {
        switch self {
        case .running:
            "正在思考、流式输出或调用工具"
        case .success:
            "可以切回终端查看结果"
        case .error:
            "权限确认、工具错误或进程退出"
        case .idle:
            "还没有读到有效状态"
        }
    }
}

struct StatusSnapshot: Equatable {
    var state: ClaudeState
    var updatedAt: Date
    var source: String
    var transcriptPath: String?
    var rawValue: String?

    static let initial = StatusSnapshot(state: .idle, updatedAt: Date(), source: "启动中", transcriptPath: nil, rawValue: nil)

    var menuTitle: String {
        "\(state.title) · \(source)"
    }
}

enum StatusPaths {
    static let home = FileManager.default.homeDirectoryForCurrentUser
    static let claudeDirectory = home.appendingPathComponent(".claude", isDirectory: true)
    static let statusFile = claudeDirectory.appendingPathComponent("traffic_light_status")
    static let eventFile = claudeDirectory.appendingPathComponent("traffic_light_event.json")
    static let projectsDirectory = claudeDirectory.appendingPathComponent("projects", isDirectory: true)
}

@MainActor
final class StatusMonitor: ObservableObject {
    static let shared = StatusMonitor()

    @Published private(set) var snapshot = StatusSnapshot.initial

    private var timer: Timer?
    private let fileManager = FileManager.default

    private init() {}

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        if let hookSnapshot = readHookStatus() {
            snapshot = hookSnapshot
            return
        }

        if let logSnapshot = readLatestLogStatus() {
            snapshot = logSnapshot
            return
        }

        snapshot = StatusSnapshot(state: .idle, updatedAt: Date(), source: "未找到 Claude 状态", transcriptPath: nil, rawValue: nil)
    }

    private func readHookStatus() -> StatusSnapshot? {
        guard let raw = try? String(contentsOf: StatusPaths.statusFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }

        let attributes = try? fileManager.attributesOfItem(atPath: StatusPaths.statusFile.path)
        let modified = attributes?[.modificationDate] as? Date ?? Date()
        return StatusSnapshot(
            state: mapStatus(raw),
            updatedAt: modified,
            source: "Claude hook",
            transcriptPath: readEventTranscriptPath(),
            rawValue: raw
        )
    }

    private func readEventTranscriptPath() -> String? {
        guard let data = try? Data(contentsOf: StatusPaths.eventFile),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object["transcript_path"] as? String
    }

    private func mapStatus(_ value: String) -> ClaudeState {
        let normalized = value.lowercased()
        if ["running", "processing", "thinking", "streaming", "running_tool", "compacting", "yellow"].contains(normalized) {
            return .running
        }
        if ["success", "done", "complete", "completed", "clean", "green"].contains(normalized) {
            return .success
        }
        if ["error", "failed", "failure", "permission", "waiting_permission", "ended", "exit", "red"].contains(normalized) {
            return .error
        }
        return .idle
    }

    private func readLatestLogStatus() -> StatusSnapshot? {
        guard let logURL = newestJSONLFile(in: StatusPaths.projectsDirectory),
              let lines = tailLines(from: logURL, byteLimit: 160_000) else {
            return nil
        }

        for line in lines.reversed() where !line.isEmpty {
            guard let data = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            if let inferred = inferStatus(from: object, transcriptPath: logURL.path) {
                return inferred
            }
        }

        return nil
    }

    private func newestJSONLFile(in directory: URL) -> URL? {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var newest: (url: URL, date: Date)?
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values?.isRegularFile == true else {
                continue
            }
            let date = values?.contentModificationDate ?? .distantPast
            if newest == nil || date > newest!.date {
                newest = (url, date)
            }
        }
        return newest?.url
    }

    private func tailLines(from url: URL, byteLimit: UInt64) -> [String]? {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer {
            try? handle.close()
        }

        let end = (try? handle.seekToEnd()) ?? 0
        let start = end > byteLimit ? end - byteLimit : 0
        try? handle.seek(toOffset: start)
        guard let data = try? handle.readToEnd(),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        return text.components(separatedBy: .newlines)
    }

    private func inferStatus(from object: [String: Any], transcriptPath: String) -> StatusSnapshot? {
        if let attachment = object["attachment"] as? [String: Any],
           attachment["type"] as? String == "hook_non_blocking_error" {
            return StatusSnapshot(state: .error, updatedAt: Date(), source: "Claude 日志", transcriptPath: transcriptPath, rawValue: "hook_non_blocking_error")
        }

        if object["type"] as? String == "assistant",
           let message = object["message"] as? [String: Any],
           let stopReason = message["stop_reason"] as? String {
            if stopReason == "tool_use" {
                return StatusSnapshot(state: .running, updatedAt: Date(), source: "Claude 日志", transcriptPath: transcriptPath, rawValue: stopReason)
            }
            if ["end_turn", "stop_sequence", "max_tokens"].contains(stopReason) {
                return StatusSnapshot(state: .success, updatedAt: Date(), source: "Claude 日志", transcriptPath: transcriptPath, rawValue: stopReason)
            }
        }

        if object["type"] as? String == "user",
           object["message"] != nil {
            return StatusSnapshot(state: .running, updatedAt: Date(), source: "Claude 日志", transcriptPath: transcriptPath, rawValue: "user_prompt")
        }

        return nil
    }
}
