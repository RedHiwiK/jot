import Foundation
import SwiftUI
import Testing
@testable import Jot

@MainActor
struct ProjectTests {
    private func decode(_ json: String) -> Project {
        try! JSONDecoder().decode(Project.self, from: Data(json.utf8))
    }

    @Test func decodesOptionalDisplayFields() {
        // Older CLIs don't emit color / repo_url; decoding must not fail because of it
        let plain = decode(#"{"name":"Studio","repo_path":"/tmp/studio","open_count":2}"#)
        #expect(plain.color == nil && plain.repositoryURL == nil)

        let full = decode(#"{"name":"Studio","repo_path":"/tmp/studio","open_count":2,"color":"blue","repo_url":"https://github.com/o/r","repo_url_inferred":true}"#)
        #expect(full.color == "blue")
        #expect(full.repositoryURL?.absoluteString == "https://github.com/o/r")
        // Inferred URLs are not echoed into the edit field
        #expect(full.configuredRepoURL == "")
    }

    @Test func linkLabelsAreShort() {
        #expect(LinkLabel.short("https://github.com/o/jot/pull/12") == "jot#12")
        #expect(LinkLabel.short("https://code.example.com/g/sub/myapp/-/merge_requests/34") == "myapp!34")
        #expect(LinkLabel.short("https://example.com/docs/spec") == "example.com/spec")
    }

    @Test func requirementsDecodeLinks() {
        let json = """
        {"id":7,"title":"Linked","state":"inbox","path":"x.md","links":["https://github.com/o/r/pull/1"],
         "created_at":"2026-09-07T00:00:00Z","updated_at":"2026-09-07T00:00:00Z"}
        """
        let req = try! JSONDecoder().decode(Req.self, from: Data(json.utf8))
        #expect(req.linkList == ["https://github.com/o/r/pull/1"])
        #expect(req.reference == "JOT-7")
    }

    @Test func everyThemeResolvesEveryProjectColor() {
        for entry in Palette.builtins {
            let theme = Theme(name: entry.name, palette: entry.palette)
            // Keep in sync with the CLI's model.ProjectColors
            for color in ["red", "orange", "yellow", "green", "teal", "blue", "purple", "gray"] {
                #expect(theme.project(color) != nil, "\(entry.name) missing \(color)")
            }
            #expect(theme.project(nil) == nil)
            #expect(theme.project("chartreuse") == nil)
        }
        // Custom theme JSON without projectColors falls back to built-in colors
        var custom = Palette.oneDark
        custom.projectColors = nil
        #expect(Theme(name: "Custom", palette: custom).project("blue") != nil)
    }

    @Test func requirementCountIncludesFinishedWork() {
        let state = AppState()
        func req(_ id: Int, _ project: String?, _ st: ReqState) -> Req {
            Req(id: id, title: "R\(id)", state: st, project: project, tags: nil,
                path: "r.md", createdAt: "2026-09-07T00:00:00Z", updatedAt: "2026-09-07T00:00:00Z")
        }
        state.reqs = [req(1, "Studio", .inbox), req(2, "Studio", .done),
                      req(3, "Studio", .archived), req(4, "Other", .inbox), req(5, nil, .inbox)]
        #expect(state.requirementCount(in: "Studio") == 3)
    }
}
