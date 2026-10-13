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
        Button(Localization.string("New Task")) { store.appendItem() }
        Button(Localization.string("New Section")) { store.appendSection() }
        Button(Localization.string("Clear Completed")) { store.clearCompleted() }
        Divider()
        Menu(String(format: Localization.string("Text Size (%d)"), Int(settings.fontSize))) {
            Button(Localization.string("Larger")) { settings.adjustFont(by: WidgetSettings.fontStep) }
                .disabled(settings.fontSize >= WidgetSettings.fontRange.upperBound)
            Button(Localization.string("Smaller")) { settings.adjustFont(by: -WidgetSettings.fontStep) }
                .disabled(settings.fontSize <= WidgetSettings.fontRange.lowerBound)
            Button(String(format: Localization.string("Default (%d)"), Int(WidgetSettings.defaultFontSize))) { settings.resetFont() }
        }
        Button(Localization.string("Color…")) { settings.showColorPanel() }
        Button(String(format: Localization.string("Open %@"), settings.fileURL.lastPathComponent)) { NSWorkspace.shared.open(settings.fileURL) }
        Button(Localization.string("Choose File…")) { chooseFile() }
        Divider()
        Button(Localization.string("New Widget")) { registry.addWidget() }
        Button(Localization.string("Remove This Widget…")) { remove() }
        Toggle(Localization.string("Launch at Login"), isOn: Binding(
            get: { registry.launchAtLogin },
            set: { registry.setLaunchAtLogin($0) }
        ))
        Divider()
        Button(Localization.string("Hide Widget")) { hide() }
        Button(Localization.string("Quit ToDo")) { NSApp.terminate(nil) }
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
