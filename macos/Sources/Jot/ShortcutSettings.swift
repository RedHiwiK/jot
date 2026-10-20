import AppKit
import SwiftUI

struct ShortcutSettings: View {
    @EnvironmentObject var shortcuts: ShortcutStore
    @Environment(\.theme) var th

    @State private var conflict: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                  VStack(spacing: 0) {
                    ForEach(ShortcutAction.allCases.filter { $0.projectIndex == nil }) { action in
                        shortcutRow(action)
                        if action != .back { HLine() }
                    }
                }
                .background(th.card, in: RoundedRectangle(cornerRadius: Metric.radiusSm))
                .overlay {
                    RoundedRectangle(cornerRadius: Metric.radiusSm).strokeBorder(th.line)
                }
                }
                .padding(.horizontal, 24).padding(.bottom, 24)
            }

            HLine()
            HStack {
                if let conflict {
                    Text(conflict)
                        .font(Metric.micro)
                        .foregroundStyle(th.danger)
                        .lineLimit(2)
                }
                Spacer()
                Button(L[.shortcutReset]) {
                    shortcuts.reset()
                    conflict = nil
                }
                .buttonStyle(FlatButton(compact: true))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
    }

    private func shortcutRow(_ action: ShortcutAction) -> some View {
        HStack(spacing: 12) {
            if action.projectIndex == nil {
              Image(systemName: icon(for: action))
                .font(.system(size: 14, weight: .regular))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(th.ink3)
                .frame(width: 18)
            }
            Text(action.projectIndex.map { "\($0 + 1)" } ?? action.title)
                .font(Metric.body)
                .foregroundStyle(th.ink2)
            Spacer(minLength: 12)
            ShortcutRecorder(binding: shortcuts.binding(for: action)) { candidate in
                if let other = shortcuts.conflictingAction(for: candidate, excluding: action) {
                    conflict = L[.shortcutConflict, other.title]
                    NSSound.beep()
                } else {
                    shortcuts.set(candidate, for: action)
                    conflict = nil
                }
            }
            .frame(width: 92, height: 28)
        }
        .padding(.horizontal, 13)
        .frame(height: 48)
    }

    private func icon(for action: ShortcutAction) -> String {
        switch action {
        case .board: return "rectangle.split.3x1"
        case .inbox: return ReqState.inbox.symbol
        case .inProgress: return ReqState.inProgress.symbol
        case .onHold: return ReqState.onHold.symbol
        case .done: return ReqState.done.symbol
        case .search: return "magnifyingglass"
        case .refresh: return "arrow.clockwise"
        case .inspector: return "sidebar.right"
        case .back: return "chevron.backward"
        default: return "folder"
        }
    }
}

struct ShortcutRecorder: View {
    @EnvironmentObject var shortcuts: ShortcutStore
    @Environment(\.theme) var th
    let binding: ShortcutBinding
    let onCapture: (ShortcutBinding) -> Void

    @State private var recording = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Metric.radiusSm)
                .fill(recording ? th.selected : th.elevated)
            RoundedRectangle(cornerRadius: Metric.radiusSm)
                .strokeBorder(recording ? th.accent.opacity(0.65) : th.line)
            Text(recording ? "⌨ …" : binding.display)
                .font(Metric.monoSm.weight(.medium))
                .foregroundStyle(recording ? th.accent : th.ink2)
            ShortcutCaptureView(active: $recording, onCapture: onCapture)
        }
        .contentShape(Rectangle())
        .onChange(of: recording) { _, active in shortcuts.setRecording(active) }
        .onDisappear { shortcuts.setRecording(false) }
        .help("Click to record a shortcut; Esc cancels")
    }
}

struct ShortcutCaptureView: NSViewRepresentable {
    @Binding var active: Bool
    let onCapture: (ShortcutBinding) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(active: $active, onCapture: onCapture)
    }

    func makeNSView(context: Context) -> CaptureNSView {
        let view = CaptureNSView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ view: CaptureNSView, context: Context) {
        context.coordinator.active = $active
        context.coordinator.onCapture = onCapture
        view.isActive = active
        if active, view.window?.firstResponder !== view {
            DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        }
    }

    final class Coordinator {
        var active: Binding<Bool>
        var onCapture: (ShortcutBinding) -> Void

        init(active: Binding<Bool>, onCapture: @escaping (ShortcutBinding) -> Void) {
            self.active = active
            self.onCapture = onCapture
        }
    }

    final class CaptureNSView: NSView {
        weak var coordinator: Coordinator?
        var isActive = false

        override var acceptsFirstResponder: Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
            isActive = true
            coordinator?.active.wrappedValue = true
        }

        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            guard isActive else { return false }
            keyDown(with: event)
            return true
        }

        override func keyDown(with event: NSEvent) {
            guard isActive else { super.keyDown(with: event); return }
            if event.keyCode == 53 {
                coordinator?.active.wrappedValue = false
                return
            }
            guard let binding = ShortcutBinding.from(event) else {
                NSSound.beep()
                return
            }
            coordinator?.onCapture(binding)
            coordinator?.active.wrappedValue = false
        }

        override func resignFirstResponder() -> Bool {
            coordinator?.active.wrappedValue = false
            return super.resignFirstResponder()
        }
    }
}
