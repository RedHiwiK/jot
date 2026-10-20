import Testing
@testable import Jot

@MainActor
struct NavigationTests {
    @Test func manualOrderSupportsMiddleAndEndAndIgnoresUpdatedDates() {
        let state = AppState()
        state.boardOrder = [1, 2, 3, 4]
        state.reqs = (1...4).map { requirement($0, project: "Studio", state: .inbox) }
        state.applyBoardOrder(4, destination: .inbox, before: 2, persist: false)
        #expect(state.filtered.map(\.id) == [1, 4, 2, 3])
        state.applyBoardOrder(1, destination: .inbox, before: nil, persist: false)
        #expect(state.filtered.map(\.id) == [4, 2, 3, 1])
        state.reqs[2].updatedAt = "2099-01-01T00:00:00Z"
        #expect(state.filtered.map(\.id) == [4, 2, 3, 1])
    }
    private func requirement(_ id: Int, project: String, state: ReqState) -> Req {
        Req(id: id, title: "Requirement \(id)", state: state, project: project,
            path: "req.md", createdAt: "2026-09-07T00:00:00Z", updatedAt: "2026-09-07T00:00:00Z")
    }

    @Test func returningFromDetailsKeepsProjectAndFilters() {
        let state = AppState()
        state.reqs = [requirement(1, project: "Studio", state: .inbox),
                      requirement(2, project: "Other", state: .inbox),
                      requirement(3, project: "Studio", state: .onHold)]
        state.selection = .project("Studio")
        state.requirementFilter = .inbox
        state.requirementQuery = "Requirement"
        state.requirementListScrollID = 1
        state.selectedReqID = 1
        state.navigateBack()
        #expect(state.selection == .project("Studio"))
        #expect(state.selectedReqID == nil)
        #expect(state.filtered.map(\.id) == [1])
        #expect(state.requirementListScrollID == 1)
        #expect(state.requirementQuery == "Requirement")
    }

    @Test func globalBoardClearsWorkflowFilterButKeepsSearch() {
        let state = AppState()
        state.requirementFilter = .onHold
        state.requirementQuery = "date"
        state.showBoard()
        #expect(state.requirementFilter == nil)
        #expect(state.requirementQuery == "date")
    }

    @Test func historyIgnoresActiveWorkflowFilter() {
        let state = AppState()
        state.reqs = [requirement(1, project: "Studio", state: .archived),
                      requirement(2, project: "Studio", state: .inbox)]
        state.requirementFilter = .inbox
        state.selection = .state(.archived)
        #expect(state.filtered.map(\.id) == [1])
    }
}
