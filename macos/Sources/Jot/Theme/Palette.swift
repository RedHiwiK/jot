import SwiftUI

/// A complete color palette.
///
/// All colors are hex and can be loaded from JSON, like Typora's theme mechanism:
/// adding a theme = adding a file, no code changes.
struct Palette: Codable, Equatable {
    // Backgrounds of the three panes, outermost to innermost
    var sidebar: String
    var list: String
    var canvas: String        // Content area (overview / detail)
    var card: String          // Cards, text field backgrounds
    var cardHover: String
    var elevated: String      // Elevated panels (popovers)

    // Four gray levels for text
    var ink: String
    var ink2: String
    var ink3: String
    var ink4: String

    // Lines and selection
    var line: String
    var lineStrong: String
    var selected: String
    var hover: String

    // State colors
    var inbox: String
    var ready: String
    var running: String
    var review: String
    var done: String

    var danger: String
    var warn: String
    var accent: String

    var isDark: Bool

    /// Project colors (sidebar project icons), keyed by CLI color name (jot project set --color). Optional: older custom theme JSON lacks this section,
    /// and missing color names fall back to the built-in theme in Theme.
    var projectColors: [String: String]? = nil
}

extension Palette {
    /// Newsprint: warm white background, ink-black text. The default theme, modeled on Otty's Newsprint.
    static let newsprint = Palette(
        sidebar: "E6E2DA", list: "F2EFEA", canvas: "F9F7F4",
        card: "FFFFFF", cardHover: "FFFFFF", elevated: "FFFFFF",
        ink: "1F1D1A", ink2: "5C5852", ink3: "8B8680", ink4: "B5B0A8",
        line: "E2DED6", lineStrong: "D0CBC1",
        selected: "E8E4DB", hover: "F0EDE7",
        inbox: "8B8680", ready: "3D6B8F", running: "3E7A50",
        review: "B07D28", done: "9B9690",
        danger: "B04A42", warn: "C08430", accent: "3D6B8F",
        isDark: false,
        projectColors: ["red": "B4574F", "orange": "C27A3A", "yellow": "B8962E", "green": "4F8A5B",
                        "teal": "3E8A87", "blue": "4A74A8", "purple": "7E62A8", "gray": "8B8680"]
    )

    /// Paper: a cooler neutral off-white
    static let paper = Palette(
        sidebar: "E8E8EA", list: "F3F3F4", canvas: "FFFFFF",
        card: "F7F7F8", cardHover: "F1F1F3", elevated: "FFFFFF",
        ink: "18181B", ink2: "52525B", ink3: "686872", ink4: "767680",
        line: "E4E4E7", lineStrong: "D4D4D8",
        selected: "E9E9EC", hover: "F1F1F3",
        inbox: "8B8B93", ready: "3B6FA0", running: "3A7D52",
        review: "B4802A", done: "9A9AA2",
        danger: "B4443E", warn: "C1852F", accent: "3B6FA0",
        isDark: false,
        projectColors: ["red": "B4574F", "orange": "C27A3A", "yellow": "B8962E", "green": "4F8A5B",
                        "teal": "3E8A87", "blue": "4A74A8", "purple": "7E62A8", "gray": "8B8680"]
    )

    /// Solarized Light: the classic easy-on-the-eyes yellowish palette
    static let solarized = Palette(
        sidebar: "E3DBC6", list: "F2ECDA", canvas: "FAF4E6",
        card: "FDF6E3", cardHover: "FFFBEF", elevated: "FDF6E3",
        ink: "073642", ink2: "586E75", ink3: "839496", ink4: "A8B3B3",
        line: "E0D9C4", lineStrong: "CFC8B4",
        selected: "E4DCC6", hover: "EDE6D3",
        inbox: "839496", ready: "268BD2", running: "859900",
        review: "B58900", done: "93A1A1",
        danger: "DC322F", warn: "CB4B16", accent: "268BD2",
        isDark: false,
        projectColors: ["red": "DC322F", "orange": "CB4B16", "yellow": "B58900", "green": "859900",
                        "teal": "2AA198", "blue": "268BD2", "purple": "6C71C4", "gray": "93A1A1"]
    )

    /// One Dark: Atom's classic dark theme, the one programmers know best
    static let oneDark = Palette(
        sidebar: "1B1F24", list: "23272E", canvas: "282C34",
        card: "31363F", cardHover: "373D47", elevated: "2F343D",
        ink: "ABB2BF", ink2: "8B94A3", ink3: "6B7280", ink4: "4E5666",
        line: "3A404B", lineStrong: "4A515F",
        selected: "3A4048", hover: "313640",
        inbox: "7F8794", ready: "61AFEF", running: "98C379",
        review: "E5C07B", done: "6B7280",
        danger: "E06C75", warn: "D19A66", accent: "61AFEF",
        isDark: true,
        projectColors: ["red": "E06C75", "orange": "D19A66", "yellow": "E5C07B", "green": "98C379",
                        "teal": "56B6C2", "blue": "61AFEF", "purple": "C678DD", "gray": "7F8794"]
    )

    static let builtins: [(name: String, palette: Palette)] = [
        ("Newsprint", .newsprint),
        ("Paper", .paper),
        ("Solarized Light", .solarized),
        ("One Dark", .oneDark),
    ]
}

// MARK: - hex → Color

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(
            .sRGB,
            red:   Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8)  & 0xFF) / 255,
            blue:  Double(v & 0xFF) / 255,
            opacity: 1
        )
    }
}
