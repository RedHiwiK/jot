import SwiftUI

struct Shell: View {
    @EnvironmentObject var state: AppState
    @Environment(\.theme) var th
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("sidebarWidth") private var savedSidebar = 224.0
    @AppStorage("inspectorWidth") private var savedInspector = 320.0
    @State private var sidebarWidth: CGFloat = 224
    @State private var inspectorWidth: CGFloat = 320
    @State private var showInspector = false
    @State private var showSearch = false

    private var panelVisible: Bool {
        state.selectedReq != nil && showInspector
    }

    private var workspace: some View {
        GeometryReader { geometry in
            let available = geometry.size.width - sidebarWidth - 1
            let inspectorDocked = available - inspectorWidth - 1 >= 520
            HStack(spacing: 0) {
                Rail().frame(width: sidebarWidth)
                ResizeHandle(width: $sidebarWidth, range: 200...280,
                             onCommit: { savedSidebar = Double(sidebarWidth) }, direction: 1)
                HStack(spacing: 0) {
                  VStack(spacing: 0) {
                    if state.selectedReq != nil || state.selection != .all || state.requirementFilter != nil {
                        TopBar(showInspector: $showInspector)
                    }
                    if let req = state.selectedReq { DetailPane(req: req).id(req.id) }
                    else { OverviewBoard() }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                  if panelVisible && inspectorDocked {
                      ResizeHandle(width: $inspectorWidth, range: 280...360,
                                   onCommit: { savedInspector = Double(inspectorWidth) })
                      inspector.frame(width: inspectorWidth)
                  }
                }
                    .background(th.canvas)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: th.edgeShadow.opacity(0.5), radius: 4, y: 1)
                    .padding(.vertical, 8)
                    .padding(.trailing, 8)
                    .padding(.leading, 4)
            }
            .overlay(alignment: .trailing) {
                if panelVisible && !inspectorDocked {
                    ZStack(alignment: .trailing) {
                        Color.black.opacity(0.12).onTapGesture { closeInspector() }
                            .accessibilityLabel(L[.closePanel])
                        inspector.frame(width: inspectorWidth).background(th.card)
                    }
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: panelVisible)
        }
    }

    private var configuredWorkspace: some View {
        workspace.background(th.sidebar.ignoresSafeArea())
        .sheet(isPresented: $showSearch) { RequirementSearch() }
        .onReceive(NotificationCenter.default.publisher(for: .focusSearch)) { _ in showSearch = true }
        .onAppear {
            sidebarWidth = min(280, max(200, savedSidebar))
            inspectorWidth = min(360, max(280, savedInspector))
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleInspector)) { _ in
            if state.selectedReq != nil { showInspector.toggle() }
        }
        .onChange(of: state.selectedReqID) { _, _ in showInspector = false }
    }

    private var navigableWorkspace: some View {
        configuredWorkspace
        .onReceive(NotificationCenter.default.publisher(for: .shortcutBoard)) { _ in state.showBoard() }
        .onReceive(NotificationCenter.default.publisher(for: .shortcutInbox)) { _ in state.showState(.inbox) }
        .onReceive(NotificationCenter.default.publisher(for: .shortcutInProgress)) { _ in state.showState(.inProgress) }
        .onReceive(NotificationCenter.default.publisher(for: .shortcutDone)) { _ in state.showState(.done) }
        .onReceive(NotificationCenter.default.publisher(for: .shortcutReview)) { _ in state.showState(.onHold) }
        .onReceive(NotificationCenter.default.publisher(for: .shortcutRefresh)) { _ in state.refreshCurrentView() }
        .onReceive(NotificationCenter.default.publisher(for: .shortcutBack)) { _ in state.navigateBack() }
        .onReceive(projectShortcutNotifications) { note in
            guard let index = note.userInfo?["index"] as? Int, index < state.projects.count else { return }
            state.showProject(state.projects[index].name)
        }
        .onExitCommand {
            if showInspector { closeInspector() }
            else { state.navigateBack() }
        }
    }

    private var projectShortcutNotifications: NotificationCenter.Publisher {
        NotificationCenter.default.publisher(for: .shortcutProject1)
    }

    var body: some View {
        navigableWorkspace.overlay(alignment: .bottom) {
            if let message = state.errorMessage {
                Toast(text: message) { state.errorMessage = nil }
            } else if let archived = state.archivedUndo {
                HStack(spacing: 12) {
                    Label(archived.title, systemImage: "archivebox").lineLimit(1)
                    Button(L[.undoAction]) { state.undoArchive() }.disabled(state.isLoading)
                    IconButton(icon: "xmark") { state.archivedUndo = nil }
                        .help(L[.dismissMessage]).accessibilityLabel(L[.dismissMessage])
                }
                .font(Metric.meta).padding(12).background(th.elevated, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(th.line))
                .frame(maxWidth: 520).padding(16)
            }
        }
    }

    @ViewBuilder private var inspector: some View {
        if let req = state.selectedReq { InspectorPane(req: req, showInspector: $showInspector) }
    }

    private func closeInspector() { showInspector = false }
}

struct TopBar: View {
    @EnvironmentObject var state: AppState
    @Environment(\.theme) var th
    @Binding var showInspector: Bool

    private var title: String {
        switch state.selection {
        case .all: return L[.requirements]
        case .state(let value): return value.label
        case .project(let name): return name
        case .tag(let name): return name
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            if state.selectedReq != nil {
                IconButton(icon: "chevron.left") { state.navigateBack() }
                    .help(L[.shortcutBack]).accessibilityLabel(L[.shortcutBack])
            }
            if state.selection != .all || state.selectedReq != nil {
                Text(title).font(Metric.body.weight(.semibold)).foregroundStyle(th.ink).lineLimit(1)
                    .frame(maxWidth: 160, alignment: .leading)
            }
            if state.selectedReq == nil && state.requirementFilter != nil {
                IconButton(icon: "line.3.horizontal.decrease.circle") { state.requirementFilter = nil }
                    .help(L[.clearFilter]).accessibilityLabel(L[.clearFilter])
            }
            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity).overlay { TitleBarDragArea() }
            if state.isLoading {
                ProgressView().controlSize(.small).frame(width: 24)
            }
            if state.selectedReq != nil && !showInspector {
                IconButton(icon: "sidebar.right") { showInspector.toggle() }.help(L[.shortcutInspector]).accessibilityLabel(L[.shortcutInspector])
            }

        }.padding(.horizontal, 12).frame(height: Metric.toolbarHeight).background(th.canvas)

    }
}

struct Rail: View {
    @EnvironmentObject var state: AppState
    @Environment(\.theme) var th

    private var projectShortcuts: [String: Int] {
        Dictionary(uniqueKeysWithValues: state.projects.prefix(9).enumerated().map { ($0.element.name, $0.offset + 1) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    row(.all, L[.requirements], "rectangle.split.3x1", state.reqs.filter { ReqState.active.contains($0.state) }.count)
                    caption(L[.progress])
                    ForEach(ReqState.active) { progress in
                        row(.state(progress), progress.label, progress.symbol, state.count(for: progress))
                    }
                    row(.state(.done), L[.stDone], ReqState.done.symbol, state.count(for: .done))
                    if !state.projects.isEmpty {
                        caption(L[.navProjects])
                        ForEach(state.projects) { project in
                            row(.project(project.name), project.name, "folder", project.openCount, projectShortcuts[project.name])
                        }
                    }
                }.padding(.horizontal, 12).padding(.top, 16).padding(.bottom, 16)
            }
            HStack {
                Text("Jot").font(Metric.meta.weight(.semibold)).foregroundStyle(th.ink2)
                Spacer()
                SettingsLink { Image(systemName: "gearshape").frame(width: 32, height: 32) }
                    .buttonStyle(.plain).help(L[.setGeneral]).accessibilityLabel(L[.setGeneral])
            }.padding(12)
        }.frame(maxHeight: .infinity).background(th.sidebar)
    }

    private func caption(_ title: String) -> some View {
        Caption(text: title).padding(.horizontal, 8).padding(.top, 20).padding(.bottom, 4)
    }

    private func row(_ selection: SidebarSelection, _ title: String, _ icon: String, _ count: Int, _ projectNumber: Int? = nil) -> some View {
        NavigationRow(selection: selection, title: title, icon: icon, count: count, projectNumber: projectNumber)
    }
}

private struct NavigationRow: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var shortcuts: ShortcutStore
    @Environment(\.theme) var th
    let selection: SidebarSelection
    let title: String
    let icon: String
    let count: Int
    let projectNumber: Int?
    @State private var hover = false

    private var shortcutAction: ShortcutAction? {
        switch selection {
        case .all: return .board
        case .state(.inbox): return .inbox
        case .state(.inProgress): return .inProgress
        case .state(.onHold): return .onHold
        case .state(.done): return .done
        default: return nil
        }
    }

    /// Project color is used only here: the folder icon of sidebar project rows. Dots on board cards indicate state only, never project color
    private var projectTint: Color? {
        guard case .project(let name) = selection else { return nil }
        return th.project(state.project(named: name)?.color)
    }

    var body: some View {
        let selected = state.selection == selection
        Button {
            state.selectedReqID = nil
            if case .project(let name) = selection { state.showProject(name) }
            else if case .tag(let name) = selection { state.showTag(name) }
            else { state.selection = selection; state.requirementFilter = nil }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .regular))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(projectTint ?? (selected ? th.ink : th.ink2))
                    .frame(width: 18, height: 18)
                Text(title).lineLimit(1)
                Spacer(minLength: 4)
                if shortcuts.commandKeyDown, let action = shortcutAction {
                    Text(shortcuts.binding(for: action).display)
                        .font(Metric.meta.monospacedDigit())
                        .foregroundStyle(th.ink2)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                } else if shortcuts.optionKeyDown, let number = projectNumber,
                          let action = ShortcutAction(rawValue: "project\(number)") {
                    Text(shortcuts.binding(for: action).display).font(Metric.meta.monospacedDigit()).foregroundStyle(th.ink2)
                } else if count > 0 {
                    Text("\(count)").font(Metric.meta.monospacedDigit()).foregroundStyle(th.ink3)
                }
            }
            .font(selected ? Metric.body.weight(.semibold) : Metric.body)
            .foregroundStyle(selected ? th.ink : th.ink2)
            .padding(.horizontal, 8).frame(height: 36)
            .background(selected ? th.selected : (hover ? th.hover : Color.clear), in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }.buttonStyle(.plain).onHover { hover = $0 }
            .accessibilityAddTraits(selected ? .isSelected : []).help(title)
    }
}

struct Toast: View {
    @Environment(\.theme) var th
    let text: String
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(th.danger)
            Text(text).font(Metric.meta).foregroundStyle(th.ink).lineLimit(3)
            IconButton(icon: "xmark", action: dismiss)
                .help(L[.dismissMessage]).accessibilityLabel(L[.dismissMessage])
        }.padding(12).background(th.elevated, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(th.line))
            .frame(maxWidth: 520).padding(16)
    }
}
