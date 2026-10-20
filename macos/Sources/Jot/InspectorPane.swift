import SwiftUI
import AppKit

struct InspectorPane: View {
    @EnvironmentObject var state: AppState
    @Environment(\.theme) var th

    let req: Req
    @Binding var showInspector: Bool
    @State private var newTag = ""
    @FocusState private var tagFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            info
        }
        .background(th.canvas)
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text(L[.metaInfo]).font(Metric.meta.weight(.semibold))
            Spacer(minLength: 4)
            IconButton(icon: "sidebar.right") {
                showInspector = false
            }
            .help(L[.shortcutInspector])
            .accessibilityLabel(L[.closePanel])
        }
        .padding(.horizontal, 12)
        .frame(height: Metric.toolbarHeight)
    }

    private var info: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                field(L[.requirementID]) {
                    HStack {
                        Text("#\(req.id)").font(Metric.monoSm).textSelection(.enabled)
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("#\(req.id)", forType: .string)
                        } label: { Image(systemName: "doc.on.doc") }
                            .buttonStyle(.plain).help(L[.copyID]).accessibilityLabel(L[.copyID])
                    }.foregroundStyle(th.ink2)
                }
                tagField
                valueField(L[.metaOrigin], req.originCwd ?? L[.none_], mono: true)
                valueField(L[.metaCreated], L.shortDate(req.createdAt))
                valueField(L[.metaUpdated], L.shortDate(req.updatedAt))
            }
            .padding(16)
        }
    }

    /// Tag editing: existing tags can be removed one by one, Return in the field adds one.
    /// No Save button: each add/remove is a separate CLI call that takes effect immediately, like board drags.
    private var tagField: some View {
        field(L[.metaTags]) {
            VStack(alignment: .leading, spacing: 8) {
                if req.tagList.isEmpty {
                    Text(L[.noTags]).font(Metric.meta).foregroundStyle(th.ink4)
                } else {
                    FlowLayout(spacing: 4) {
                        ForEach(req.tagList, id: \.self) { tag in
                            // Chips wrap in the panel, so width jumps don't matter and the hover × stays;
                            // the context menu matches the detail attribute row so both places behave the same.
                            TagChip(text: tag) { state.removeTag(req, tag) }
                                .contextMenu {
                                    Button(L[.filterByTag]) { state.showTag(tag) }
                                    Divider()
                                    Button(L[.removeTag], role: .destructive) { state.removeTag(req, tag) }
                                }
                        }
                    }
                }
                TextField(L[.addTagHint], text: $newTag)
                    .textFieldStyle(.plain)
                    .font(Metric.meta)
                    .foregroundStyle(th.ink)
                    .focused($tagFieldFocused)
                    .onSubmit(commitTag)
                    .padding(.horizontal, 6).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: Metric.radiusSm).fill(th.hover))
                    .overlay(RoundedRectangle(cornerRadius: Metric.radiusSm)
                        .strokeBorder(tagFieldFocused ? th.accent.opacity(0.5) : th.line))
                    .accessibilityLabel(L[.addTag])
            }
        }
    }

    private func commitTag() {
        let value = newTag
        newTag = ""
        state.addTag(req, value)
    }

    private func field<Content: View>(_ label: String,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(Metric.micro).foregroundStyle(th.ink4)
            content()
        }
    }

    private func valueField(_ label: String, _ value: String, mono: Bool = false) -> some View {
        field(label) {
            Text(value)
                .font(mono ? Metric.monoSm : Metric.meta)
                .foregroundStyle(th.ink2)
                .textSelection(.enabled)
        }
    }

}
