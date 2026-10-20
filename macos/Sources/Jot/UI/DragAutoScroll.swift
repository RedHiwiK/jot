import AppKit
import SwiftUI

/// Scroll the column under the pointer, with speed increasing near its edges.
struct DragAutoScroll: NSViewRepresentable {
    let active: Bool

    func makeNSView(context: Context) -> Driver { Driver() }
    func updateNSView(_ view: Driver, context: Context) { view.active = active }
    static func dismantleNSView(_ view: Driver, coordinator: ()) { view.stop() }

    final class Driver: NSView {
        var timer: Timer?
        var active = false {
            didSet {
                guard active != oldValue else { return }
                if active {
                    timer = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in
                        MainActor.assumeIsolated { self?.tick() }
                    }
                    RunLoop.main.add(timer!, forMode: .common)
                } else { stop() }
            }
        }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        func stop() { timer?.invalidate(); timer = nil }
        func tick() {
            guard NSApp.isActive, let scroll = enclosingScrollView,
                  let window, let document = scroll.documentView else { return }
            let clip = scroll.contentView
            let point = clip.convert(window.mouseLocationOutsideOfEventStream, from: nil)
            let bounds = clip.bounds
            guard point.x >= bounds.minX, point.x <= bounds.maxX else { return }
            let band = min(64.0, bounds.height * 0.15)
            let localY = point.y - bounds.minY
            var speed: CGFloat = 0
            if localY < band { speed = -min(1, max(0, (band - localY) / band)) }
            else if localY > bounds.height - band { speed = min(1, (localY - bounds.height + band) / band) }
            guard speed != 0 else { return }
            let maximum = max(0, document.bounds.height - bounds.height)
            let y = min(maximum, max(0, bounds.minY + speed * abs(speed) * 12))
            guard abs(y - bounds.minY) > 0.1 else { return }
            clip.scroll(to: NSPoint(x: bounds.minX, y: y))
            scroll.reflectScrolledClipView(clip)
        }
    }
}
