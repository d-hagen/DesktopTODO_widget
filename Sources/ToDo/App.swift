import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var registry: WidgetRegistry!
    private var statusItem: StatusItemController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.mainMenu = MainMenu.build(delegate: self)
        registry = WidgetRegistry()
        statusItem = StatusItemController(registry: registry)
    }

    func applicationWillTerminate(_ notification: Notification) {
        registry.saveAll()
    }

    @objc func newTask(_ sender: Any?) {
        guard let c = registry.activeController else { return }
        c.show()
        c.store.appendItem()
    }

    @objc func newWidget(_ sender: Any?) {
        registry.addWidget()
    }

    @objc func showAllWidgets(_ sender: Any?) {
        registry.showAll()
    }

    @objc func largerText(_ sender: Any?) {
        registry.activeController?.settings.adjustFont(by: WidgetSettings.fontStep)
    }

    @objc func smallerText(_ sender: Any?) {
        registry.activeController?.settings.adjustFont(by: -WidgetSettings.fontStep)
    }

    @objc func resetText(_ sender: Any?) {
        registry.activeController?.settings.resetFont()
    }
}
