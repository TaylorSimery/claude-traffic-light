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
    static let projectsDirectory = claudeDirectory.appendingPathComponent("projects", isDirectory: true)
}

@MainActor
final class StatusMonitor: ObservableObject {
    static let shared = StatusMonitor()

    @Published private(set) var snapshot = StatusSnapshot.initial

    private var timer: Timer?
    private var isRefreshing = false

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
        guard !isRefreshing else {
            return
        }
        isRefreshing = true

        Task.detached(priority: .utility) {
            let nextSnapshot = StatusScanner().scan()
            await MainActor.run {
                StatusMonitor.shared.finishRefresh(nextSnapshot)
            }
        }
    }

    private func finishRefresh(_ nextSnapshot: StatusSnapshot) {
        snapshot = nextSnapshot
        isRefreshing = false
    }
}

private struct StatusScanner {
    private struct LogStatus {
        var snapshot: StatusSnapshot
        var logUpdatedAt: Date
    }

    private let fileManager = FileManager.default

    func scan() -> StatusSnapshot {
        let processRunning = isClaudeCodeRunning()

        if let logStatus = readLatestLogStatus(processRunning: processRunning) {
            return logStatus.snapshot
        }

        if processRunning {
            return StatusSnapshot(
                state: .running,
                updatedAt: Date(),
                source: "Claude Code 运行中",
                transcriptPath: nil,
                rawValue: "process_running"
            )
        } else {
            return StatusSnapshot(
                state: .error,
                updatedAt: Date(),
                source: "Claude Code 已停止",
                transcriptPath: nil,
                rawValue: "process_not_running"
            )
        }
    }

    func isClaudeCodeRunning() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,comm=,args="]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return false
        }

        let deadline = Date().addingTimeInterval(0.6)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }

        if process.isRunning {
            process.terminate()
            return false
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else {
            return false
        }

        if process.terminationStatus != 0 {
            return false
        }

        return text
            .split(separator: "\n")
            .map { $0.lowercased() }
            .contains { line in
                isClaudeProcessLine(String(line))
            }
    }

    private func isClaudeProcessLine(_ line: String) -> Bool {
        guard !line.contains("claudetrafficlight"),
              !line.contains("claude-traffic-light"),
              !line.contains("xcode"),
              !line.contains("swift-frontend") else {
            return false
        }

        let fields = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard fields.count >= 2 else {
            return false
        }

        let command = String(fields[1])
        let args = fields.count >= 3 ? String(fields[2]) : ""

        return command.hasSuffix("/claude")
            || command == "claude"
            || args.contains("/bin/claude")
            || args.contains("/claude ")
            || args.contains(" claude ")
            || args.hasPrefix("claude ")
            || args.contains("claude-code")
    }

    private func readLatestLogStatus(processRunning: Bool) -> LogStatus? {
        guard let logURL = newestJSONLFile(in: StatusPaths.projectsDirectory),
              let lines = tailLines(from: logURL, byteLimit: 160_000) else {
            return nil
        }
        let logUpdatedAt = modifiedDate(of: logURL) ?? Date()

        for line in lines.reversed() where !line.isEmpty {
            guard let data = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            if let inferred = inferStatus(
                from: object,
                transcriptPath: logURL.path,
                logUpdatedAt: logUpdatedAt,
                processRunning: processRunning
            ) {
                return LogStatus(snapshot: inferred, logUpdatedAt: logUpdatedAt)
            }
        }

        return LogStatus(
            snapshot: StatusSnapshot(
                state: processRunning ? .running : .error,
                updatedAt: logUpdatedAt,
                source: processRunning ? "Claude 日志" : "Claude Code 已停止",
                transcriptPath: logURL.path,
                rawValue: processRunning ? "unknown" : "process_not_running"
            ),
            logUpdatedAt: logUpdatedAt
        )
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

    private func modifiedDate(of url: URL) -> Date? {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate
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

    private func inferStatus(
        from object: [String: Any],
        transcriptPath: String,
        logUpdatedAt: Date,
        processRunning: Bool
    ) -> StatusSnapshot? {
        let hookEvent = (object["hook_event_name"] as? String) ?? (object["hookEventName"] as? String)
        if let hookEvent {
            switch hookEvent {
            case "UserPromptSubmit", "PreToolUse", "PostToolUse", "PreCompact", "SessionStart", "SubagentStop":
                if shouldTreatRunningStateAsStopped(logUpdatedAt: logUpdatedAt, processRunning: processRunning) {
                    return stoppedSnapshot(transcriptPath: transcriptPath, logUpdatedAt: logUpdatedAt, rawValue: hookEvent)
                }
                return StatusSnapshot(state: .running, updatedAt: Date(), source: "Claude 日志", transcriptPath: transcriptPath, rawValue: hookEvent)
            case "PermissionRequest":
                return StatusSnapshot(state: .error, updatedAt: Date(), source: "Claude 日志", transcriptPath: transcriptPath, rawValue: hookEvent)
            case "Stop":
                return StatusSnapshot(state: .success, updatedAt: Date(), source: "Claude 日志", transcriptPath: transcriptPath, rawValue: hookEvent)
            case "SessionEnd":
                return StatusSnapshot(state: .error, updatedAt: Date(), source: "Claude 日志", transcriptPath: transcriptPath, rawValue: hookEvent)
            default:
                break
            }
        }

        if let type = object["type"] as? String {
            let normalizedType = type.lowercased()
            if ["permission-request", "permission_request", "permission-denied", "error", "interrupted", "abort", "sessionend"].contains(normalizedType) {
                return StatusSnapshot(state: .error, updatedAt: Date(), source: "Claude 日志", transcriptPath: transcriptPath, rawValue: type)
            }
            if normalizedType == "last-prompt" || normalizedType == "permission-mode" || normalizedType == "file-history-snapshot" {
                return nil
            }
        }

        if let attachment = object["attachment"] as? [String: Any],
           let attachmentType = attachment["type"] as? String {
            let normalizedAttachment = attachmentType.lowercased()
            if normalizedAttachment.contains("error")
                || normalizedAttachment.contains("interrupted")
                || normalizedAttachment.contains("denied")
                || normalizedAttachment.contains("rejected") {
                return StatusSnapshot(state: .error, updatedAt: Date(), source: "Claude 日志", transcriptPath: transcriptPath, rawValue: attachmentType)
            }
        }

        if object["type"] as? String == "assistant",
           let message = object["message"] as? [String: Any],
           let stopReason = message["stop_reason"] as? String {
            if stopReason == "tool_use" {
                if shouldTreatRunningStateAsStopped(logUpdatedAt: logUpdatedAt, processRunning: processRunning) {
                    return stoppedSnapshot(transcriptPath: transcriptPath, logUpdatedAt: logUpdatedAt, rawValue: stopReason)
                }
                return StatusSnapshot(state: .running, updatedAt: Date(), source: "Claude 日志", transcriptPath: transcriptPath, rawValue: stopReason)
            }
            if ["end_turn", "stop_sequence", "max_tokens"].contains(stopReason) {
                return StatusSnapshot(state: .success, updatedAt: Date(), source: "Claude 日志", transcriptPath: transcriptPath, rawValue: stopReason)
            }
            if ["error", "cancelled", "canceled", "interrupted", "abort"].contains(stopReason) {
                return StatusSnapshot(state: .error, updatedAt: Date(), source: "Claude 日志", transcriptPath: transcriptPath, rawValue: stopReason)
            }
        }

        if object["type"] as? String == "user",
           let message = object["message"] as? [String: Any] {
            if let content = message["content"] as? [[String: Any]],
               content.contains(where: isErrorToolResult) {
                return StatusSnapshot(state: .error, updatedAt: Date(), source: "Claude 日志", transcriptPath: transcriptPath, rawValue: "tool_result_error")
            }
            if shouldTreatRunningStateAsStopped(logUpdatedAt: logUpdatedAt, processRunning: processRunning) {
                return stoppedSnapshot(transcriptPath: transcriptPath, logUpdatedAt: logUpdatedAt, rawValue: "user_prompt")
            }
            return StatusSnapshot(state: .running, updatedAt: Date(), source: "Claude 日志", transcriptPath: transcriptPath, rawValue: "user_prompt")
        }

        return nil
    }

    private func isErrorToolResult(_ item: [String: Any]) -> Bool {
        guard item["type"] as? String == "tool_result" else {
            return false
        }
        if item["is_error"] as? Bool == true {
            return true
        }
        let content = String(describing: item["content"] ?? "").lowercased()
        return content.contains("rejected")
            || content.contains("interrupted")
            || content.contains("doesn't want to proceed")
            || content.contains("error")
    }

    private func shouldTreatRunningStateAsStopped(logUpdatedAt: Date, processRunning: Bool) -> Bool {
        !processRunning || Date().timeIntervalSince(logUpdatedAt) > 20
    }

    private func stoppedSnapshot(transcriptPath: String, logUpdatedAt: Date, rawValue: String) -> StatusSnapshot {
        StatusSnapshot(
            state: .error,
            updatedAt: logUpdatedAt,
            source: "Claude Code 已停止",
            transcriptPath: transcriptPath,
            rawValue: rawValue
        )
    }
}
