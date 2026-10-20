import SwiftUI

@main
struct JotApp: App {
    @StateObject private var state = AppState()
    @StateObject private var themes = ThemeStore()
    @StateObject private var locale = LocaleStore()
    @StateObject private var shortcuts = ShortcutStore()

    var body: some Scene {
        WindowGroup(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Jot") {
            // .id must be the innermost modifier: SwiftUI uses the whole View type chain as the storage
            // key for the window frame; attaching .id outside makes the type chain vary with the language,
            // so the remembered window size is lost and a different stale record is restored, which shows
            // up as wrong window size and content overflowing the window after switching languages.
            Shell()
                .id(locale.language)
                .environmentObject(state)
                .environmentObject(themes)
                .environmentObject(locale)
                .environmentObject(shortcuts)
                .environment(\.theme, themes.current)
                .preferredColorScheme(themes.current.palette.isDark ? .dark : .light)
                .frame(minWidth: 820, minHeight: 650)
                .configureWindow(background: themes.current.sidebar)
                .task {
                    await state.refresh()
                    state.startAutoRefresh()
                }
        }
        // macOS standard: the Settings scene appears as the first app menu item, shortcut ⌘,
        Settings {
            SettingsSheet()
                .environmentObject(state)
                .environmentObject(themes)
                .environmentObject(locale)
                .environmentObject(shortcuts)
                .id(locale.language)
                .environment(\.theme, themes.current)
                .preferredColorScheme(themes.current.palette.isDark ? .dark : .light)
        }
        .defaultSize(width: 1040, height: 760)
        .commands {
            AppShortcutCommands(state: state, shortcuts: shortcuts)
        }
    }
}
