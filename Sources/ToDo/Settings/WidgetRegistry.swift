import AppKit
import Combine

/// Owns every widget: loads and saves their configs, creates their controllers, handles global actions.
final class WidgetRegistry: ObservableObject {
    @Published private(set) var controllers: [WidgetController] = []
    @Published var launchAtLogin: Bool = LoginItem.isEnabled

    private let defaults = UserDefaults.standard
    private let key = "widgets"
    private var snapshotSignal: DispatchSourceSignal?
    private var scriptSignal: DispatchSourceSignal?
    private var debugScript: DebugScript?

    static let supportDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/ToDo")

    /// `loadingWidgets: false` gives an empty registry for offscreen rendering (`--render`).
    init(loadingWidgets: Bool = true) {
        guard loadingWidgets else { return }
        var configs = loadConfigs()
        if configs.isEmpty { configs = [migratedOrDefaultConfig()] }
        for config in configs { controllers.append(makeController(config)) }
        persist()
        for c in controllers where !c.settings.hidden { c.show() }
        installDebugSignals()
    }

    // MARK: Persistence

    private func loadConfigs() -> [WidgetConfig] {
        guard let data = defaults.data(forKey: key),
              let configs = try? JSONDecoder().decode([WidgetConfig].self, from: data) else { return [] }
        return configs
    }

    /// First run after the single-widget version: keep its color, file and window position.
    private func migratedOrDefaultConfig() -> WidgetConfig {
        let legacyColor = defaults.string(forKey: "backgroundColorHex")
        let legacyPath = defaults.string(forKey: "filePath")
        let path = (legacyPath?.isEmpty == false) ? legacyPath! : nextFileURL().path
        return WidgetConfig(
            id: UUID(),
            filePath: path,
            colorHex: legacyColor ?? WidgetSettings.defaultColor.hexString,
            fontSize: Double(WidgetSettings.defaultFontSize),
            frameName: "ToDoWidget",
            hidden: false
        )
    }

    func persist() {
        let configs = controllers.map { $0.settings.config }
        if let data = try? JSONEncoder().encode(configs) { defaults.set(data, forKey: key) }
    }

    private func makeController(_ config: WidgetConfig) -> WidgetController {
        let settings = WidgetSettings(config: config)
        settings.onChange = { [weak self] _ in self?.persist() }
        return WidgetController(settings: settings, registry: self)
    }

    /// todo.md, todo-2.md, todo-3.md … whichever is not used by an existing widget.
    private func nextFileURL() -> URL {
        let used = Set(controllers.map { $0.settings.fileURL.path })
        var n = 1
        while true {
            let name = n == 1 ? "todo.md" : "todo-\(n).md"
            let url = WidgetRegistry.supportDir.appendingPathComponent(name)
            if !used.contains(url.path) { return url }
            n += 1
        }
    }

    // MARK: Widgets

    @discardableResult
    func addWidget() -> WidgetController {
        let config = WidgetConfig(
            id: UUID(),
            filePath: nextFileURL().path,
            colorHex: WidgetSettings.defaultColor.hexString,
            fontSize: Double(WidgetSettings.defaultFontSize),
            frameName: "ToDoWidget-\(UUID().uuidString)",
            hidden: false
        )
        let controller = makeController(config)
        if let last = controllers.last {
            var frame = last.window.frame
            frame.origin.x -= 40
            frame.origin.y -= 40
            controller.window.setFrame(frame, display: false)
        }
        controllers.append(controller)
        persist()
        controller.show()
        return controller
    }

    func confirmRemove(_ controller: WidgetController) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Remove the “\(controller.title)” widget?"
        alert.informativeText = "The list file stays at \(controller.settings.fileURL.path). Only the widget and its color, size and position are removed."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        alert.window.level = .floating
        if alert.runModal() == .alertFirstButtonReturn { remove(controller) }
    }

    func remove(_ controller: WidgetController) {
        controller.close()
        NSWindow.removeFrame(usingName: controller.settings.frameName)
        controllers.removeAll { $0 === controller }
        persist()
    }

    func controller(for window: NSWindow?) -> WidgetController? {
        guard let window else { return nil }
        return controllers.first { $0.window === window }
    }

    /// Target for global shortcuts: the key widget, else the first visible one, else the first.
    var activeController: WidgetController? {
        controller(for: NSApp.keyWindow) ?? controllers.first { $0.isVisible } ?? controllers.first
    }

    func showAll() {
        for c in controllers { c.show() }
    }

    func saveAll() {
        for c in controllers { c.store.saveNow() }
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            try LoginItem.set(on)
        } catch {
            NSLog("ToDo: login item change failed: \(error)")
        }
        launchAtLogin = LoginItem.isEnabled
    }

    // MARK: Debug hooks (see README)

    private func installDebugSignals() {
        signal(SIGUSR1, SIG_IGN)
        let snap = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        snap.setEventHandler { [weak self] in self?.activeController?.writeSnapshot() }
        snap.resume()
        snapshotSignal = snap

        // The scripted session edits the live list, so it is only armed with `--debug-script`.
        guard CommandLine.arguments.contains("--debug-script") else { return }
        signal(SIGUSR2, SIG_IGN)
        let script = DispatchSource.makeSignalSource(signal: SIGUSR2, queue: .main)
        script.setEventHandler { [weak self] in
            guard let self, let c = self.activeController else { return }
            self.debugScript = DebugScript(window: c.window, store: c.store)
            self.debugScript?.run()
        }
        script.resume()
        scriptSignal = script
    }
}
