import SwiftUI
import AppKit

/// A centered document with its title, properties and actions in the reading column.
struct DetailPane: View {
    @EnvironmentObject var state: AppState
    @Environment(\.theme) var th
    let req: Req

    @State private var body_ = ""
    @State private var original = ""
    @State private var editing = false
    @State private var saving = false
    @State private var loading = true
    @State private var loadError: String?
    @State private var saveError: String?
    @State private var confirmDiscard = false
    @State private var copied = false
    @State private var addingTag = false
    @State private var newTag = ""
    @FocusState private var tagFieldFocused: Bool

    private var dirty: Bool { body_ != original }

    var body: some View {
        doc
        .frame(minWidth: 300, maxWidth: .infinity)
        .background(th.canvas)
        .task(id: req.id) { copied = false; await load() }
        .task(id: copied) {
            guard copied else { return }
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            copied = false
        }
        .confirmationDialog(L[.discardChanges], isPresented: $confirmDiscard) {
            Button(L[.discardChanges], role: .destructive) { cancelEditing() }
            Button(L[.keepEditing], role: .cancel) { }
        }
        .onChange(of: body_) { _, text in
            guard !loading else { return }
            if text == original { state.drafts.removeValue(forKey: req.id) }
            else { state.drafts[req.id] = BodyDraft(text: text, original: original) }
        }
    }

    // MARK: Header: title + attributes + actions

    /// Attribute area: project, state, tags. All three describe what the requirement is,
    /// so they share one chip style of equal weight and don't compete with the action buttons on the right.
    @ViewBuilder private var attributes: some View {
        HStack(spacing: 6) {
            Menu {
                Button(L[.unassigned]) { state.update(req, project: "") }
                Divider()
                ForEach(state.projects) { project in
                    Button(project.name) { state.update(req, project: project.name) }
                }
            } label: {
                Label(req.projectName, systemImage: "folder").lineLimit(1)
                    .foregroundStyle(th.ink2)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(th.hover, in: RoundedRectangle(cornerRadius: Metric.radiusSm))
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .help(L[.actChangeProject]).disabled(editing || state.isLoading)

            Label(req.state.label, systemImage: req.state.symbol)
                .foregroundStyle(th.state(req.state))
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(th.state(req.state).opacity(0.09),
                            in: RoundedRectangle(cornerRadius: Metric.radiusSm))

            ForEach(req.tagList, id: \.self) { tag in
                // Click jumps to that tag's filter view, since tags exist to cut across projects;
                // removal lives in the context menu, because a hover × on the attribute row makes the chip width jump.
                Button { state.showTag(tag) } label: { TagChip(text: tag) }
                    .buttonStyle(.plain)
                    .help(tag)
                    .contextMenu {
                        Button(L[.filterByTag]) { state.showTag(tag) }
                        Divider()
                        Button(L[.removeTag], role: .destructive) { state.removeTag(req, tag) }
                    }
            }

            // Linked PR/MR: click opens, right-click copies or unlinks. Linking is done by an agent via `jot link`
            ForEach(req.linkList, id: \.self) { link in
                Button { if let url = URL(string: link) { NSWorkspace.shared.open(url) } } label: {
                    Label(LinkLabel.short(link), systemImage: "arrow.triangle.pull")
                        .font(Metric.micro).foregroundStyle(th.ink2).lineLimit(1)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(th.hover, in: RoundedRectangle(cornerRadius: Metric.radiusSm))
                }
                .buttonStyle(.plain)
                .help(link)
                .contextMenu {
                    Button(L[.copyLink]) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(link, forType: .string)
                    }
                    Divider()
                    Button(L[.unlink], role: .destructive) { state.unlink(req, link) }
                }
            }

            if addingTag {
                TextField(L[.addTagHint], text: $newTag)
                    .textFieldStyle(.plain)
                    .font(Metric.micro)
                    .foregroundStyle(th.ink)
                    .frame(width: 110)
                    .focused($tagFieldFocused)
                    .onSubmit(commitTag)
                    .onExitCommand { cancelTag() }
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: Metric.radiusSm).fill(th.hover))
                    .overlay(RoundedRectangle(cornerRadius: Metric.radiusSm).strokeBorder(th.accent.opacity(0.5)))
                    .onChange(of: tagFieldFocused) { _, focused in
                        // Collapse on focus loss so an empty field doesn't linger in the attribute row
                        if !focused { cancelTag() }
                    }
            } else if !editing {
                Button { addingTag = true; tagFieldFocused = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(th.ink3)
                        .padding(.horizontal, 6).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: Metric.radiusSm).fill(th.hover))
                }
                .buttonStyle(.plain)
                .help(L[.addTag]).accessibilityLabel(L[.addTag])
            }
        }
        .font(Metric.meta)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Action area: icon buttons aligned right. Both actions are peers, so no color hierarchy.
    @ViewBuilder private var actions: some View {
        HStack(spacing: 2) {
            // Repo URL comes from project config or git remote; when absent, hide the button instead of showing a dead one
            if let repo = state.project(named: req.project)?.repositoryURL {
                IconButton(icon: "arrow.up.forward.square") { NSWorkspace.shared.open(repo) }
                    .help(L[.openRepository]).accessibilityLabel(L[.openRepository])
            }
            IconButton(icon: "square.and.pencil") { editing = true }
                .help(L[.editBody]).accessibilityLabel(L[.editBody])
                .disabled(loading || loadError != nil)
            IconButton(icon: copied ? "checkmark" : "doc.on.doc") {
                let text = "# \(req.title)\n\nProject: \(req.projectName)\nRequirement: \(req.reference)\n\n\(body_)"
                NSPasteboard.general.clearContents()
                copied = NSPasteboard.general.setString(text, forType: .string)
            }
            .help(L[copied ? .requirementCopied : .copyRequirement])
            .accessibilityLabel(L[.copyRequirement])
            .disabled(loading || loadError != nil)
        }
    }

    private func commitTag() {
        let value = newTag
        newTag = ""
        addingTag = false
        state.addTag(req, value)
    }

    private func cancelTag() {
        newTag = ""
        addingTag = false
    }

    // MARK: Body

    private var doc: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                EditableRequirementTitle(req: req)
                // Attributes left, actions right: they differ in kind, so position (not color) separates them,
                // otherwise two rows of equally weighted rounded blocks read as a pile of buttons.
                HStack(alignment: .center, spacing: 8) {
                    attributes
                    Spacer(minLength: 12)
                    if !editing { actions }
                }.frame(minHeight: 32)
            }
            .padding(.top, 24).padding(.bottom, 14)
            .frame(maxWidth: Metric.readingWidth, alignment: .leading)
            .padding(.horizontal, 24)

            // Editing is a mode with explicit enter/exit; text buttons carry "Save / Cancel" better than icons
            if editing {
                HStack(spacing: 12) {
                    Text(dirty ? L[.unsaved] : L[.editMode])
                        .font(Metric.meta).foregroundStyle(dirty ? th.warn : th.ink3)
                    Spacer(minLength: 12)
                    Button(L[.actCancel]) {
                        if dirty { confirmDiscard = true } else { cancelEditing() }
                    }.buttonStyle(FlatButton(compact: true)).disabled(saving)
                    Button(L[.actSave]) { Task { await save() } }
                        .buttonStyle(FlatButton(tint: th.accent, filled: true, compact: true))
                        .keyboardShortcut("s", modifiers: .command).disabled(!dirty || saving)
                    if saving { ProgressView().controlSize(.small) }
                }
                .frame(maxWidth: Metric.readingWidth)
                .padding(.horizontal, 24).padding(.bottom, 16)
            }
            if let saveError {
                Text(saveError).font(Metric.meta).foregroundStyle(th.danger)
                    .frame(maxWidth: Metric.readingWidth, alignment: .leading)
                    .padding(.horizontal, 24).padding(.bottom, 12)
            }
            Rectangle().fill(th.line).frame(height: 1)
                .frame(maxWidth: Metric.readingWidth)
                .padding(.horizontal, 24).padding(.bottom, 24)

            if loading {
                Spacer(); ProgressView(); Spacer()
            } else if let loadError {
                Spacer()
                Text(loadError).font(Metric.meta).foregroundStyle(th.danger).padding()
                Button(L[.retry]) { Task { await load() } }
                Spacer()
            } else if editing {
                TextEditor(text: $body_)
                    .font(Metric.mono).foregroundStyle(th.ink)
                    .scrollContentBackground(.hidden)
                    .disabled(saving)
                    .frame(maxWidth: Metric.readingWidth)
                    .padding(.horizontal, 24).padding(.bottom, 24)
            } else {
                ScrollView {
                    MarkdownView(source: body_)
                        .frame(maxWidth: Metric.readingWidth, alignment: .leading)
                        .padding(.horizontal, 24).padding(.bottom, 40)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func cancelEditing() {
        body_ = original
        state.drafts.removeValue(forKey: req.id)
        saveError = nil
        editing = false
    }

    private func load() async {
        loading = true
        loadError = nil
        defer { loading = false }
        if let draft = state.drafts[req.id] {
            body_ = draft.text; original = draft.original
            editing = draft.text != draft.original
            return
        }
        do {
            let text = try await JotClient.shared.body(req.id)
            guard !Task.isCancelled else { return }
            body_ = text; original = text
        } catch { loadError = error.localizedDescription }
    }

    private func save() async {
        guard !saving, dirty else { return }
        saving = true
        saveError = nil
        let text = body_
        defer { saving = false }
        do {
            try await JotClient.shared.setBody(req.id, body: text)
            original = text
            state.drafts.removeValue(forKey: req.id)
            editing = false
            await state.refresh()
        } catch { saveError = error.localizedDescription }
    }

}
