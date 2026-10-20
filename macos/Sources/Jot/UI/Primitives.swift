import SwiftUI
import AppKit

/// Custom-drawn base components.
///
/// No system List / Divider / Button styles / NavigationSplitView:
/// the default combination inevitably looks like Reminders.
/// SwiftUI serves only as the drawing layer here.

// MARK: Divider

struct HLine: View {
    @Environment(\.theme) var th
    var color: Color?
    var body: some View {
        Rectangle().fill(color ?? th.line).frame(height: 1)
    }
}

struct VLine: View {
    @Environment(\.theme) var th
    var body: some View {
        Rectangle().fill(th.line).frame(width: 1)
    }
}

// MARK: Buttons

struct FlatButton: ButtonStyle {
    @Environment(\.theme) var th
    var tint: Color?
    var filled = false
    var compact = false
    @State private var hover = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let c = tint ?? th.ink
        let pressed = configuration.isPressed
        configuration.label
            .font(Metric.body)
            .padding(.horizontal, compact ? 8 : 11)
            .padding(.vertical, 4)
            .frame(minHeight: 32)
            .background {
                RoundedRectangle(cornerRadius: Metric.radiusSm)
                    .fill(filled
                          ? c.opacity(pressed ? 0.24 : (hover ? 0.17 : 0.115))
                          : (pressed ? th.selected : (hover ? th.hover : Color.clear)))
            }
            .overlay {
                RoundedRectangle(cornerRadius: Metric.radiusSm)
                    .strokeBorder(filled ? c.opacity(0.34) : (hover ? th.line : Color.clear))
            }
            .foregroundStyle(filled ? c : th.ink2)
            .opacity(enabled ? 1 : 0.45)
            .contentShape(Rectangle())
            .onHover { hover = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: hover)
    }
}

/// Icon-only button (for toolbars)
struct IconButton: View {
    @Environment(\.theme) var th
    let icon: String
    var size: CGFloat = 16
    let action: () -> Void
    @State private var hover = false
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(hover ? th.ink : th.ink2)
                .frame(width: 32, height: 32)
                .opacity(enabled ? 1 : 0.45)
                .background(
                    RoundedRectangle(cornerRadius: Metric.radiusSm)
                        .fill(hover ? th.hover : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

// MARK: Labels

struct Tag: View {
    @Environment(\.theme) var th
    let text: String
    var color: Color?
    var icon: String?
    var solid = false

    var body: some View {
        let c = color ?? th.ink3
        HStack(spacing: 3) {
            if let icon { Image(systemName: icon).font(.system(size: 8)) }
            Text(text)
        }
        .font(Metric.micro)
        .padding(.horizontal, 5.5)
        .padding(.vertical, 1.5)
        .background(c.opacity(solid ? 0.16 : 0.1), in: RoundedRectangle(cornerRadius: 3))
        .foregroundStyle(c)
    }
}

/// Requirement state dot. It reflects only the manual workflow, not any background process state.
struct StatusDot: View {
    @Environment(\.theme) var th
    let req: Req
    var size: CGFloat = 6

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }

    private var color: Color {
        return th.state(req.state)
    }
}

/// Draggable vertical divider.
///
/// No fixed sidebar width suits everyone: narrow truncates long names,
/// wide wastes space when you only want a glance. Let the user drag it.
struct ResizeHandle: View {
    @Environment(\.theme) var th
    @Binding var width: CGFloat
    let range: ClosedRange<CGFloat>
    /// Called on release. Persisting every frame mid-drag slows the whole UI, so this is the only place it's saved
    var onCommit: () -> Void = {}
    /// Which drag direction widens. The right sidebar is -1: pulling left widens it
    var direction: CGFloat = -1

    @State private var hover = false
    @State private var start: CGFloat?
    @State private var pushed = false

    var body: some View {
        Rectangle()
            .fill(start != nil ? th.accent.opacity(0.35) : Color.clear)
            .frame(width: 1)
            // Hit area wider than the visual: a 1pt line is impossible to grab
            .contentShape(Rectangle().inset(by: -3))
            .onHover { h in
                hover = h
                setCursor(h)
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { g in
                        // Compute an absolute value from global coordinates + the starting width.
                        //
                        // Don't use g.translation: the handle sits inside the layout being resized, so it moves
                        // as the width changes and translation immediately becomes a different value,
                        // jittering on every drag, which looks like flicker.
                        // Global coordinates are unaffected by layout, so they're a stable reference.
                        // Compute into a local first: @State writes become visible only on the next frame,
                        // so reading back in the same closure gets the old value and the first frame jumps
                        let base = start ?? (width - g.startLocation.x * direction)
                        if start == nil {
                            start = base
                            setCursor(true)
                        }
                        width = clamp(base + g.location.x * direction)
                    }
                    .onEnded { _ in
                        start = nil
                        onCommit()
                        if !hover { setCursor(false) }
                    }
            )
    }

    private func clamp(_ v: CGFloat) -> CGFloat {
        min(max(v, range.lowerBound), range.upperBound)
    }

    /// push/pop must be balanced; one extra push and the cursor never returns to the arrow
    private func setCursor(_ on: Bool) {
        if on, !pushed {
            NSCursor.resizeLeftRight.push()
            pushed = true
        } else if !on, pushed, start == nil {
            NSCursor.pop()
            pushed = false
        }
    }
}

// MARK: Section header

struct Caption: View {
    @Environment(\.theme) var th
    let text: String
    var body: some View {
        Text(text)
            .font(Metric.micro)
            .foregroundStyle(th.ink3)
    }
}

// MARK: Custom text field

struct Field: View {
    @Environment(\.theme) var th
    let placeholder: String
    @Binding var text: String
    var mono = false
    var onSubmit: (() -> Void)?
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(mono ? Metric.mono : Metric.body)
            .foregroundStyle(th.ink)
            .focused($focused)
            .onSubmit { onSubmit?() }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(th.card, in: RoundedRectangle(cornerRadius: Metric.radiusSm))
            .overlay(
                RoundedRectangle(cornerRadius: Metric.radiusSm)
                    .strokeBorder(focused ? th.accent.opacity(0.5) : th.line)
            )
    }
}

struct TextArea: View {
    @Environment(\.theme) var th
    @Binding var text: String
    var minHeight: CGFloat = 120
    var highlight = false

    var body: some View {
        TextEditor(text: $text)
            .font(Metric.mono)
            .foregroundStyle(th.ink)
            .scrollContentBackground(.hidden)
            .padding(8)
            .frame(minHeight: minHeight)
            .background(th.card, in: RoundedRectangle(cornerRadius: Metric.radiusSm))
            .overlay(
                RoundedRectangle(cornerRadius: Metric.radiusSm)
                    .strokeBorder(highlight ? th.accent.opacity(0.55) : th.line)
            )
    }
}

/// Inline dropdown: looks like plain text, shows options on click.
/// Used for the project in the metadata row; a frequent action shouldn't hide three menus deep.
struct InlinePicker: View {
    @Environment(\.theme) var th
    let value: String?
    let placeholder: String
    let options: [String]
    let onPick: (String) -> Void

    @State private var hover = false

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { o in
                Button(o) { onPick(o) }
            }
        } label: {
            HStack(spacing: 3) {
                Text(value?.isEmpty == false ? value! : placeholder)
                    .font(Metric.meta)
                    .foregroundStyle(value?.isEmpty == false ? th.ink3 : th.ink4)
                Image(systemName: "chevron.down")
                    .font(.system(size: 6.5, weight: .semibold))
                    .foregroundStyle(th.ink4)
                    .opacity(hover ? 1 : 0)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(hover ? th.hover : Color.clear)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { hover = $0 }
    }
}

/// Tag chip.
///
/// Deliberately no per-tag colors: that needs a color assignment scheme, while tags are free text
/// with no cap on count, so colors would collide quickly. Use one neutral color and let the text differ.
struct TagChip: View {
    @Environment(\.theme) var th
    let text: String
    var onRemove: (() -> Void)?
    @State private var hover = false

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(Metric.micro)
                .foregroundStyle(th.ink2)
                .lineLimit(1)
            if let onRemove, hover {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(th.ink3)
                }
                .buttonStyle(.plain)
                .help(L[.removeTag])
                .accessibilityLabel(L[.removeTag])
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: Metric.radiusSm)
                .fill(th.hover)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metric.radiusSm)
                .strokeBorder(th.line)
        )
        .onHover { hover = $0 }
        .accessibilityLabel(text)
    }
}

/// Tag row on cards. Space is tight, so show only the first few and fold the rest into +N.
struct TagRow: View {
    @Environment(\.theme) var th
    let tags: [String]
    var limit = 3

    var body: some View {
        if !tags.isEmpty {
            HStack(spacing: 4) {
                ForEach(tags.prefix(limit), id: \.self) { TagChip(text: $0) }
                if tags.count > limit {
                    Text("+\(tags.count - limit)")
                        .font(Metric.micro)
                        .foregroundStyle(th.ink3)
                }
            }
        }
    }
}

/// Wrapping horizontal layout. Tag count and length are unbounded: fixed column widths clip content
/// and an HStack overflows the panel, so lay out line by line by available width.
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = layout(subviews: subviews, width: width)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in layout(subviews: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: bounds.minY + row.y),
                    proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func layout(subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        var x: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            // At least one item per line, otherwise an oversized tag produces an endless run of empty lines
            if !row.indices.isEmpty && x + size.width > width {
                rows.append(row)
                row = Row(y: row.y + row.height + spacing)
                x = 0
            }
            row.indices.append(index)
            row.height = max(row.height, size.height)
            x += size.width + spacing
            row.width = x - spacing
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}
