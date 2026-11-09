import Foundation
import GlossCore

/// Runs `claude -p` with the fix-my-English prompt.
enum ClaudeRunner {
    enum Failure: Error, LocalizedError {
        case notFound
        case timedOut
        case failed(Int32, String)

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "The `claude` command was not found. Install Claude Code (https://claude.com/claude-code), then check that `command -v claude` works in Terminal."
            case .timedOut:
                return "Claude did not answer within \(Int(FixPrompt.timeout)) seconds. Try again, or try a shorter selection."
            case .failed(let code, let err):
                return "claude exited with code \(code).\n\(err.prefix(600))"
            }
        }
    }

    private struct Located { let path: String; let pathEnv: String }
    private static var cached: Located?

    /// Finds `claude` with a login shell, the same way Terminal would.
    private static func locate() throws -> Located {
        if let cached, FileManager.default.isExecutableFile(atPath: cached.path) { return cached }
        let out = try run(URL(fileURLWithPath: "/bin/zsh"), ["-lc", "command -v claude; echo \"$PATH\""],
                          env: nil, timeout: 10).stdout
        let lines = out.split(separator: "\n").map(String.init)
        guard lines.count >= 2, lines[0].hasPrefix("/"), FileManager.default.isExecutableFile(atPath: lines[0]) else {
            throw Failure.notFound
        }
        let found = Located(path: lines[0], pathEnv: lines[lines.count - 1])
        cached = found
        return found
    }

    static func fix(_ text: String) async throws -> FixResult {
        try await Task.detached(priority: .userInitiated) {
            let claude = try locate()
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = claude.pathEnv
            let r = try run(URL(fileURLWithPath: claude.path),
                            ["-p", FixPrompt.build(for: text), "--output-format", "text"],
                            env: env, timeout: FixPrompt.timeout)
            guard r.status == 0 else { throw Failure.failed(r.status, r.stderr.isEmpty ? r.stdout : r.stderr) }
            return try FixPrompt.parse(r.stdout)
        }.value
    }

    private struct Output { var status: Int32; var stdout: String; var stderr: String }

    /// Runs a program and kills it after `timeout` seconds.
    private static func run(_ exe: URL, _ args: [String], env: [String: String]?, timeout: TimeInterval) throws -> Output {
        let p = Process()
        p.executableURL = exe
        p.arguments = args
        if let env { p.environment = env }
        p.currentDirectoryURL = FileManager.default.temporaryDirectory
        let outPipe = Pipe(), errPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = errPipe
        p.standardInput = FileHandle.nullDevice

        var outData = Data(), errData = Data()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async { outData = outPipe.fileHandleForReading.readDataToEndOfFile(); group.leave() }
        group.enter()
        DispatchQueue.global().async { errData = errPipe.fileHandleForReading.readDataToEndOfFile(); group.leave() }

        try p.run()
        let done = DispatchSemaphore(value: 0)
        p.terminationHandler = { _ in done.signal() }
        if done.wait(timeout: .now() + timeout) == .timedOut {
            p.terminate()
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) { if p.isRunning { kill(p.processIdentifier, SIGKILL) } }
            throw Failure.timedOut
        }
        group.wait()
        return Output(status: p.terminationStatus,
                      stdout: String(decoding: outData, as: UTF8.self),
                      stderr: String(decoding: errData, as: UTF8.self))
    }
}
