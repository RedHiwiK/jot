import AppKit
import SwiftUI
import Testing
@testable import Jot

@MainActor
struct ShortcutRecorderTests {
    @Test func clickThenCommandKeyIsCapturedAndEscapeCancels() throws {
        var active = false
        var captured: ShortcutBinding?
        let coordinator = ShortcutCaptureView.Coordinator(
            active: Binding(get: { active }, set: { active = $0 }),
            onCapture: { captured = $0 })
        let view = ShortcutCaptureView.CaptureNSView()
        view.coordinator = coordinator
        let click = try #require(NSEvent.mouseEvent(with: .leftMouseDown,
            location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
            context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
        view.mouseDown(with: click)
        #expect(active)
        let command = try #require(NSEvent.keyEvent(with: .keyDown,
            location: .zero, modifierFlags: [.command], timestamp: 0,
            windowNumber: 0, context: nil, characters: "f",
            charactersIgnoringModifiers: "f", isARepeat: false, keyCode: 3))
        #expect(view.performKeyEquivalent(with: command))
        #expect(captured == ShortcutBinding(key: "f", modifiers: [.command]))
        #expect(!active)
        captured = nil
        view.mouseDown(with: click)
        let escape = try #require(NSEvent.keyEvent(with: .keyDown,
            location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, characters: "\u{1b}",
            charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53))
        view.keyDown(with: escape)
        #expect(!active)
        #expect(captured == nil)
    }
}
