import Foundation
import Testing
@testable import Jot

@MainActor
struct DoneGroupingTests {
    private func requirement(_ id: Int, project: String?, state: ReqState) -> Req {
        Req(id: id, title: "Requirement \(id)", state: state, project: project, tags: nil,
            path: "req.md", createdAt: "2026-09-07T00:00:00Z", updatedAt: "2026-09-07T00:00:00Z")
    }

    private func populated() -> AppState {
        let state = AppState()
        state.projects = [Project(name: "CutePet", repoPath: "/a", openCount: 0),
                          Project(name: "jot", repoPath: "/b", openCount: 0)]
        state.reqs = [requirement(1, project: "CutePet", state: .done),
                      requirement(2, project: "jot", state: .done),
                      requirement(3, project: "CutePet", state: .done),
                      requirement(4, project: nil, state: .done),
                      requirement(5, project: "jot", state: .inbox)]
        return state
    }

    @Test func doneGroupsByProjectAndActiveStatesDoNot() {
        let state = populated()
        state.showState(.done)
        #expect(state.groupsByProject)
        // Order follows the sidebar's project order, with project-less last
        #expect(state.projectSections.map(\.project) == ["CutePet", "jot", ""])
        #expect(state.projectSections.map(\.reqs.count) == [2, 1, 1])

        state.showState(.inbox)
        #expect(!state.groupsByProject)
        #expect(state.projectSections.isEmpty)
    }

    @Test func archivedGroupsToo() {
        let state = populated()
        state.reqs.append(requirement(6, project: "jot", state: .archived))
        state.showState(.archived)
        #expect(state.groupsByProject)
        #expect(state.projectSections.map(\.project) == ["jot"])
    }

    @Test func collapsingRemovesRowsFromKeyboardNavigation() {
        let state = populated()
        state.showState(.done)
        #expect(state.navigableReqs.count == 4)

        state.toggleCollapsed("CutePet")
        // Collapsed sections are skipped by up/down navigation, otherwise the cursor lands on hidden rows
        #expect(state.isCollapsed("CutePet"))
        #expect(state.navigableReqs.map(\.id) == [2, 4])
        // The section itself still exists, just not expanded
        #expect(state.projectSections.map(\.project) == ["CutePet", "jot", ""])

        state.toggleCollapsed("CutePet")
        #expect(state.navigableReqs.count == 4)
    }

    @Test func navigationMatchesFilteredWhenNotGrouped() {
        let state = populated()
        state.showState(.inbox)
        #expect(state.navigableReqs.map(\.id) == state.filtered.map(\.id))
    }
}
