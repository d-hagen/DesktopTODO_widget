import AppKit
import Combine
import SwiftUI

final class WidgetController {
    let settings: WidgetSettings
    let store: Store
    let window: DesktopWindow
    private var observers: [NSObjectProtocol] = []
    private var cancellables: Set<AnyCancellable> = []

    init(settings: WidgetSettings, registry: WidgetRegistry) {
        self.settings = settings
        store = Store(fileURL: settings.fileURL)

        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = NSSize(width: 340, height: 450)
        let origin = NSPoint(x: screen.maxX - size.width - 40, y: screen.maxY - size.height - 40)
        window = DesktopWindow(contentRect: NSRect(origin: origin, size: size))

        let root = RootView(
            store: store,
            settings: settings,
            registry: registry,
            hide: { [weak self] in self?.hide() },
            remove: { [weak self, weak registry] in
                guard let self, let registry else { return }
                registry.confirmRemove(self)
            }
        )
        let hosting = WidgetHostingView(rootView: root)
        hosting.wantsLayer = true
        window.contentView = hosting
        window.setFrameAutosaveName(settings.frameName)

        observers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: window, queue: .main
        ) { [weak self] _ in
            self?.store.windowLostFocus()
        })

        settings.$fileURL
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] url in self?.store.switchFile(to: url) }
            .store(in: &cancellables)
    }

    var title: String {
        let t = store.doc.title.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? settings.fileURL.lastPathComponent : t
    }

    var isVisible: Bool { window.isVisible }

    func show() {
        settings.hidden = false
        window.makeKeyAndOrderFront(nil)
    }

    func hide() {
        window.makeFirstResponder(nil)
        store.saveNow()
        window.orderOut(nil)
        settings.hidden = true
    }

    func toggle() {
        if isVisible { hide() } else { show() }
    }

    func close() {
        window.makeFirstResponder(nil)
        store.saveNow()
        window.orderOut(nil)
        for o in observers { NotificationCenter.default.removeObserver(o) }
        observers.removeAll()
    }

    /// Debug aid: renders the widget to $TMPDIR/todo-snapshot.png.
    func writeSnapshot() {
        guard let view = window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("todo-snapshot.png")
        try? rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:])?.write(to: url)
    }
}

/// Lets the first click on the (usually inactive) widget reach SwiftUI controls.
final class WidgetHostingView: NSHostingView<RootView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
