import Foundation
import Testing
@testable import Jot

struct CLIProcessTests {
    @Test func largeMarkdownRoundTrip() throws {
        let body = String(repeating: "需求正文：保留所有内容\n", count: 20000)
        #expect(try CLIProcess.run(binary: "/bin/cat", arguments: [], input: body) == body)
    }

    @Test func failureIncludesStderr() {
        do {
            _ = try CLIProcess.run(binary: "/bin/sh", arguments: ["-c", "echo 'write failed' >&2; exit 7"])
            Issue.record("Expected failure")
        } catch {
            #expect(error.localizedDescription.contains("write failed"))
        }
    }

    @Test func hungCommandTimesOut() {
        let start = Date()
        do {
            _ = try CLIProcess.run(binary: "/bin/sleep", arguments: ["30"], timeout: 0.1)
            Issue.record("Expected timeout")
        } catch {
            #expect(error.localizedDescription.contains("timed out"))
            #expect(Date().timeIntervalSince(start) < 5)
        }
    }
}
