import SwiftUI
import AppKit

struct ProjectSettings: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var shortcuts: ShortcutStore
    @Environment(\.theme) var th
    @State private var conflict: String?
    @State private var renaming: Project?
    @State private var editingURL: Project?
    @State private var removing: Project?
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L[.projectOrderHint]).font(Metric.meta).foregroundStyle(th.ink3)
            if state.projects.isEmpty {
                Text(L[.noProjects]).foregroundStyle(th.ink3)
            }
            List {
                ForEach(Array(state.projects.enumerated()), id: \.element.id) { index, project in
                    HStack(spacing: 12) {
                        Image(systemName: "line.3.horizontal").foregroundStyle(th.ink3)
                        Text("\(index + 1)").font(Metric.meta.monospacedDigit()).foregroundStyle(th.ink3)
                        Text(project.name).lineLimit(1)
                        Spacer()
                        if let action = ShortcutAction(rawValue: "project\(index + 1)"), index < 9 {
                            ShortcutRecorder(binding: shortcuts.binding(for: action)) { candidate in
                                if let other = shortcuts.conflictingAction(for: candidate, excluding: action) {
                                    conflict = L[.shortcutConflict, other.title]
                                } else {
                                    shortcuts.set(candidate, for: action)
                                    conflict = nil
                                }
                            }.frame(width: 92, height: 28)
                        }
                        Button { state.moveProjects(from: IndexSet(integer: index), to: index - 1) } label: {
                            Image(systemName: "chevron.up")
                        }.disabled(index == 0).help(L[.moveProjectUp])
                        Button { state.moveProjects(from: IndexSet(integer: index), to: index + 2) } label: {
                            Image(systemName: "chevron.down")
                        }.disabled(index == state.projects.count - 1).help(L[.moveProjectDown])
                        actions(project)
                    }
                    .font(Metric.body).padding(.vertical, 6)
                    .listRowSeparator(.hidden)
                }.onMove { state.moveProjects(from: $0, to: $1) }
            }
            .listStyle(.plain).scrollContentBackground(.hidden)
            if let conflict { Text(conflict).font(Metric.meta).foregroundStyle(th.danger) }
            // Settings is a separate window, so the main window's error banner isn't visible here
            if let error = state.errorMessage { Text(error).font(Metric.meta).foregroundStyle(th.danger) }
        }
        .padding(.horizontal, 24).padding(.bottom, 24)
        .alert(L[.renameProject], isPresented: presented($renaming), presenting: renaming) { project in
            TextField(L[.projectName], text: $draft)
            Button(L[.actSave]) { state.renameProject(project.name, to: draft) }
            Button(L[.actCancel], role: .cancel) { }
        } message: { _ in
            Text(L[.renameProjectHint])
        }
        .alert(L[.repositoryURL], isPresented: presented($editingURL), presenting: editingURL) { project in
            TextField(project.repoURLInferred == true ? (project.repoURL ?? "") : "https://", text: $draft)
            Button(L[.actSave]) { state.setProjectRepoURL(project.name, draft) }
            Button(L[.actCancel], role: .cancel) { }
        } message: { _ in
            Text(L[.repositoryURLHint])
        }
        .confirmationDialog(L[.removeProjectTitle, removing?.name ?? ""],
                            isPresented: presented($removing), presenting: removing) { project in
            Button(L[.removeProject], role: .destructive) { state.removeProject(project.name) }
            Button(L[.actCancel], role: .cancel) { }
        } message: { project in
            Text(L[.removeProjectMessage, state.requirementCount(in: project.name)])
        }
    }

    private func actions(_ project: Project) -> some View {
        Menu {
            Button(L[.renameProject] + "…") { draft = project.name; renaming = project }
            Button(L[.repositoryURL] + "…") { draft = project.configuredRepoURL; editingURL = project }
            if let url = project.repositoryURL {
                Button(L[.openRepository]) { NSWorkspace.shared.open(url) }
            }
            Divider()
            Button(L[.removeProject] + "…", role: .destructive) { removing = project }
        } label: {
            Image(systemName: "ellipsis")
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .help(L[.moreActions]).accessibilityLabel(L[.moreActions])
        .disabled(state.isLoading)
    }

    private func presented(_ item: Binding<Project?>) -> Binding<Bool> {
        Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })
    }
}
