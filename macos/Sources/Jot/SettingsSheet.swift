import SwiftUI
import AppKit

/// Settings panel. Uses the standard macOS Settings scene,
/// which the system places as the first app menu item and binds to ⌘,.
///
/// Layout is a vertical sidebar nav + content on the right, not TabView's horizontal tabs:
/// horizontal tabs get cramped by the third or fourth category, while a vertical list scales.
/// macOS 26 System Settings and Otty's preferences use the same shape.
struct SettingsSheet: View {
    @Environment(\.theme) var th

    @State private var tab: Tab = .general

    enum Tab: String, CaseIterable, Identifiable {
        case general, appearance, projects, shortcuts, archived

        var id: String { rawValue }

        @MainActor
        var title: String {
            switch self {
            case .general:    return L[.setGeneral]
            case .appearance: return L[.setAppearance]
            case .shortcuts:  return L[.setShortcuts]
            case .archived: return L[.stArchived]
            case .projects: return L[.navProjects]
            }
        }
        var icon: String {
            switch self {
            case .general:    return "gearshape"
            case .appearance: return "paintpalette"
            case .shortcuts:  return "keyboard"
            case .archived: return "archivebox"
            case .projects: return "folder"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            content
        }
        // Fit all shortcut rows by default while retaining a scrollable compact size.
        .frame(minWidth: 720, idealWidth: 1040, maxWidth: .infinity,
               minHeight: 580, idealHeight: 760, maxHeight: .infinity)
        .background(th.canvas)
        // Title bar matches the sidebar color; otherwise the system default background shows through
        // and doesn't meet the dark content area (an abrupt light band)
        .configureSettingsWindow(background: th.sidebar)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Tab.allCases) { t in
                SettingsNavItem(tab: t, selected: tab == t) { tab = t }
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 14)
        .frame(width: 200, alignment: .leading)
        // Regions are layered by color, no divider lines
        .background(th.sidebar)
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(tab.title)
                .font(Metric.title)
                .foregroundStyle(th.ink)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 14)

            Group {
                switch tab {
                case .general:    GeneralSettings()
                case .appearance: AppearanceSettings()
                case .shortcuts:  ShortcutSettings()
                case .projects: ProjectSettings()
                case .archived: ArchivedSettings()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(th.canvas)
    }
}

/// Sidebar item. Icon + text; selection uses a filled block rather than an outline.
private struct SettingsNavItem: View {
    @Environment(\.theme) var th
    let tab: SettingsSheet.Tab
    let selected: Bool
    let action: () -> Void

    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12))
                    .frame(width: 16)
                Text(tab.title)
                    .font(Metric.body)
                Spacer(minLength: 0)
            }
            .foregroundStyle(selected ? th.ink : th.ink2)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: Metric.radiusSm)
                    .fill(selected ? th.selected : (hover ? th.hover : Color.clear))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.1), value: hover)
    }
}

// MARK: - General

struct GeneralSettings: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var locale: LocaleStore
    @Environment(\.theme) var th

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            languagePicker

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Language gets its own picker: the value is an enum, not a string,
    /// and the display name differs from the value (zh-Hans shows as its native name)
    private var languagePicker: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(L[.setLanguage]).font(Metric.meta.weight(.medium)).foregroundStyle(th.ink)

            HStack(spacing: 5) {
                ForEach(Language.allCases, id: \.self) { lang in
                    let on = locale.language == lang
                    Button { locale.select(lang) } label: {
                        Text(lang.display)
                            .font(Metric.meta)
                            .foregroundStyle(on ? th.ink : th.ink3)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                            .background {
                                RoundedRectangle(cornerRadius: Metric.radiusSm)
                                    .fill(on ? th.selected : th.card)
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: Metric.radiusSm)
                                    .strokeBorder(on ? th.accent.opacity(0.5) : th.line)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(L[.setLanguageHint]).font(Metric.micro).foregroundStyle(th.ink4)
        }
    }

}

// MARK: - Appearance

struct AppearanceSettings: View {
    @EnvironmentObject var themes: ThemeStore
    @Environment(\.theme) var th

    private let cols = [GridItem(.adaptive(minimum: 130), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                LazyVGrid(columns: cols, spacing: 12) {
                    ForEach(themes.available, id: \.name) { entry in
                        Swatch(name: entry.name,
                               palette: entry.palette,
                               selected: themes.current.name == entry.name)
                            .onTapGesture { themes.select(entry.name) }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }

            Rectangle().fill(th.line).frame(height: 1)

            HStack(spacing: 8) {
                Button(L[.exportTemplate]) {
                    if let url = themes.exportTemplate() {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
                .buttonStyle(FlatButton(compact: true))

                Button(L[.rescan]) { themes.reload() }
                    .buttonStyle(FlatButton(compact: true))

                Spacer()

                Text("~/.jot/themes/*.json")
                    .font(Metric.micro)
                    .foregroundStyle(th.ink4)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
    }
}

private struct ArchivedSettings: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        List {
            ForEach(state.reqs.filter { $0.state == .archived }) { req in
                HStack {
                    Text(req.title).lineLimit(2)
                    Spacer()
                    Button { state.move(req, to: .inbox) } label: {
                        Label(L[.stInbox], systemImage: "arrow.uturn.backward")
                    }
                }.padding(.vertical, 6)
            }
        }.overlay {
            if !state.reqs.contains(where: { $0.state == .archived }) {
                Text(L[.emptyArchived]).foregroundStyle(.secondary)
            }
        }
    }
}
