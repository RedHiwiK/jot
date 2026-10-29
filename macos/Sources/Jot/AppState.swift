import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var reqs: [Req] = []
    @Published var projects: [Project] = []
    @Published var selection: SidebarSelection = .all
    @Published var selectedReqID: Int?
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var requirementQuery = ""
    @Published var drafts: [Int: BodyDraft] = [:]
    @Published var boardScrollIDs: [ReqState: Int] = [:]
    @Published var requirementListScrollID: Int?
    @Published var requirementFilter: ReqState?
    @Published var archivedUndo: Req?
    @Published var boardOrder: [Int] = UserDefaults.standard.array(forKey: "jot.boardOrder") as? [Int] ?? []
    /// Projects collapsed in the Done / Archived views. Those lists only grow,
    /// so after grouping by project you still need to fold away finished ones, or you'd scroll forever.
    @Published var collapsedProjects: Set<String> = Set(
        UserDefaults.standard.stringArray(forKey: "jot.collapsedProjects") ?? [])

    private var refreshTask: Task<Void, Never>?
    private var refreshRevision = 0
    private var showingReadError = false

    var selectedReq: Req? {
        guard let id = selectedReqID else { return nil }
        return reqs.first { $0.id == id }
    }

    var filtered: [Req] {
        let ranks = Dictionary(boardOrder.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: min)
        let formatter = ISO8601DateFormatter()
        let dates = Dictionary(reqs.map { ($0.id, formatter.date(from: $0.updatedAt) ?? .distantPast) }, uniquingKeysWith: { first, _ in first })
        let base: [Req]
        switch selection {
        // "All" means work in flight, excluding done and archived:
        // those each have their own entry, and mixing them in only bloats counts and the board
        case .all:              base = reqs.filter { ReqState.active.contains($0.state) }
        case .state(let s):     base = reqs.filter { $0.state == s }
        case .project(let p):   base = reqs.filter {
            $0.project == p && ReqState.active.contains($0.state)
        }
        case .tag(let t):       base = reqs.filter {
            $0.tagList.contains(t) && ReqState.active.contains($0.state)
        }
        }
        let query = requirementQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return base.filter {
            let matchesState = requirementFilter == nil || $0.state == requirementFilter || isStateSelection
            return matchesState && (query.isEmpty || $0.searchText.localizedCaseInsensitiveContains(query))
        }.sorted { a, b in
            if a.state != b.state {
                return stateOrder(a.state) < stateOrder(b.state)
            }
            let left = ranks[a.id]
            let right = ranks[b.id]
            if left != nil || right != nil { return (left ?? -1) < (right ?? -1) }
            let leftDate = dates[a.id] ?? .distantPast
            let rightDate = dates[b.id] ?? .distantPast
            return leftDate == rightDate ? a.id > b.id : leftDate > rightDate
        }
    }

    /// Done / Archived are history that only grows; flattened across projects nothing can be found,
    /// so these two views are grouped by project. Active states are not grouped; they are meant to be seen mixed.
    var groupsByProject: Bool {
        if case .state(let s) = selection { return s == .done || s == .archived }
        return false
    }

    /// Grouped sections. Order follows the sidebar's project order, with project-less last.
    var projectSections: [(project: String, reqs: [Req])] {
        guard groupsByProject else { return [] }
        let items = filtered
        var order: [String] = projects.map(\.name)
        order.append("")
        var buckets: [String: [Req]] = [:]
        for req in items { buckets[req.project ?? "", default: []].append(req) }
        return order.compactMap { name in
            guard let group = buckets[name], !group.isEmpty else { return nil }
            return (name, group)
        }
    }

    func isCollapsed(_ project: String) -> Bool { collapsedProjects.contains(project) }

    func toggleCollapsed(_ project: String) {
        if collapsedProjects.contains(project) { collapsedProjects.remove(project) }
        else { collapsedProjects.insert(project) }
        UserDefaults.standard.set(Array(collapsedProjects), forKey: "jot.collapsedProjects")
    }

    /// Sequence walked by the up/down arrow keys. In grouped views it must follow visible order,
    /// otherwise the cursor jumps between collapsed sections.
    var navigableReqs: [Req] {
        guard groupsByProject else { return filtered }
        return projectSections.flatMap { isCollapsed($0.project) ? [] : $0.reqs }
    }

    private func stateOrder(_ s: ReqState) -> Int {
        ReqState.allCases.firstIndex(of: s) ?? 99
    }

    private var isStateSelection: Bool {
        if case .state = selection { return true }
        return false
    }

    func count(for state: ReqState) -> Int {
        reqs.filter { $0.state == state }.count
    }

    // MARK: - Data

    func refresh() async {
        refreshRevision += 1
        let revision = refreshRevision
        do {
            // Always fetch done / archived too: the sidebar rows show their counts,
            // and opening them must show content. Hiding them on the board is the render layer's job,
            // not something to achieve by fetching less
            let resp = try await JotClient.shared.list(includeDone: true)
            guard revision == refreshRevision else { return }
            let nextReqs = resp.reqs ?? []
            let nextProjects = orderedProjects(resp.projects ?? [])
            if reqs != nextReqs { reqs = nextReqs }
            if projects != nextProjects { projects = nextProjects }
            if showingReadError { errorMessage = nil; showingReadError = false }
            // Clear the selection if the selected item is gone
            if let id = selectedReqID, !reqs.contains(where: { $0.id == id }) {
                selectedReqID = nil
            }
        } catch {
            guard revision == refreshRevision else { return }
            if errorMessage == nil || showingReadError {
                errorMessage = error.localizedDescription
                showingReadError = true
            }
        }
    }

    /// Periodically reloads local requirements so CLI changes show up on the board.
    func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { return }
                await self.refresh()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Actions

    func perform(_ action: @escaping () async throws -> Void) {
        guard !isLoading else { return }
        isLoading = true
        showingReadError = false
        errorMessage = nil
        Task {
            defer { isLoading = false }
            do {
                try await action()
                await refresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func move(_ req: Req, to state: ReqState) {
        perform { _ = try await JotClient.shared.move(req.id, to: state) }
    }

    func place(_ req: Req, in destination: ReqState, before nextID: Int?) {
        guard !isLoading else { return }
        if req.state == destination {
            applyBoardOrder(req.id, destination: destination, before: nextID)
            return
        }
        let previousOrder = boardOrder
        if let index = reqs.firstIndex(where: { $0.id == req.id }) { reqs[index].state = destination }
        applyBoardOrder(req.id, destination: destination, before: nextID, persist: false)
        perform {
            do {
                _ = try await JotClient.shared.move(req.id, to: destination)
                UserDefaults.standard.set(self.boardOrder, forKey: "jot.boardOrder")
            } catch {
                self.boardOrder = previousOrder
                if let index = self.reqs.firstIndex(where: { $0.id == req.id }) { self.reqs[index].state = req.state }
                throw error
            }
        }
    }

    func applyBoardOrder(_ id: Int, destination: ReqState, before nextID: Int?, persist: Bool = true) {
        var order = filtered.map(\.id).filter { $0 != id }
        if let nextID, let index = order.firstIndex(of: nextID) {
            order.insert(id, at: index)
        } else {
            let last = order.lastIndex { candidate in reqs.contains { $0.id == candidate && $0.state == destination } }
            order.insert(id, at: last.map { $0 + 1 } ?? order.count)
        }
        // Preserve ordering of requirements outside the current project/filter.
        boardOrder = order + boardOrder.filter { !order.contains($0) }
        if persist { UserDefaults.standard.set(boardOrder, forKey: "jot.boardOrder") }
    }

    func update(_ req: Req, project: String? = nil, title: String? = nil) {
        perform { _ = try await JotClient.shared.update(req.id, project: project, title: title) }
    }

    func archive(_ req: Req) {
        perform {
            try await JotClient.shared.archive(req.id)
            self.archivedUndo = req
            if self.selectedReqID == req.id { self.selectedReqID = nil }
        }
    }

    /// The CLI only purges archived requirements, so anything still active is archived first
    func delete(_ req: Req) {
        perform {
            if req.state != .archived { try await JotClient.shared.archive(req.id) }
            try await JotClient.shared.purge(req.id)
            if self.archivedUndo?.id == req.id { self.archivedUndo = nil }
            if self.selectedReqID == req.id { self.selectedReqID = nil }
        }
    }

    func undoArchive() {
        guard let req = archivedUndo, !isLoading else { return }
        perform {
            _ = try await JotClient.shared.move(req.id, to: req.state)
            self.archivedUndo = nil
        }
    }

    func showBoard() {
        requirementFilter = nil
        guard selection != .all || selectedReqID != nil else { return }
        selectedReqID = nil
        selection = .all
    }

    func showState(_ state: ReqState) {
        requirementFilter = nil
        let next = SidebarSelection.state(state)
        guard selection != next || selectedReqID != nil else { return }
        selectedReqID = nil
        selection = next
    }

    func showTag(_ tag: String) {
        requirementFilter = nil
        let next = SidebarSelection.tag(tag)
        guard selection != next || selectedReqID != nil else { return }
        selectedReqID = nil
        selection = next
    }

    /// Tags are free text; the GUI only does basic sanity checks. Normalization is the CLI's call,
    /// and after refresh the value shown is whatever the CLI settled on.
    func addTag(_ req: Req, _ raw: String) {
        let tag = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }
        perform { try await JotClient.shared.addTags(req.id, [tag]) }
    }

    /// Linking is CLI-only (an agent runs jot link after opening a PR); the GUI only displays and unlinks
    func unlink(_ req: Req, _ url: String) {
        perform { try await JotClient.shared.unlink(req.id, url) }
    }

    func removeTag(_ req: Req, _ tag: String) {
        perform { try await JotClient.shared.removeTag(req.id, tag) }
    }

    func showProject(_ project: String) {
        requirementFilter = nil
        let next = SidebarSelection.project(project)
        guard selection != next || selectedReqID != nil else { return }
        selectedReqID = nil
        selection = next
    }

    func orderedProjects(_ values: [Project]) -> [Project] {
        let ids = UserDefaults.standard.stringArray(forKey: "jot.projectOrder") ?? []
        return values.sorted {
            let a = ids.firstIndex(of: $0.id) ?? Int.max
            let b = ids.firstIndex(of: $1.id) ?? Int.max
            return a == b ? $0.name < $1.name : a < b
        }
    }

    func moveProjects(from source: IndexSet, to destination: Int) {
        projects.move(fromOffsets: source, toOffset: destination)
        UserDefaults.standard.set(projects.map(\.id), forKey: "jot.projectOrder")
    }

    func project(named name: String?) -> Project? {
        guard let name else { return nil }
        return projects.first { $0.name == name }
    }

    /// How many requirements deleting the project will leave project-less, including done and archived; the user must be told before deleting
    func requirementCount(in project: String) -> Int {
        reqs.filter { $0.project == project }.count
    }

    func renameProject(_ old: String, to raw: String) {
        let new = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !new.isEmpty, new != old else { return }
        perform {
            try await JotClient.shared.renameProject(old, to: new)
            // Sidebar order, collapse state and current selection are keyed by project name, so they must migrate on rename
            let order = UserDefaults.standard.stringArray(forKey: "jot.projectOrder") ?? []
            UserDefaults.standard.set(order.map { $0 == old ? new : $0 }, forKey: "jot.projectOrder")
            if self.collapsedProjects.remove(old) != nil {
                self.collapsedProjects.insert(new)
                UserDefaults.standard.set(Array(self.collapsedProjects), forKey: "jot.collapsedProjects")
            }
            if self.selection == .project(old) { self.selection = .project(new) }
        }
    }

    func removeProject(_ name: String) {
        perform {
            try await JotClient.shared.removeProject(name)
            if self.selection == .project(name) { self.selection = .all }
        }
    }

    /// Empty string means fall back to inferring from git remote
    func setProjectRepoURL(_ name: String, _ raw: String) {
        let url = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        perform { try await JotClient.shared.setProjectRepoURL(name, url) }
    }

    func navigateBack() {
        if selectedReqID != nil {
            selectedReqID = nil
        } else if selection != .all {
            selection = .all
        }
    }

    func refreshCurrentView() {
        Task { await refresh() }
    }

    func saveBody(_ req: Req, body: String) {
        perform { try await JotClient.shared.setBody(req.id, body: body) }
    }
}
