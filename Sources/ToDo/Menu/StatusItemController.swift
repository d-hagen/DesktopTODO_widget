import AppKit

final class StatusItemController: NSObject, NSMenuDelegate {
    private let item: NSStatusItem
    private let registry: WidgetRegistry
    private let menu = NSMenu()

    init(registry: WidgetRegistry) {
        self.registry = registry
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "To Do")
        }
        menu.delegate = self
        item.menu = menu
    }

    /// Rebuilt on every open so it reflects the current widgets and their titles.
    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        for controller in registry.controllers {
            let title = "\(controller.isVisible ? "Hide" : "Show") “\(controller.title)”"
            let entry = NSMenuItem(title: title, action: #selector(toggleWidget(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = controller
            menu.addItem(entry)
        }
        menu.addItem(.separator())
        let newTask = menu.addItem(withTitle: "New Task", action: #selector(newTask), keyEquivalent: "")
        newTask.target = self
        let newWidget = menu.addItem(withTitle: "New Widget", action: #selector(newWidget), keyEquivalent: "")
        newWidget.target = self
        if registry.controllers.count > 1 {
            let showAll = menu.addItem(withTitle: "Show All Widgets", action: #selector(showAll), keyEquivalent: "")
            showAll.target = self
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit ToDo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    @objc private func toggleWidget(_ sender: NSMenuItem) {
        (sender.representedObject as? WidgetController)?.toggle()
    }

    @objc private func newTask() {
        guard let c = registry.activeController else { return }
        c.show()
        c.store.appendItem()
    }

    @objc private func newWidget() {
        registry.addWidget()
    }

    @objc private func showAll() {
        registry.showAll()
    }
}
