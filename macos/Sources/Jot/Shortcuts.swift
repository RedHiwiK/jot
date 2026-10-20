import AppKit
import SwiftUI

enum ShortcutAction: String, CaseIterable, Codable, Identifiable {
    case board
    case inbox
    case inProgress
    case onHold
    case done
    case search
    case refresh
    case inspector
    case back
    case project1, project2, project3, project4, project5, project6, project7, project8, project9

    var id: String { rawValue }

    @MainActor var title: String {
        switch self {
        case .board: return L[.shortcutBoard]
        case .inbox: return L[.shortcutInbox]
        case .inProgress: return L[.shortcutInProgress]
        case .onHold: return L[.shortcutReview]
        case .done: return L[.stDone]
        case .search: return L[.shortcutSearch]
        case .refresh: return L[.shortcutRefresh]
        case .inspector: return L[.shortcutInspector]
        case .back: return L[.shortcutBack]
        default: return "Project \(projectIndex! + 1)"
        }
    }

    var projectIndex: Int? {
        guard rawValue.hasPrefix("project"), let number = Int(rawValue.dropFirst(7)) else { return nil }
        return number - 1
    }

    var defaultBinding: ShortcutBinding {
        switch self {
        case .board: return .init(key: "1", modifiers: [.command])
        case .inbox: return .init(key: "2", modifiers: [.command])
        case .inProgress: return .init(key: "3", modifiers: [.command])
        case .onHold: return .init(key: "4", modifiers: [.command])
        case .done: return .init(key: "5", modifiers: [.command])
        case .search: return .init(key: "f", modifiers: [.command])
        case .refresh: return .init(key: "r", modifiers: [.command])
        case .inspector: return .init(key: "i", modifiers: [.command, .option])
        case .back: return .init(key: "[", modifiers: [.command])
        case .project1: return .init(key: "1", modifiers: [.option])
        case .project2: return .init(key: "2", modifiers: [.option])
        case .project3: return .init(key: "3", modifiers: [.option])
        case .project4: return .init(key: "4", modifiers: [.option])
        case .project5: return .init(key: "5", modifiers: [.option])
        case .project6: return .init(key: "6", modifiers: [.option])
        case .project7: return .init(key: "7", modifiers: [.option])
        case .project8: return .init(key: "8", modifiers: [.option])
        case .project9: return .init(key: "9", modifiers: [.option])
        }
    }
}

enum ShortcutModifier: String, Codable, CaseIterable {
    case command, option, control, shift
}

struct ShortcutBinding: Codable, Hashable {
    var key: String
    var modifiers: Set<ShortcutModifier>

    var keyEquivalent: KeyEquivalent {
        KeyEquivalent(Character(key.lowercased()))
    }

    var eventModifiers: EventModifiers {
        var result: EventModifiers = []
        if modifiers.contains(.command) { result.insert(.command) }
        if modifiers.contains(.option) { result.insert(.option) }
        if modifiers.contains(.control) { result.insert(.control) }
        if modifiers.contains(.shift) { result.insert(.shift) }
        return result
    }

    var display: String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        result += key.uppercased()
        return result
    }

    static func from(_ event: NSEvent) -> ShortcutBinding? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: Set<ShortcutModifier> = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        guard modifiers.contains(.command) || modifiers.contains(.option) || modifiers.contains(.control),
              let chars = event.charactersIgnoringModifiers?.lowercased(),
              chars.count == 1,
              let scalar = chars.unicodeScalars.first,
              !CharacterSet.controlCharacters.contains(scalar) else { return nil }
        return ShortcutBinding(key: chars, modifiers: modifiers)
    }
}

/// Preserve user bindings when obsolete actions are removed from the app.
private struct SavedShortcuts: Decodable {
    var bindings: [ShortcutAction: ShortcutBinding] = [:]

    init(from decoder: Decoder) throws {
        var values = try decoder.unkeyedContainer()
        while !values.isAtEnd {
            let key = try values.decode(String.self)
            let binding = try values.decode(ShortcutBinding.self)
            if let action = ShortcutAction(rawValue: key) { bindings[action] = binding }
        }
    }
}

@MainActor
final class ShortcutStore: ObservableObject {
    @Published private(set) var bindings: [ShortcutAction: ShortcutBinding]
    @Published private(set) var commandKeyDown = false
    @Published private(set) var optionKeyDown = false
    private(set) var isRecording = false

    private static let storageKey = "jot.shortcuts.v3"
    private let defaults: UserDefaults
    private var modifierMonitor: Any?
    private var keyMonitor: Any?
    private var resignObserver: NSObjectProtocol?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(SavedShortcuts.self, from: data).bindings {
            bindings = Dictionary(uniqueKeysWithValues: ShortcutAction.allCases.map {
                ($0, saved[$0] ?? $0.defaultBinding)
            })
        } else {
            bindings = Dictionary(uniqueKeysWithValues: ShortcutAction.allCases.map {
                ($0, $0.defaultBinding)
            })
        }
        modifierMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.commandKeyDown = NSApp.isActive && event.modifierFlags.contains(.command)
            self?.optionKeyDown = NSApp.isActive && event.modifierFlags.contains(.option)
            return event
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard NSApp.isActive, !self.isRecording, NSApp.keyWindow?.sheetParent == nil,
                  NSApp.keyWindow?.attachedSheet == nil else { return event }
            for action in ShortcutAction.allCases {
                if self.binding(for: action).matches(event) {
                    self.post(action)
                    return nil
                }
            }
            return event
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.commandKeyDown = false; self?.optionKeyDown = false }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.commandKeyDown = NSEvent.modifierFlags.contains(.command)
                self?.optionKeyDown = NSEvent.modifierFlags.contains(.option)
            }
        }
    }

    func binding(for action: ShortcutAction) -> ShortcutBinding {
        bindings[action] ?? action.defaultBinding
    }

    func conflictingAction(for binding: ShortcutBinding, excluding action: ShortcutAction) -> ShortcutAction? {
        bindings.first { $0.key != action && $0.value == binding }?.key
    }

    func set(_ binding: ShortcutBinding, for action: ShortcutAction) {
        bindings[action] = binding
        save()
    }

    func reset() {
        bindings = Dictionary(uniqueKeysWithValues: ShortcutAction.allCases.map {
            ($0, $0.defaultBinding)
        })
        save()
    }

    func setRecording(_ recording: Bool) {
        isRecording = recording
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(bindings) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private func post(_ action: ShortcutAction) {
        if let index = action.projectIndex {
            NotificationCenter.default.post(name: .shortcutProject1, object: nil, userInfo: ["index": index])
            return
        }
        let name: Notification.Name
        var info: [AnyHashable: Any]? = nil
        switch action {
        case .board: name = .shortcutBoard
        case .inbox: name = .shortcutInbox
        case .inProgress: name = .shortcutInProgress
        case .onHold: name = .shortcutReview
        case .done: name = .shortcutDone
        case .search: name = .focusSearch
        case .refresh: name = .shortcutRefresh
        case .inspector: name = .toggleInspector
        case .back: name = .shortcutBack
        case .project1: name = .shortcutProject1; info = ["index": 0]
        case .project2: name = .shortcutProject2; info = ["index": 1]
        case .project3: name = .shortcutProject3; info = ["index": 2]
        case .project4: name = .shortcutProject4; info = ["index": 3]
        case .project5: name = .shortcutProject5; info = ["index": 4]
        case .project6: name = .shortcutProject6; info = ["index": 5]
        case .project7: name = .shortcutProject7; info = ["index": 6]
        case .project8: name = .shortcutProject8; info = ["index": 7]
        case .project9: name = .shortcutProject9; info = ["index": 8]
        }
        NotificationCenter.default.post(name: name, object: nil, userInfo: info)
    }
}

struct AppShortcutCommands: Commands {
    @ObservedObject var state: AppState
    @ObservedObject var shortcuts: ShortcutStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) { }
        CommandGroup(after: .toolbar) {
            command(.search) { NotificationCenter.default.post(name: .focusSearch, object: nil) }
            command(.inspector) {
                NotificationCenter.default.post(name: .toggleInspector, object: nil)
            }
            .disabled(state.selectedReq == nil)
            command(.refresh) { state.refreshCurrentView() }
        }
    }

    private func command(_ action: ShortcutAction,
                         perform: @escaping () -> Void) -> some View {
        let binding = shortcuts.binding(for: action)
        return Button(action.title, action: perform)
            .keyboardShortcut(binding.keyEquivalent, modifiers: binding.eventModifiers)
    }
}

extension Notification.Name {
    static let focusSearch = Notification.Name("jot.focusSearch")
    static let toggleInspector = Notification.Name("jot.toggleInspector")
    static let shortcutBoard = Notification.Name("jot.shortcutBoard")
    static let shortcutInbox = Notification.Name("jot.shortcutInbox")
    static let shortcutReady = Notification.Name("jot.shortcutReady")
    static let shortcutInProgress = Notification.Name("jot.shortcutInProgress")
    static let shortcutDone = Notification.Name("jot.shortcutDone")
    static let shortcutReview = Notification.Name("jot.shortcutReview")
    static let shortcutRefresh = Notification.Name("jot.shortcutRefresh")
    static let shortcutBack = Notification.Name("jot.shortcutBack")
    static let shortcutProject1 = Notification.Name("jot.shortcutProject1")
    static let shortcutProject2 = Notification.Name("jot.shortcutProject2")
    static let shortcutProject3 = Notification.Name("jot.shortcutProject3")
    static let shortcutProject4 = Notification.Name("jot.shortcutProject4")
    static let shortcutProject5 = Notification.Name("jot.shortcutProject5")
    static let shortcutProject6 = Notification.Name("jot.shortcutProject6")
    static let shortcutProject7 = Notification.Name("jot.shortcutProject7")
    static let shortcutProject8 = Notification.Name("jot.shortcutProject8")
    static let shortcutProject9 = Notification.Name("jot.shortcutProject9")
}

private extension ShortcutBinding {
    func matches(_ event: NSEvent) -> Bool {
        guard let candidate = ShortcutBinding.from(event) else { return false }
        return candidate == self
    }
}
