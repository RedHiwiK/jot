import SwiftUI
import AppKit

private struct BoardCardFrames: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private final class BoardGeometryCache {
    var frames: [Int: CGRect] = [:]
}

/// Overview board: the main workspace.
///
/// Dragging is a custom DragGesture, not the system onDrag:
/// that is cross-app file dragging (NSItemProvider), with a + cursor, window dragging,
/// and uncontrollable animation. Moving cards within the board should be fully under our control.
struct OverviewBoard: View {
    @EnvironmentObject var state: AppState
    @Environment(\.theme) var th
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Drag session. Splitting it in two is the key performance measure:
    /// translation changes every frame (60fps); in @State it would re-render the whole board,
    /// including refiltering every card. So it lives in DragModel, observed only by the overlay.
    @StateObject private var dragModel = DragModel()
    /// Low-frequency state: what's being dragged and which column is the drop target. Only these redraw column highlights.
    @State private var dragging: Req?
    @State private var target: ReqState?
    @State private var insertionBefore: Int?
    @State private var geometryCache = BoardGeometryCache()
    private var cardFrames: [Int: CGRect] { geometryCache.frames }
    @State private var dragItems: [Req] = []
    @State private var columnScrollIDs: [ReqState: Int] = [:]
    @State private var settling = false

    @State private var boardWidth: CGFloat = 0
    @FocusState private var listFocused: Bool
    @State private var keyboardSelection: Int?
    @FocusState private var focusedCardID: Int?
    @State private var deleting: Req?

    private var columns: [ReqState] {
        // A state picked in the sidebar shows only that column (Done / Archived go this way too)
        if case .state(let s) = state.selection { return [s] }
        if let filter = state.requirementFilter { return [filter] }
        // The board only ever shows active states. DONE / ARCHIVED grow without bound
        // and would squeeze the work in flight; each has its own sidebar row
        return ReqState.active
    }

    var body: some View {
        let grouped = Dictionary(grouping: state.filtered, by: \.state)
        VStack(spacing: 0) {
        GeometryReader { geo in
            if columns.count == 1 {
                requirementList
            } else {
            let contentWidth = max(geo.size.width, CGFloat(columns.count) * 220)
            ScrollView(.horizontal) {
            ZStack(alignment: .topLeading) {
                Color.clear
                    .onAppear { boardWidth = contentWidth }
                    .onChange(of: contentWidth) { _, w in boardWidth = w }

                HStack(spacing: 0) {
                    ForEach(columns, id: \.self) { st in
                        column(st, items: grouped[st] ?? [], width: contentWidth / CGFloat(columns.count))
                    }
                }

                // The overlay is its own view: the only place that observes high-frequency translation
                if let req = dragging {
                    FloatingCard(req: req, model: dragModel)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: contentWidth, height: geo.size.height - 12)
            .coordinateSpace(name: "board")
            .onPreferenceChange(BoardCardFrames.self) { geometryCache.frames = $0 }
            }
            // Unlike .hidden, .never also overrides macOS “Always show scroll bars”.
            .scrollIndicators(.never)
            }
        }
        }
        .background(th.canvas)
        .confirmationDialog(L[.deleteReqTitle],
                            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            presenting: deleting) { req in
            Button(L[.actDelete], role: .destructive) { state.delete(req) }
            Button(L[.actCancel], role: .cancel) { }
        } message: { _ in
            Text(L[.deleteReqMessage])
        }
    }

    private var requirementList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    if state.groupsByProject {
                        ForEach(state.projectSections, id: \.project) { section in
                            Section {
                                if !state.isCollapsed(section.project) {
                                    ForEach(section.reqs) { listRow($0) }
                                }
                            } header: {
                                sectionHeader(section.project, count: section.reqs.count)
                            }
                        }
                    } else {
                        ForEach(state.filtered) { listRow($0) }
                    }
                    if state.filtered.isEmpty {
                        Text(L[.noMatches]).font(Metric.body).foregroundStyle(th.ink3).padding(32)
                    }
                }.scrollTargetLayout()
            }
            .scrollIndicators(.never)
            .scrollPosition(id: $state.requirementListScrollID)
            .focusable()
            // Keyboard navigation belongs to the list; selection is drawn on its rows.
            .focusEffectDisabled()
            .focused($listFocused)
            .onKeyPress(.downArrow) { moveListSelection(1, proxy); return .handled }
            .onKeyPress(.upArrow) { moveListSelection(-1, proxy); return .handled }
            .onKeyPress(.return) {
                if let id = keyboardSelection { state.selectedReqID = id }
                return .handled
            }
        }
    }

    private func listRow(_ req: Req) -> some View {
        Button {
            keyboardSelection = req.id
            state.selectedReqID = req.id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: req.state.symbol).foregroundStyle(th.state(req.state)).frame(width: 20)
                VStack(alignment: .leading, spacing: 8) {
                    Text(req.title).font(Metric.body).foregroundStyle(th.ink).lineLimit(2)
                    HStack(spacing: 8) {
                        // In grouped views the project name is already in the section header; repeating it in the row is noise
                        Text(state.groupsByProject ? req.state.label
                                                   : req.projectName + " · " + req.state.label)
                            .font(Metric.meta).foregroundStyle(th.ink3)
                        TagRow(tags: req.tagList)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Text(L.shortDate(req.updatedAt)).font(Metric.meta).foregroundStyle(th.ink3)
            }.padding(.horizontal, 24).frame(minHeight: 80)
                .background(keyboardSelection == req.id ? th.selected : Color.clear)
                .overlay { if keyboardSelection == req.id { Rectangle().strokeBorder(th.accent, lineWidth: 1) } }
                .contentShape(Rectangle())
        }.buttonStyle(.plain).id(req.id).contextMenu { menu(req) }
    }

    private func sectionHeader(_ project: String, count: Int) -> some View {
        let collapsed = state.isCollapsed(project)
        return Button { state.toggleCollapsed(project) } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(th.ink4)
                    .rotationEffect(.degrees(collapsed ? 0 : 90))
                Text(project.isEmpty ? L[.unassigned] : project)
                    .font(Metric.meta.weight(.semibold)).foregroundStyle(th.ink2)
                Text("\(count)")
                    .font(Metric.micro.monospacedDigit()).foregroundStyle(th.ink4)
                Spacer()
            }
            .padding(.horizontal, 24).frame(height: 34)
            .background(th.canvas)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(collapsed ? [] : .isSelected)
    }

    private func moveListSelection(_ offset: Int, _ proxy: ScrollViewProxy) {
        let items = state.navigableReqs
        guard !items.isEmpty else { return }
        let current = items.firstIndex { $0.id == keyboardSelection }
        let index = min(items.count - 1, max(0, (current ?? (offset > 0 ? -1 : items.count)) + offset))
        keyboardSelection = items[index].id
        proxy.scrollTo(items[index].id)
    }

    // MARK: Columns

    private func column(_ st: ReqState, items: [Req], width: CGFloat) -> some View {
        let isTarget = target == st && dragging?.state != st

        return VStack(spacing: 0) {
            if columns.count > 1 {
                HStack(spacing: 6) {
                    Circle().fill(th.state(st)).frame(width: 5, height: 5)
                    Button(st.label) { state.requirementFilter = st }
                        .buttonStyle(.plain)
                        .font(Metric.meta.weight(.semibold))
                        .foregroundStyle(th.ink2)
                    Text("\(items.count)")
                        .font(Metric.micro.monospacedDigit())
                        .foregroundStyle(th.ink4)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
            }

            ScrollView {
                LazyVStack(spacing: 9) {
                    ForEach(items) { req in
                        cardSlot(req).id(req.id)
                            .offset(y: displacement(req, items: items))
                            .background {
                                GeometryReader { geometry in
                                    Color.clear.preference(key: BoardCardFrames.self,
                                        value: [req.id: geometry.frame(in: .named("board"))])
                                }
                            }
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.20), value: insertionBefore)
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.20), value: target)
                    }
                    if let dragged = dragging, target == st && dragged.state != st {
                        Color.clear.frame(height: dragModel.size.height)
                    }

                }
                .scrollTargetLayout()
                .padding(.horizontal, 10)
                .padding(.vertical, 11)
                .background(DragAutoScroll(active: dragging != nil && target == st && !settling))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: items.count)
            }
            // Unlike .hidden, .never also overrides macOS “Always show scroll bars”.
            .scrollIndicators(.never)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollPosition(id: Binding(get: { columnScrollIDs[st] }, set: { columnScrollIDs[st] = $0 }))
            .onAppear { columnScrollIDs[st] = state.boardScrollIDs[st] }
            .onDisappear { state.boardScrollIDs[st] = columnScrollIDs[st] }
            .overlay {
                if items.isEmpty && !(dragging != nil && target == st) {
                    Text(state.requirementQuery.isEmpty ? emptyHint(st) : L[.noMatches])
                        .font(Metric.meta)
                        .foregroundStyle(th.ink3)
                        .multilineTextAlignment(.center)
                        .padding(24)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(width: width)

        .background {
            // Drop highlight: faint column tint + dashed border
            RoundedRectangle(cornerRadius: 8)
                .fill(isTarget ? th.state(st).opacity(0.07) : Color.clear)
                .padding(6)
                .overlay {
                    if isTarget {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(th.state(st).opacity(0.45),
                                          style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            .padding(6)
                    }
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isTarget)
        }
        // Record each column's frame to hit-test the drop target while dragging

    }

    /// Card slot: the original spot is left empty while dragging and the other cards close up
    @ViewBuilder
    private func cardSlot(_ req: Req) -> some View {
        let isDragging = dragging?.id == req.id

        // Read the frame live via a GeometryReader in an overlay;
        // caching it in onAppear records it once and goes stale after scrolling
        BoardCard(req: req)
            .equatable()
            .opacity(isDragging ? 0 : 1)
            .overlay {
                GeometryReader { g in
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            state.selectedReqID = req.id
                        }
                        .highPriorityGesture(
                            dragGesture(req, frame: g.frame(in: .named("board"))),
                            including: columns.count > 1 ? .all : .subviews
                        )
                }
            }
            .contextMenu { menu(req) }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { state.selectedReqID = req.id }
            .focusable()
            .focusEffectDisabled()
            .focused($focusedCardID, equals: req.id)
            .overlay {
                RoundedRectangle(cornerRadius: Metric.radius)
                    .fill(focusedCardID == req.id ? th.accent.opacity(0.04) : Color.clear)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Metric.radius)
                    .strokeBorder(focusedCardID == req.id ? th.accent.opacity(0.4) : Color.clear, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .onKeyPress(.return) { state.selectedReqID = req.id; return .handled }
    }

    private func dragGesture(_ req: Req, frame: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .named("board"))
            .onChanged { v in
                guard !settling else { return }
                if dragging == nil {
                    dragItems = state.filtered
                    focusedCardID = nil
                    dragModel.begin(origin: frame.origin, size: frame.size)
                    dragging = req
                }
                // Each frame writes only the model, never @State, so the board doesn't re-render
                if dragModel.translation != v.translation { dragModel.translation = v.translation }

                // Write @State only when the drop target changes (low frequency, a few times per drag at most)
                let t = columns.count > 1 ? columnAt(v.location) : nil
                if t != target { target = t }
                let candidate = dragItems.first {
                    $0.id != req.id && $0.state == t && (cardFrames[$0.id]?.midY ?? -.infinity) > v.location.y
                }?.id
                if insertionBefore != candidate { insertionBefore = candidate }
            }
            .onEnded { v in
                // Pointer dragging must not leave a keyboard-focus highlight behind.
                focusedCardID = nil
                let landed = columns.count > 1 ? columnAt(v.location) : nil

                if let t = landed {
                    let before = insertionBefore
                    var destinationY = before.flatMap { cardFrames[$0]?.minY }
                        ?? state.filtered.filter { $0.state == t && $0.id != req.id }.compactMap { cardFrames[$0.id]?.maxY }.max().map { $0 + 9 }
                        ?? 59
                    if t == req.state, let sourceY = cardFrames[req.id]?.minY, destinationY > sourceY {
                        destinationY -= dragModel.size.height + 9
                    }
                    settling = true
                    withAnimation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.9)) {
                        dragModel.translation = CGSize(
                            width: CGFloat(columns.firstIndex(of: t) ?? 0) * boardWidth / CGFloat(columns.count) + 10 - dragModel.origin.x,
                            height: destinationY - dragModel.origin.y)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.24)) {
                    // Column changed: the card disappears and the new column's items animation pops it in
                    dragging = nil
                    target = nil
                    dragModel.reset()
                    state.place(req, in: t, before: before)
                    insertionBefore = nil
                    settling = false
                    }
                } else {
                    // Same column: spring back to the original spot
                    target = nil
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.14)) {
                        dragModel.translation = .zero
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.14)) {
                        dragging = nil
                        dragModel.reset()
                    }
                }
            }
    }

    private func displacement(_ req: Req, items: [Req]) -> CGFloat {
        guard let dragged = dragging, req.id != dragged.id,
              let index = items.firstIndex(where: { $0.id == req.id }) else { return 0 }
        let gap = dragModel.size.height + 9
        var offset: CGFloat = 0
        if let source = items.firstIndex(where: { $0.id == dragged.id }), index > source { offset -= gap }
        if target == req.state {
            let insertion = insertionBefore.flatMap { id in items.firstIndex { $0.id == id } } ?? items.count
            if index >= insertion { offset += gap }
        }
        return offset
    }

    /// Column index for an x coordinate.
    /// Positions aren't cached: column widths change when the filter switches, so values from onAppear go stale.
    private func columnAt(_ p: CGPoint) -> ReqState? {
        guard columns.count > 1, boardWidth > 0 else { return nil }
        let colW = boardWidth / CGFloat(columns.count)
        let idx = Int(p.x / colW)
        guard idx >= 0, idx < columns.count else { return nil }
        return columns[idx]
    }

    private func emptyHint(_ st: ReqState) -> String {
        switch st {
        case .inbox:    return L[.emptyInbox]
        case .inProgress: return L[.emptyInProgress]
        case .onHold:   return L[.emptyReview]
        case .done:     return L[.emptyDone]
        case .archived: return L[.emptyArchived]
        }
    }

    @ViewBuilder
    private func menu(_ req: Req) -> some View {
        Menu(L[.actChangeState]) {
            ForEach(ReqState.active) { s in
                Button(s.label) { state.move(req, to: s) }.disabled(s == req.state)
            }
            Divider()
            Button(ReqState.done.label) { state.move(req, to: .done) }
                .disabled(req.state == .done)
        }
        if req.state == .archived {
            Button(L[.actRestore]) { state.move(req, to: .inbox) }
        } else {
            Button(L[.actArchive], role: .destructive) { state.archive(req) }
        }
        Divider()
        Button(L[.actDelete] + "…", role: .destructive) { deleting = req }
    }
}

// MARK: Card

struct BoardCard: View, Equatable {
    @Environment(\.theme) var th
    @EnvironmentObject var state: AppState
    let req: Req
    var floating = false
    @State private var hover = false

    /// Skip redraws when data is unchanged. With dozens of cards on the board,
    /// dragging one shouldn't re-evaluate the rest.
    nonisolated static func == (a: BoardCard, b: BoardCard) -> Bool {
        a.req == b.req && a.floating == b.floating
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                StatusDot(req: req).padding(.top, 3.5)
                Text(req.title)
                    .font(Metric.body)
                    .foregroundStyle(th.ink)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

            TagRow(tags: req.tagList).padding(.top, 2)

            HStack(spacing: 12) {
                if let p = req.project {
                    Text(p).lineLimit(1).truncationMode(.middle)
                }
                Spacer(minLength: 8)
                Text(L.shortDate(req.updatedAt))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .font(Metric.micro)
            .foregroundStyle(th.ink3)
            .padding(.top, 6)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Metric.radius)
                .fill(floating ? th.cardHover : (hover ? th.cardHover : th.card))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metric.radius)
                .strokeBorder(state.selectedReqID == req.id && !floating
                              ? th.accent.opacity(0.5) : Color.clear)
        )
        .onHover { h in
            guard !floating else { return }
            hover = h
        }
    }
}

/// Holder of the drag translation.
///
/// Pulled out as the core performance measure: translation changes every frame (60fps);
/// in the board's @State every frame would re-evaluate the whole OverviewBoard,
/// including state.filtered and rebuilding every column.
/// Here, only FloatingCard observes it.
@MainActor
final class DragModel: ObservableObject {
    @Published var translation: CGSize = .zero
    /// The origin needs no @Published: it doesn't change during a drag
    var origin: CGPoint = .zero
    var size: CGSize = .zero

    func begin(origin: CGPoint, size: CGSize) {
        self.origin = origin
        self.size = size
        translation = .zero
    }

    func reset() {
        translation = .zero
    }
}

/// The floating card that follows the pointer. The only view on the board observing high-frequency translation.
struct FloatingCard: View {
    @Environment(\.theme) var th
    let req: Req
    @ObservedObject var model: DragModel

    var body: some View {
        BoardCard(req: req, floating: true)
            .equatable()
            .frame(width: model.size.width)
            .scaleEffect(1.015)
            .shadow(color: .black.opacity(th.palette.isDark ? 0.35 : 0.14), radius: 8, y: 4)
            .drawingGroup()
            .position(
                x: model.origin.x + model.size.width / 2 + model.translation.width,
                y: model.origin.y + model.size.height / 2 + model.translation.height
            )
    }
}
