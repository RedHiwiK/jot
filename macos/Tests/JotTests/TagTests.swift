import Foundation
import Testing
@testable import Jot

@MainActor
struct TagTests {
    private func requirement(_ id: Int, tags: [String]?, state: ReqState = .inbox) -> Req {
        Req(id: id, title: "Requirement \(id)", state: state, project: "Studio", tags: tags,
            path: "req.md", createdAt: "2026-09-07T00:00:00Z", updatedAt: "2026-09-07T00:00:00Z")
    }

    @Test func tagSelectionKeepsOnlyMatchingActiveRequirements() {
        let state = AppState()
        state.reqs = [requirement(1, tags: ["v1.2.0"]),
                      requirement(2, tags: ["v1.2.0", "bug"]),
                      requirement(3, tags: ["bug"]),
                      requirement(4, tags: nil),
                      // Done items must not appear in tag views, consistent with project views
                      requirement(5, tags: ["v1.2.0"], state: .done)]
        state.showTag("v1.2.0")
        #expect(state.selection == .tag("v1.2.0"))
        // Equal timestamps sort by ID descending, consistent with other board views
        #expect(state.filtered.map(\.id) == [2, 1])
    }

    @Test func listResponseDecodesTagCounts() throws {
        // `jot ls --json` returns the tag list next to reqs; the sidebar Tags group is built from it
        let json = #"{"reqs":[],"tags":[{"tag":"bug","count":2},{"tag":"v0.2","count":4}]}"#
        let resp = try JSONDecoder().decode(ListResponse.self, from: Data(json.utf8))
        #expect(resp.tags == [TagCount(tag: "bug", count: 2), TagCount(tag: "v0.2", count: 4)])
    }

    @Test func requirementsWithoutTagsDecodeAsEmpty() {
        // The CLI omits the tags field entirely for untagged requirements; decoding must not fail or crash on nil
        let json = """
        {"id":7,"title":"No tags","state":"inbox","path":"x.md",
         "created_at":"2026-09-07T00:00:00Z","updated_at":"2026-09-07T00:00:00Z"}
        """
        let req = try! JSONDecoder().decode(Req.self, from: Data(json.utf8))
        #expect(req.tagList.isEmpty)
    }

    @Test func searchMatchesTagText() {
        let state = AppState()
        state.reqs = [requirement(1, tags: ["v1.2.0"]),
                      requirement(2, tags: ["bug"])]
        state.requirementQuery = "v1.2.0"
        #expect(state.filtered.map(\.id) == [1])
    }

    /// The ⌘K palette and in-list filter are separate paths; sharing searchText keeps them from diverging.
    @Test func searchTextCoversEveryMatchableField() {
        let req = requirement(42, tags: ["v1.2.0", "bug"])
        let text = req.searchText
        for needle in ["42", "Requirement 42", "Studio", "v1.2.0", "bug", "inbox"] {
            #expect(text.localizedCaseInsensitiveContains(needle))
        }
    }
}
