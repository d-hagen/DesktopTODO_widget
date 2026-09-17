import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct WidgetMenuItems: View {
    @ObservedObject var store: Store
    @ObservedObject var settings: WidgetSettings
    @ObservedObject var registry: WidgetRegistry
    let hide: () -> Void
    let remove: () -> Void

    var body: some View {
        Button("New Task") { store.appendItem() }
        Button("New Section") { store.appendSection() }
        Button("Clear Completed") { store.clearCompleted() }
        Divider()
        Menu("Text Size (\(Int(settings.fontSize)))") {
            Button("Larger") { settings.adjustFont(by: WidgetSettings.fontStep) }
                .disabled(settings.fontSize >= WidgetSettings.fontRange.upperBound)
            Button("Smaller") { settings.adjustFont(by: -WidgetSettings.fontStep) }
                .disabled(settings.fontSize <= WidgetSettings.fontRange.lowerBound)
            Button("Default (\(Int(WidgetSettings.defaultFontSize)))") { settings.resetFont() }
        }
        Button("Color…") { settings.showColorPanel() }
        Button("Open \(settings.fileURL.lastPathComponent)") { NSWorkspace.shared.open(settings.fileURL) }
        Button("Choose File…") { chooseFile() }
        Divider()
        Button("New Widget") { registry.addWidget() }
        Button("Remove This Widget…") { remove() }
        Toggle("Launch at Login", isOn: Binding(
            get: { registry.launchAtLogin },
            set: { registry.setLaunchAtLogin($0) }
        ))
        Divider()
        Button("Hide Widget") { hide() }
        Button("Quit ToDo") { NSApp.terminate(nil) }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        var types: [UTType] = [.plainText, .text]
        if let md = UTType("net.daringfireball.markdown") { types.insert(md, at: 0) }
        panel.allowedContentTypes = types
        panel.directoryURL = settings.fileURL.deletingLastPathComponent()
        panel.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            settings.fileURL = url
        }
    }
}
