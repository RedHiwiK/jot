import SwiftUI

struct EditableRequirementTitle: View {
    @EnvironmentObject var state: AppState
    @Environment(\.theme) var th
    let req: Req
    @State private var editing = false
    @State private var title = ""
    @State private var saving = false
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if editing {
                TextField(req.title, text: $title, axis: .vertical)
                    .textFieldStyle(.plain).focused($focused)
                    .disabled(saving)
                    .onSubmit { commit() }
                    .onKeyPress(.return) { commit(); return .handled }
                    .onKeyPress(.escape) {
                        editing = false
                        error = nil
                        focused = false
                        return .handled
                    }
                    .onChange(of: focused) { _, value in
                        if !value && editing { commit() }
                    }
            } else {
                Text(req.title)
                    .fixedSize(horizontal: false, vertical: true)
                    .onTapGesture(count: 2) { begin() }
                    .help(L[.editTitleHint])
                    .accessibilityAction(named: Text(L[.editTitleHint])) { begin() }
            }
            if let error {
                Text(error).font(Metric.meta).foregroundStyle(th.danger)
            }
        }
        .font(Metric.title).foregroundStyle(th.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func begin() {
        title = req.title
        error = nil
        editing = true
        focused = true
    }

    private func commit() {
        guard editing, !saving else { return }
        let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            error = L[.titleRequired]
            focused = true
            return
        }
        guard value != req.title else { editing = false; return }
        saving = true
        Task {
            defer { saving = false }
            do {
                _ = try await JotClient.shared.update(req.id, title: value)
                editing = false
                error = nil
                await state.refresh()
            } catch {
                self.error = error.localizedDescription
                focused = true
            }
        }
    }
}
