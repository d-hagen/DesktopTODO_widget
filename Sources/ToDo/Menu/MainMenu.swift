import AppKit

/// Invisible main menu (the app has no menu bar) so ⌘ shortcuts route correctly.
enum MainMenu {
    static func build(delegate: AppDelegate) -> NSMenu {
        let main = NSMenu()

        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: Localization.string("Quit ToDo"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let fileItem = NSMenuItem()
        main.addItem(fileItem)
        let file = NSMenu(title: Localization.string("File"))
        fileItem.submenu = file
        add(file, Localization.string("New Task"), #selector(AppDelegate.newTask(_:)), "n", delegate)
        add(file, Localization.string("New Widget"), #selector(AppDelegate.newWidget(_:)), "N", delegate)
        add(file, Localization.string("Show All Widgets"), #selector(AppDelegate.showAllWidgets(_:)), "", delegate)

        let editItem = NSMenuItem()
        main.addItem(editItem)
        let edit = NSMenu(title: Localization.string("Edit"))
        editItem.submenu = edit
        edit.addItem(withTitle: Localization.string("Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: Localization.string("Redo"), action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: Localization.string("Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: Localization.string("Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: Localization.string("Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: Localization.string("Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let viewItem = NSMenuItem()
        main.addItem(viewItem)
        let view = NSMenu(title: Localization.string("View"))
        viewItem.submenu = view
        add(view, Localization.string("Larger Text"), #selector(AppDelegate.largerText(_:)), "=", delegate)
        add(view, Localization.string("Smaller Text"), #selector(AppDelegate.smallerText(_:)), "-", delegate)
        add(view, Localization.string("Default Text Size"), #selector(AppDelegate.resetText(_:)), "0", delegate)

        return main
    }

    private static func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String, _ target: AnyObject) {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
        item.target = target
    }
}
