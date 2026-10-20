import SwiftUI

/// Theme runtime. Parses Palette hex values into Colors for views.
///
/// Usage: @Environment(\.theme) var th → th.ink / th.card / th.state(.ready)
struct Theme {
    let name: String
    let palette: Palette

    // Backgrounds
    let sidebar, list, canvas, card, cardHover, elevated: Color
    // Text
    let ink, ink2, ink3, ink4: Color
    // Lines and states
    let line, lineStrong, selected, hover: Color
    // States
    let danger, warn, accent: Color
    private let inbox, ready, running, review, done: Color
    private let projectColors: [String: Color]

    init(name: String, palette p: Palette) {
        self.name = name
        self.palette = p
        sidebar    = Color(hex: p.sidebar)
        list       = Color(hex: p.list)
        canvas     = Color(hex: p.canvas)
        card       = Color(hex: p.card)
        cardHover  = Color(hex: p.cardHover)
        elevated   = Color(hex: p.elevated)
        ink        = Color(hex: p.ink)
        ink2       = Color(hex: p.ink2)
        ink3       = Color(hex: p.ink3)
        ink4       = Color(hex: p.ink4)
        line       = Color(hex: p.line)
        lineStrong = Color(hex: p.lineStrong)
        selected   = Color(hex: p.selected)
        hover      = Color(hex: p.hover)
        inbox      = Color(hex: p.inbox)
        ready      = Color(hex: p.ready)
        running    = Color(hex: p.running)
        review     = Color(hex: p.review)
        done       = Color(hex: p.done)
        danger     = Color(hex: p.danger)
        warn       = Color(hex: p.warn)
        accent     = Color(hex: p.accent)
        // Color names missing from a custom theme fall back to Paper, so every name has a value
        let hexes = (Palette.paper.projectColors ?? [:]).merging(p.projectColors ?? [:]) { _, own in own }
        projectColors = hexes.mapValues { Color(hex: $0) }
    }

    /// Project color for sidebar project icons. Returns nil when the project has no color (or an unknown name); callers then draw nothing.
    func project(_ color: String?) -> Color? {
        color.flatMap { projectColors[$0] }
    }

    func state(_ s: ReqState) -> Color {
        switch s {
        case .inbox:    return inbox
                case .inProgress: return running
        case .onHold:   return review
        case .done:     return done
        case .archived: return ink4
        }
    }

    /// Regions are layered with shadows, no lines.
    /// Dark themes need heavier shadows to be visible.
    var edgeShadow: Color {
        Color.black.opacity(palette.isDark ? 0.32 : 0.07)
    }

    var edgeShadowRadius: CGFloat { palette.isDark ? 8 : 6 }

    static let `default` = Theme(name: "Paper", palette: .paper)
}

// MARK: - Typography and metrics (separate from colors; themes only control color)

enum Metric {
    // MARK: Corner radii and spacing
    static let radius: CGFloat = 8
    static let radiusSm: CGFloat = 6
    static let pad: CGFloat = 24
    static let gap: CGFloat = 10

    // MARK: Type scale
    //
    // Only four sizes, one per level, no improvising; otherwise same-level elements end up with mixed sizes.
    static let toolbarHeight: CGFloat = 48
    static let readingWidth: CGFloat = 760
    static let title = Font.system(size: 20, weight: .semibold)
    static let panelTitle = Font.system(size: 16, weight: .semibold)
    static let body  = Font.system(size: 14)
    static let meta  = Font.system(size: 12)
    static let micro = Font.system(size: 12, weight: .medium)

    // Monospaced (editor, logs)
    static let mono     = Font.system(size: 14, design: .monospaced)
    static let monoSm   = Font.system(size: 12, design: .monospaced)

    // MARK: Markdown font sizes (modeled on Typora: comfortable body, restrained headings)
    static let mdH1   = Font.system(size: 19, weight: .semibold)
    static let mdH2   = Font.system(size: 16, weight: .semibold)
    static let mdH3   = Font.system(size: 14, weight: .semibold)
    static let mdBody = Font.system(size: 15)
    static let mdCode = Font.system(size: 14, design: .monospaced)

}

// MARK: - Environment

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.default
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - Theme management

@MainActor
final class ThemeStore: ObservableObject {
    @Published private(set) var current: Theme = .default
    @Published private(set) var available: [(name: String, palette: Palette)] = []

    private let key = "jot.theme"

    init() {
        reload()
        let saved = UserDefaults.standard.string(forKey: key) ?? "Paper"
        select(saved)
    }

    /// Built-in themes + JSON themes in the user directory.
    /// Adding a theme = dropping a JSON file into ~/.jot/themes/, no code changes.
    func reload() {
        var all = Palette.builtins
        let dir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".jot/themes")
        if let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) {
            for f in files where f.pathExtension == "json" {
                if let data = try? Data(contentsOf: f),
                   let p = try? JSONDecoder().decode(Palette.self, from: data) {
                    all.append((f.deletingPathExtension().lastPathComponent, p))
                }
            }
        }
        available = all
    }

    func select(_ name: String) {
        guard let hit = available.first(where: { $0.name == name }) else { return }
        current = Theme(name: hit.name, palette: hit.palette)
        UserDefaults.standard.set(name, forKey: key)
    }

    /// Exports the current theme as a template for users to build their own
    func exportTemplate() -> URL? {
        let dir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".jot/themes")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("MyTheme.json")
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(current.palette) else { return nil }
        try? data.write(to: url)
        return url
    }
}
