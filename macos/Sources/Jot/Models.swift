import Foundation

enum ReqState: String, Codable, CaseIterable, Identifiable {
    case inbox, inProgress = "in_progress", onHold = "on_hold", done, archived

    var id: String { rawValue }

    @MainActor
    var label: String {
        switch self {
        case .inbox:    return L[.stInbox]
        case .inProgress: return L[.stInProgress]
        case .onHold:   return L[.stReview]
        case .done:     return L[.stDone]
        case .archived: return L[.stArchived]
        }
    }

    /// Each state answers "whose court is the ball in right now"
    @MainActor
    var hint: String {
        switch self {
        case .inbox:    return L[.hintInbox]
        case .inProgress: return L[.hintInProgress]
        case .onHold:   return L[.hintReview]
        case .done:     return L[.hintDone]
        case .archived: return L[.hintArchived]
        }
    }

    var symbol: String {
        switch self {
        case .inbox:    return "tray"
        case .inProgress: return "arrow.trianglehead.2.clockwise.rotate.90"
        case .onHold:   return "pause.circle"
        case .done:     return "checkmark.circle"
        case .archived: return "archivebox"
        }
    }

    /// States shown on the board (done/archived collapsed by default)
    static var active: [ReqState] { [.inbox, .inProgress, .onHold] }
}

struct Req: Codable, Identifiable, Hashable {
    let id: Int
    var title: String
    var state: ReqState
    var project: String?
    var tags: [String]?
    var links: [String]?
    var path: String
    var note: String?
    var originCwd: String?
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, state, project, tags, links, path, note
        case originCwd = "origin_cwd"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    @MainActor var projectName: String { project ?? L[.unassigned] }

    var tagList: [String] { tags ?? [] }

    var linkList: [String] { links ?? [] }

    /// Text used for search matching. Both searches (⌘K palette and in-list filter) share it,
    /// otherwise adding a field means one of them inevitably gets missed.
    @MainActor
    var searchText: String {
        "\(id) \(title) \(project ?? "") \(state.label) \(state.rawValue) \(tagList.joined(separator: " ")) \(note ?? "")"
    }

    /// ID for referencing a requirement in PRs/MRs and commits. Not #42: GitHub/GitLab auto-link that to
    /// issue/PR 42 of the current repo. Same approach as Linear's ENG-123.
    static func reference(_ id: Int) -> String { "JOT-\(id)" }

    var reference: String { Req.reference(id) }

    var updatedDate: Date {
        ISO8601DateFormatter().date(from: updatedAt) ?? .distantPast
    }
}

struct Project: Codable, Identifiable, Hashable {
    var name: String
    var repoPath: String
    var openCount: Int
    var color: String?
    /// Effective repo web URL: manual config wins, otherwise the CLI infers it from git remote
    var repoURL: String?
    var repoURLInferred: Bool?

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, color
        case repoPath = "repo_path"
        case openCount = "open_count"
        case repoURL = "repo_url"
        case repoURLInferred = "repo_url_inferred"
    }

    /// Manually configured URL only. Inferred ones don't count: echoing them in the edit field would suggest one was set.
    var configuredRepoURL: String { repoURLInferred == true ? "" : (repoURL ?? "") }

    var repositoryURL: URL? { repoURL.flatMap(URL.init(string:)) }
}

/// Short name for a linked URL, shown on the detail chip. The full URL is too long, so keep only repo name and number:
///   github.com/o/jot/pull/12                → jot#12
///   gitlab.example.com/g/myapp/-/merge_requests/34 → myapp!34
/// Unrecognized links fall back to "host/last path segment".
enum LinkLabel {
    static func short(_ raw: String) -> String {
        guard let url = URL(string: raw), let host = url.host else { return raw }
        let parts = url.pathComponents.filter { $0 != "/" && $0 != "-" }
        if parts.count >= 2, let number = Int(parts[parts.count - 1]) {
            let kind = parts[parts.count - 2]
            let repo = parts.count >= 3 ? parts[parts.count - 3] : host
            if kind == "pull" || kind == "pulls" { return "\(repo)#\(number)" }
            if kind == "merge_requests" { return "\(repo)!\(number)" }
        }
        return parts.last.map { "\(host)/\($0)" } ?? host
    }
}

/// Tags have no registry: a tag exists while some requirement references it and disappears with the last reference.
/// So this is a live tally, not a list to maintain.
struct TagCount: Codable, Identifiable, Hashable {
    var tag: String
    var count: Int

    var id: String { tag }
}

struct ListResponse: Codable {
    var reqs: [Req]?
    var projects: [Project]?
    var tags: [TagCount]?
    var detectedProject: String?
    var cwd: String?

    enum CodingKeys: String, CodingKey {
        case reqs, projects, tags, cwd
        case detectedProject = "detected_project"
    }
}

struct BodyDraft {
    var text: String
    var original: String
}

/// Sidebar filter dimension
enum SidebarSelection: Hashable {
    case all
    case state(ReqState)
    case project(String)
    case tag(String)
}
