import Foundation
import GlossCore

/// Runs Claude Code for Fix My English and for looking up new words.
///
/// Starting `claude` costs about 5 s before the model even sees the question (measured: 5.3 s for "ok"),
/// so one is started ahead of time and waits (`WarmClaude`): asking it takes about 2 s. Each question
/// gets a fresh process (no history carries over); the next one is started in the background.
/// It runs without the person's hooks, MCP servers or tools (`--setting-sources project`,
/// `--strict-mcp-config`, `--tools ""`), so a fix never sets off their own automations.
enum ClaudeRunner {
    enum Failure: Error, LocalizedError {
        case notFound
        case timedOut
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "The `claude` command was not found. Install Claude Code (https://claude.com/claude-code), then check that `command -v claude` works in Terminal."
            case .timedOut:
                return "Claude did not answer within \(Int(FixPrompt.timeout)) seconds. Try again, or try a shorter selection."
            case .failed(let why):
                return "Claude could not answer.\n\(why.prefix(600))"
            }
        }
    }

    /// Model for Fix My English and word look-ups (Settings). "haiku" is fastest.
    nonisolated(unsafe) static var model = "haiku"
    /// Keep one Claude started and waiting (Settings).
    nonisolated(unsafe) static var keepWarm = true
    /// A spare older than this is replaced (seconds). See MECHANICS.md.
    static let spareMaxAge: TimeInterval = 60 * 60

    /// For the self-test: a stand-in `claude` (path and PATH) instead of the real one.
    nonisolated(unsafe) static var override: (path: String, pathEnv: String)?

    private static let lock = NSLock()
    nonisolated(unsafe) private static var located: (path: String, pathEnv: String)?
    nonisolated(unsafe) private static var spare: WarmClaude?

    // MARK: Asking

    static func fix(_ text: String) async throws -> FixResult {
        try FixPrompt.parse(try await ask(FixPrompt.build(for: text)))
    }

    static func lookUp(_ word: String) async throws -> WordLookup {
        try WordLookup.parse(try await ask(WordLookup.prompt(for: word)))
    }

    /// Sends one question and returns Claude's text answer.
    static func ask(_ prompt: String) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let claude: WarmClaude
            if let s = takeSpare() { claude = s } else { claude = try start() }
            defer { claude.stop(); prewarm() }
            return try claude.ask(prompt, timeout: FixPrompt.timeout)
        }.value
    }

    /// Starts a waiting Claude when there is none (or it is old, or for another model).
    static func prewarm() {
        guard keepWarm else { stopSpare(); return }
        Task.detached(priority: .utility) { refreshSpare() }
    }

    private static func refreshSpare() {
        lock.lock()
        let fresh = spare.map { $0.isAlive && $0.model == model && Date().timeIntervalSince($0.started) < spareMaxAge } ?? false
        lock.unlock()
        guard !fresh, let next = try? start() else { return }
        lock.lock()
        let old = spare
        spare = next
        lock.unlock()
        old?.stop()
    }

    static func stopSpare() {
        lock.lock()
        let old = spare
        spare = nil
        lock.unlock()
        old?.stop()
    }

    /// Whether a started Claude is waiting (Settings shows it).
    static var isReady: Bool {
        lock.lock(); defer { lock.unlock() }
        return spare?.isAlive ?? false
    }

    private static func takeSpare() -> WarmClaude? {
        lock.lock()
        defer { lock.unlock() }
        guard let s = spare else { return nil }
        spare = nil
        guard s.isAlive, s.model == model, Date().timeIntervalSince(s.started) < spareMaxAge else { s.stop(); return nil }
        return s
    }

    private static func start() throws -> WarmClaude {
        let c = try locate()
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = c.pathEnv
        return try WarmClaude(executable: URL(fileURLWithPath: c.path), model: model, env: env)
    }

    /// Finds `claude` with a login shell, the same way Terminal would.
    private static func locate() throws -> (path: String, pathEnv: String) {
        if let override { return override }
        lock.lock()
        if let located, FileManager.default.isExecutableFile(atPath: located.path) { lock.unlock(); return located }
        lock.unlock()
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-lc", "command -v claude; echo \"$PATH\""]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        try p.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        let lines = String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init)
        guard lines.count >= 2, lines[0].hasPrefix("/"), FileManager.default.isExecutableFile(atPath: lines[0]) else {
            throw Failure.notFound
        }
        let found = (path: lines[0], pathEnv: lines[lines.count - 1])
        lock.lock(); located = found; lock.unlock()
        return found
    }
}

/// One `claude -p` in stream-json mode, started and waiting for a single question.
final class WarmClaude: @unchecked Sendable {
    let model: String
    let started = Date()
    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private let errors = Pipe()
    private let lock = NSLock()
    private var buffer = Data()
    private var resultLine: [String: Any]?
    private var errText = ""
    private let done = DispatchSemaphore(value: 0)

    static func arguments(model: String) -> [String] {
        ["-p", "--input-format", "stream-json", "--output-format", "stream-json", "--verbose",
         "--setting-sources", "project", "--strict-mcp-config", "--tools", "",
         "--effort", "low", "--no-session-persistence", "--model", model]
    }

    init(executable: URL, model: String, env: [String: String]) throws {
        self.model = model
        process.executableURL = executable
        process.arguments = Self.arguments(model: model)
        process.environment = env
        process.currentDirectoryURL = FileManager.default.temporaryDirectory
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errors
        output.fileHandleForReading.readabilityHandler = { [weak self] h in self?.received(h.availableData) }
        errors.fileHandleForReading.readabilityHandler = { [weak self] h in
            let d = h.availableData
            guard let self, !d.isEmpty else { return }
            self.lock.lock(); self.errText += String(decoding: d, as: UTF8.self); self.lock.unlock()
        }
        process.terminationHandler = { [weak self] _ in self?.done.signal() }
        try process.run()
    }

    var isAlive: Bool { process.isRunning }

    /// Sends the question and waits for Claude's result.
    func ask(_ prompt: String, timeout: TimeInterval) throws -> String {
        let message: [String: Any] = ["type": "user", "message": ["role": "user", "content": prompt]]
        var line = try JSONSerialization.data(withJSONObject: message)
        line.append(0x0A)
        do {
            try input.fileHandleForWriting.write(contentsOf: line)
        } catch {
            throw ClaudeRunner.Failure.failed(stderrText().isEmpty ? "Claude stopped before the question." : stderrText())
        }
        guard done.wait(timeout: .now() + timeout) == .success else { throw ClaudeRunner.Failure.timedOut }
        lock.lock()
        let r = resultLine
        lock.unlock()
        guard let r else {
            throw ClaudeRunner.Failure.failed(stderrText().isEmpty ? "Claude ended without an answer." : stderrText())
        }
        let text = r["result"] as? String ?? ""
        if (r["is_error"] as? Bool) == true || (r["subtype"] as? String).map({ $0 != "success" }) == true {
            throw ClaudeRunner.Failure.failed(text.isEmpty ? (r["subtype"] as? String ?? "error") : text)
        }
        return text
    }

    func stop() {
        output.fileHandleForReading.readabilityHandler = nil
        errors.fileHandleForReading.readabilityHandler = nil
        try? input.fileHandleForWriting.close()
        if process.isRunning { process.terminate() }
    }

    private func stderrText() -> String {
        lock.lock(); defer { lock.unlock() }
        return errText
    }

    /// Collects stdout lines; the `{"type":"result", ...}` line ends the question.
    private func received(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock()
        buffer.append(data)
        var found: [String: Any]?
        while let nl = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer[buffer.startIndex..<nl]
            buffer.removeSubrange(buffer.startIndex...nl)
            if let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
               obj["type"] as? String == "result" {
                found = obj
            }
        }
        if let found, resultLine == nil { resultLine = found }
        lock.unlock()
        if found != nil { done.signal() }
    }
}

/// Starts the waiting Claude a moment after launch (and after a setting changes), off the main thread.
enum ClaudePrewarm {
    static func schedule() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { ClaudeRunner.prewarm() }
    }
}
