import Foundation

/// The GUI reads and writes data through the jot CLI and never touches SQLite directly.
///
/// Same reason as the skill: a single source of business logic. State transition rules, project inference
/// and frontmatter sync all live in Go; reimplementing them in the GUI would inevitably drift.
actor JotClient {
    static let shared = JotClient()

    enum Error: LocalizedError {
        case notFound
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .notFound:        return "jot not found (expected at ~/.local/bin/jot)"
            case .failed(let msg): return msg
            }
        }
    }

    private lazy var binary: String? = {
        let candidates = [
            Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/jot").path,
            "\(NSHomeDirectory())/.local/bin/jot",
            "/usr/local/bin/jot",
            "/opt/homebrew/bin/jot",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }()

    @discardableResult
    private func run(_ args: [String], stdin: String? = nil) throws -> String {
        guard let bin = binary else { throw Error.notFound }

        return try CLIProcess.run(binary: bin, arguments: args, input: stdin)
    }

    private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        guard let data = json.data(using: .utf8) else {
            throw Error.failed("Invalid output encoding")
        }
        return try JSONDecoder().decode(type, from: data)
    }

    // MARK: - Read

    func list(includeDone: Bool = false) throws -> ListResponse {
        var args = ["ls", "--json"]
        if includeDone { args.append("--all") }
        return try decode(ListResponse.self, from: run(args))
    }

    func show(_ id: Int) throws -> Req {
        try decode(Req.self, from: run(["show", "\(id)", "--json"]))
    }

    func body(_ id: Int) throws -> String {
        try run(["body", "\(id)"])
    }

    // MARK: - Write

    func setBody(_ id: Int, body: String) throws {
        try run(["body", "set", "\(id)"], stdin: body)
    }

    func update(_ id: Int, project: String? = nil, title: String? = nil) throws -> Req {
        var args = ["set", "\(id)", "--json"]
        if let project { args += ["--project", project] }
        if let title { args += ["--title", title] }
        return try decode(Req.self, from: run(args))
    }

    /// Adds tags incrementally. Full replacement is the CLI's `set --tags`; the GUI has no entry point that replaces the whole set.
    ///
    /// Tags always go through --tag rather than positional args: a purely numeric positional arg is taken as a requirement ID,
    /// and the GUI already knows the ID, so there's no reason to make the CLI guess.
    func addTags(_ id: Int, _ tags: [String]) throws {
        try run(["tag", "\(id)"] + tags.flatMap { ["--tag", $0] })
    }

    func removeTag(_ id: Int, _ tag: String) throws {
        try run(["untag", "\(id)", "--tag", tag])
    }

    func unlink(_ id: Int, _ url: String) throws {
        try run(["unlink", "\(id)", url])
    }

    func move(_ id: Int, to state: ReqState) throws -> Req {
        try decode(Req.self, from: run(["mv", "\(id)", state.rawValue, "--json"]))
    }

    func archive(_ id: Int) throws {
        try run(["rm", "\(id)"])
    }

    // MARK: - Projects

    func renameProject(_ old: String, to new: String) throws {
        try run(["project", "rename", old, new, "--json"])
    }

    /// Removes only the category: linked requirements become project-less, state and body are kept (the CLI rolls back failed file syncs)
    func removeProject(_ name: String) throws {
        try run(["project", "rm", name, "--json"])
    }

    /// Empty string means fall back to inferring from git remote. Project color is CLI-only (jot project set --color); the GUI has no entry for it
    func setProjectRepoURL(_ name: String, _ url: String) throws {
        try run(["project", "set", name, "--repo-url", url, "--json"])
    }
}
