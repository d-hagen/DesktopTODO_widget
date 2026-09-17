import AppKit
import SwiftUI

/// Debug aid: `ToDo --render list.md out.png [fontSize]` renders a widget for that file to a PNG
/// without touching the user's widgets or files.
enum OffscreenRender {
    static func run(markdown: String, png: String, fontSize: Double) -> Int32 {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)

        let config = WidgetConfig(
            id: UUID(), filePath: markdown, colorHex: WidgetSettings.defaultColor.hexString,
            fontSize: fontSize, frameName: "render", hidden: false)
        let settings = WidgetSettings(config: config)
        let store = Store(fileURL: URL(fileURLWithPath: markdown))
        let registry = WidgetRegistry(loadingWidgets: false)
        let root = RootView(store: store, settings: settings, registry: registry, hide: {}, remove: {})

        let frame = NSRect(x: 0, y: 0, width: 340, height: 600)
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        let host = NSHostingView(rootView: root)
        host.frame = frame
        window.contentView = host
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        host.layoutSubtreeIfNeeded()

        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return 1 }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return 1 }
        do {
            try data.write(to: URL(fileURLWithPath: png))
        } catch {
            print("render failed: \(error)")
            return 1
        }
        return 0
    }
}
