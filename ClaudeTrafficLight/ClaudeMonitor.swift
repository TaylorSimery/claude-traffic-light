import Foundation
import Combine

enum ClaudeStatus: String {
    case idle, running, success, error
}

final class ClaudeMonitor: ObservableObject {
    @Published private(set) var status: ClaudeStatus = .idle
    @Published private(set) var detail: String = "Waiting"

    private let claudeDir: URL
    private var timer: Timer?
    private var lastActivity: Date = .distantPast
    private var lastSessionPath: String?
    private var lastSessionSize: UInt64 = 0

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.claudeDir = home.appendingPathComponent(".claude/projects", isDirectory: true)
    }

    func start() {
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    deinit { timer?.invalidate() }

    private func tick() {
        let processAlive = isClaudeProcessRunning()
        guard let latest = newestSessionFile() else {
            update(status: processAlive ? .running : .idle,
                   detail: processAlive ? "Starting" : "No session")
            return
        }

        let attrs = (try? FileManager.default.attributesOfItem(atPath: latest.path)) ?? [:]
        let size = (attrs[.size] as? NSNumber)?.uint64Value ?? 0
        let mtime = (attrs[.modificationDate] as? Date) ?? .distantPast
        let interval = Date().timeIntervalSince(mtime)

        if latest.path != lastSessionPath || size != lastSessionSize {
            lastSessionPath = latest.path
            lastSessionSize = size
            lastActivity = Date()
        }

        let lastLine = readLastJSONLine(url: latest)
        let signal = inferStatus(lastLine: lastLine,
                                 processAlive: processAlive,
                                 idleSeconds: interval)
        update(status: signal.0, detail: signal.1)
    }

    private func update(status: ClaudeStatus, detail: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.status != status { self.status = status }
            if self.detail != detail { self.detail = detail }
        }
    }

    private func isClaudeProcessRunning() -> Bool {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-lc", "pgrep -f 'claude( |$)' | head -1"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do { try task.run() } catch { return false }
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: data, encoding: .utf8) ?? ""
        return !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func newestSessionFile() -> URL? {
        let fm = FileManager.default
        guard let projects = try? fm.contentsOfDirectory(at: claudeDir,
                                                        includingPropertiesForKeys: [.contentModificationDateKey],
                                                        options: [.skipsHiddenFiles]) else { return nil }
        var newest: URL?
        var newestDate = Date.distantPast
        for dir in projects {
            guard let files = try? fm.contentsOfDirectory(at: dir,
                                                         includingPropertiesForKeys: [.contentModificationDateKey],
                                                         options: [.skipsHiddenFiles]) else { continue }
            for f in files where f.pathExtension == "jsonl" {
                let d = (try? f.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                if d > newestDate { newestDate = d; newest = f }
            }
        }
        return newest
    }

    private func readLastJSONLine(url: URL) -> [String: Any]? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let chunk: UInt64 = 8192
        let start = size > chunk ? size - chunk : 0
        try? handle.seek(toOffset: start)
        let data = handle.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let lines = text.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        guard let last = lines.last,
              let lineData = last.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any]
        else { return nil }
        return obj
    }

    private func inferStatus(lastLine: [String: Any]?, processAlive: Bool, idleSeconds: TimeInterval)
        -> (ClaudeStatus, String)
    {
        guard let line = lastLine else {
            return processAlive ? (.running, "Working") : (.idle, "Idle")
        }
        let type = line["type"] as? String ?? ""
        let role = (line["message"] as? [String: Any])?["role"] as? String

        if type == "system" {
            if let sub = line["subtype"] as? String, sub.contains("error") {
                return (.error, "System error")
            }
        }

        if let msg = line["message"] as? [String: Any] {
            if let stop = msg["stop_reason"] as? String {
                switch stop {
                case "tool_use":
                    if processAlive && idleSeconds < 3 {
                        return (.running, "Calling tool")
                    } else {
                        return (.error, "Awaiting permission")
                    }
                case "end_turn":
                    return (.success, "Done")
                case "max_tokens":
                    return (.error, "Truncated")
                case "refusal", "stop_sequence":
                    return (.success, "Done")
                default: break
                }
            }
            if let content = msg["content"] as? [[String: Any]] {
                for block in content {
                    if (block["type"] as? String) == "tool_use" && processAlive && idleSeconds < 3 {
                        return (.running, "Tool running")
                    }
                }
            }
        }

        if type == "user" || role == "user" {
            return processAlive ? (.running, "Thinking") : (.idle, "Pending")
        }
        if type == "assistant" || role == "assistant" {
            if idleSeconds < 2 { return (.running, "Streaming") }
            return (.success, "Done")
        }

        return processAlive ? (.running, "Working") : (.idle, "Idle")
    }
}
