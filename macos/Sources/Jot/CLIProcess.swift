import Foundation
import Darwin

/// Bounded CLI calls; file-backed IO also handles large Markdown without pipe deadlocks.
enum CLIProcess {
    static func run(binary: String, arguments: [String], input: String? = nil,
                    timeout: TimeInterval = 15) throws -> String {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                                               attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        let inputURL = directory.appendingPathComponent("input")
        let outputURL = directory.appendingPathComponent("output")
        let errorURL = directory.appendingPathComponent("error")
        try Data((input ?? "").utf8).write(to: inputURL)
        try Data().write(to: outputURL)
        try Data().write(to: errorURL)
        let stdin = try FileHandle(forReadingFrom: inputURL)
        defer { try? stdin.close() }
        let stdout = try FileHandle(forWritingTo: outputURL)
        defer { try? stdout.close() }
        let stderr = try FileHandle(forWritingTo: errorURL)
        defer { try? stderr.close() }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = arguments
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr
        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }
        try process.run()
        if exited.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            if exited.wait(timeout: .now() + 1) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                process.waitUntilExit()
            }
            throw JotClient.Error.failed("jot timed out. Refresh to check whether the change was saved.")
        }
        if process.terminationStatus != 0 {
            let message = String(decoding: try Data(contentsOf: errorURL), as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw JotClient.Error.failed(message.isEmpty ? "jot exited with code \(process.terminationStatus)" : message)
        }
        return String(decoding: try Data(contentsOf: outputURL), as: UTF8.self)
    }
}
