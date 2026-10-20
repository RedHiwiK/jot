import SwiftUI

/// Global requirement search; local navigation filters never hide a result.
struct RequirementSearch: View {
    @EnvironmentObject var state: AppState
    @Environment(\.theme) var th
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    @State private var query = ""
    @State private var selectedID: Int?

    private var results: [Req] {
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        return state.reqs.filter { req in
            let text = req.searchText
            return words.allSatisfy { text.localizedCaseInsensitiveContains($0) }
        }.sorted {
            $0.updatedDate == $1.updatedDate ? $0.id > $1.id : $0.updatedDate > $1.updatedDate
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").foregroundStyle(th.ink3)
                TextField(L[.requirementsSearch], text: $query)
                    .textFieldStyle(.plain).font(Metric.body).focused($focused)
                    .onSubmit { openSelection() }
                    .onKeyPress(.downArrow) { move(1); return .handled }
                    .onKeyPress(.upArrow) { move(-1); return .handled }
                Button { dismiss() } label: {
                    Text("esc").font(Metric.meta).foregroundStyle(th.ink3)
                }.buttonStyle(.plain).accessibilityLabel(L[.closePanel])
            }.padding(20)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        if results.isEmpty {
                            Text(L[.noMatches]).foregroundStyle(th.ink3).padding(32)
                        }
                        ForEach(results) { req in
                            Button { open(req) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: req.state.symbol).foregroundStyle(th.state(req.state))
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(req.title).font(Metric.body).foregroundStyle(th.ink).lineLimit(2)
                                        Text("#\(req.id) · \(req.projectName) · \(req.state.label)")
                                            .font(Metric.meta).foregroundStyle(th.ink3)
                                    }
                                    Spacer(minLength: 0)
                                    if selectedID == req.id {
                                        Image(systemName: "return").foregroundStyle(th.ink3)
                                    }
                                }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(selectedID == req.id ? th.selected : Color.clear,
                                                in: RoundedRectangle(cornerRadius: 8))
                                    .contentShape(Rectangle())
                            }.buttonStyle(.plain).id(req.id)
                                .accessibilityAddTraits(selectedID == req.id ? .isSelected : [])
                        }
                    }.padding(.horizontal, 8).padding(.bottom, 12)
                }
                .onChange(of: selectedID) { _, id in
                    if let id { proxy.scrollTo(id) }
                }
            }
        }
        .frame(width: 620, height: 440)
        .background(th.elevated)
        .onAppear { focused = true; selectedID = results.first?.id }
        .onChange(of: query) { _, _ in selectedID = results.first?.id }
        .onChange(of: results.map(\.id)) { _, ids in
            if selectedID == nil || !ids.contains(selectedID!) { selectedID = ids.first }
        }
        .onExitCommand { dismiss() }
    }

    private func move(_ offset: Int) {
        guard !results.isEmpty else { return }
        let index = results.firstIndex { $0.id == selectedID } ?? (offset > 0 ? -1 : results.count)
        selectedID = results[min(results.count - 1, max(0, index + offset))].id
    }

    private func openSelection() {
        if let req = results.first(where: { $0.id == selectedID }) { open(req) }
    }

    private func open(_ req: Req) {
        state.selectedReqID = req.id
        dismiss()
    }
}
