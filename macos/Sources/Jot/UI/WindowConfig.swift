import SwiftUI
import AppKit

/// Window behavior configuration.
///
/// .hiddenTitleBar also kills system gestures such as double-click-to-zoom and drag-to-move,
/// so keep the title bar but make it transparent: same clean look, all gestures intact.
struct WindowConfigurator: NSViewRepresentable {
    let background: NSColor
    // Weak window identity survives SwiftUI view recreation (e.g. language changes).
    private static let sizedWindows = NSHashTable<NSWindow>.weakObjects()

    func makeNSView(context: Context) -> NSView {
        let v = WindowAttachmentView()
        v.configure = configure
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? WindowAttachmentView)?.configure = configure
        DispatchQueue.main.async { configure(nsView.window) }
    }

    private final class WindowAttachmentView: NSView {
        var configure: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            configure?(window)
            // SwiftUI may apply its window defaults after attachment.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.configure?(self.window)
            }
        }
    }

    private func configure(_ window: NSWindow?) {
        guard let w = window else { return }
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        // Extend the background beneath the transparent titlebar. SwiftUI's
        // safe area keeps the workspace below the native window controls.
        w.styleMask.insert(.fullSizeContentView)
        // Must stay off: window background dragging conflicts with the board cards' DragGesture,
        // making the whole app move while dragging a card. Window moving is handled by the TitleBarDragArea at the top
        w.isMovableByWindowBackground = false
        w.standardWindowButton(.zoomButton)?.isEnabled = true
        w.collectionBehavior.insert(.fullScreenPrimary)
        // Key point: the window's own background follows the theme.
        // Otherwise the title bar strip shows the desktop wallpaper through
        w.backgroundColor = background
        w.isOpaque = true

        // The main window uses a custom-drawn top bar and keeps no system toolbar.
        // Setting only isVisible=false can still leave a system toolbar item on macOS 26
        // (a purple capsule button in the top-left), so the toolbar must be removed entirely here.
        w.toolbar = nil
        w.titlebarSeparatorStyle = .none
        if !Self.sizedWindows.contains(w) {
            Self.sizedWindows.add(w)
            DispatchQueue.main.async { [weak w] in
                guard let w, !w.styleMask.contains(.fullScreen),
                      let screen = w.screen ?? NSScreen.main else { return }
                w.setFrame(screen.visibleFrame, display: true)
            }
        }
    }
}

extension View {
    func configureWindow(background: Color) -> some View {
        self.background(
            WindowConfigurator(background: NSColor(background))
                .frame(width: 0, height: 0)
        )
    }
}

/// Top bar area that zooms on double-click.
/// The custom top bar covers the system title bar, so the double-click gesture must be forwarded manually.
struct TitleBarDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        /// Must be transparent, otherwise it covers the background SwiftUI draws
        /// and leaves a gap of system background color at the top of the sidebar
        override var isOpaque: Bool { false }
        override func draw(_ dirtyRect: NSRect) {}

        override func mouseDown(with event: NSEvent) {
            guard let w = window else { return }
            if event.clickCount == 2 {
                // Follow the system "double-click title bar" preference: zoom / minimize.
                // Read NSGlobalDomain rather than standard: this is a global preference,
                // and standard doesn't contain it unless this app has overridden it (it is empty in practice)
                let action = UserDefaults.standard
                    .persistentDomain(forName: UserDefaults.globalDomain)?["AppleActionOnDoubleClick"] as? String
                switch action {
                case "Minimize": w.miniaturize(nil)
                case "None":     break
                default:         w.zoom(nil)
                }
                return
            }
            // performDrag blocks until the mouse is released, so the second click of a double-click never arrives,
            // which shows up as the window nudging up on click but never zooming on double-click.
            // Wait a very short interval for a second click first, and only then start dragging.
            if let next = w.nextEvent(matching: [.leftMouseUp, .leftMouseDragged],
                                      until: .now + NSEvent.doubleClickInterval,
                                      inMode: .eventTracking, dequeue: true),
               next.type == .leftMouseUp {
                // Just a click, no drag: don't start a window drag
                return
            }
            w.performDrag(with: event)
        }
    }
}

/// Settings window appearance and behavior.
///
/// Two things:
///   1. The Settings scene locks the window to the content's intrinsic size by default; giving
///      maxWidth: .infinity on the SwiftUI side doesn't help, as styleMask lacks .resizable.
///   2. Without configuring the title bar, the system default background shows through
///      and doesn't meet the theme's dark content area (an abrupt light band).
struct SettingsWindow: NSViewRepresentable {
    let background: NSColor

    final class Coordinator {
        var resized = false
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async { configure(v.window) }
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(nsView.window)
            guard let window = nsView.window, !context.coordinator.resized else { return }
            context.coordinator.resized = true
            let key = "jot.settings.largeWindow.v1"
            guard !UserDefaults.standard.bool(forKey: key) else { return }
            let screen = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
            let width = min(1040, (screen?.width ?? 1100) - 40)
            let height = min(760, (screen?.height ?? 840) - 80)
            window.setContentSize(NSSize(width: width, height: height))
            window.center()
            UserDefaults.standard.set(true, forKey: key)
        }
    }

    private func configure(_ window: NSWindow?) {
        guard let w = window else { return }
        w.styleMask.insert(.resizable)
        w.standardWindowButton(.zoomButton)?.isEnabled = true

        // Blend the title bar into the content. Keep the title text: the settings window needs it to identify itself,
        // whereas hiding it completely like the main window would make the panel unrecognizable
        w.titlebarAppearsTransparent = true
        w.backgroundColor = background
        w.isOpaque = true
        w.titlebarSeparatorStyle = .none
    }
}

extension View {
    func configureSettingsWindow(background: Color) -> some View {
        self.background(
            SettingsWindow(background: NSColor(background))
                .frame(width: 0, height: 0)
        )
    }
}
