import AppKit
import Combine

enum FieldKind { case title, header, item }

/// Owns the document, persistence, file watching, and focus requests for the UI.
final class Store: ObservableObject {
    @Published private(set) var doc: Document
    /// Set to ask the matching text field to become first responder.
    @Published var focusID: UUID?
    @Published private(set) var fileURL: URL

    let maxDoneAge: TimeInterval = 24 * 3600

    private var lastSavedText: String?
    private var saveWork: DispatchWorkItem?
    private var watcher: FileWatcher?
    private var purgeTimer: Timer?
    private var editingID: UUID?
    private var pendingReload = false

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.doc = Document(title: Document.defaultTitle, sections: [])
        load()
        watcher = FileWatcher(url: fileURL) { [weak self] in self?.reloadIfChanged() }
        purgeTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            self?.purgeNow()
        }
    }

    // MARK: Persistence

    private func load() {
        if let text = try? String(contentsOf: fileURL, encoding: .utf8) {
            doc = Document.parse(text)
            lastSavedText = text
        } else {
            doc = Document.starter
            lastSavedText = nil
        }
        var changed = doc.normalize()
        changed = doc.purge(maxAge: maxDoneAge) || changed
        if changed || lastSavedText == nil { saveNow() }
    }

    private func reloadIfChanged() {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        if text == lastSavedText { return }
        if editingID != nil {
            pendingReload = true
            return
        }
        pendingReload = false
        doc = Document.parse(text)
        lastSavedText = text
        if doc.normalize() || doc.purge(maxAge: maxDoneAge) { scheduleSave() }
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    func saveNow() {
        saveWork?.cancel()
        saveWork = nil
        let text = doc.serialized()
        if text == lastSavedText { return }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.data(using: .utf8)!.write(to: fileURL, options: .atomic)
            lastSavedText = text
        } catch {
            NSLog("ToDo: save failed: \(error)")
        }
    }

    func switchFile(to url: URL) {
        saveNow()
        fileURL = url
        editingID = nil
        pendingReload = false
        load()
        watcher = FileWatcher(url: url) { [weak self] in self?.reloadIfChanged() }
    }

    private func purgeNow() {
        if doc.purge(maxAge: maxDoneAge) { scheduleSave() }
    }

    private func mutate(_ body: (inout Document) -> Void) {
        body(&doc)
        scheduleSave()
    }

    // MARK: Actions from the UI

    func toggle(_ id: UUID) {
        mutate { $0.toggle(id) }
    }

    func appendItem() {
        var id: UUID?
        mutate { id = $0.appendItem() }
        focusID = id
    }

    func appendSection() {
        var id: UUID?
        mutate { id = $0.appendSection(title: "New section") }
        focusID = id
    }

    func clearCompleted() {
        mutate { $0.clearCompleted() }
    }

    func updateText(_ id: UUID, _ text: String) {
        mutate { $0.setText(id, text) }
    }

    func beganEditing(_ id: UUID) {
        editingID = id
    }

    func endedEditing(_ id: UUID, kind: FieldKind, text: String) {
        if editingID == id { editingID = nil }
        if kind == .item, let item = doc.item(id), item.isTask {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    self?.mutate { $0.deleteItem(id) }
                }
            } else if !item.done, let heading = headerTitle(from: trimmed) {
                DispatchQueue.main.async { [weak self] in
                    self?.mutate { $0.convertToSection(id, title: heading) }
                }
            }
        }
        if pendingReload, editingID == nil {
            DispatchQueue.main.async { [weak self] in self?.reloadIfChanged() }
        }
    }

    func windowLostFocus() {
        saveNow()
        if pendingReload {
            editingID = nil
            reloadIfChanged()
        }
    }

    /// Enter pressed in a field.
    func handleEnter(_ id: UUID, kind: FieldKind, text: String, endEditing: () -> Void) {
        switch kind {
        case .title:
            var newID: UUID?
            mutate { newID = $0.insertItemAtTop() }
            focusID = newID
        case .header:
            var newID: UUID?
            mutate { newID = $0.insertItem(atStartOfSection: id) }
            focusID = newID
        case .item:
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            if doc.item(id)?.done == true {
                endEditing()
            } else if let heading = headerTitle(from: trimmed) {
                var newID: UUID?
                mutate {
                    if let sid = $0.convertToSection(id, title: heading) {
                        newID = $0.insertItem(atStartOfSection: sid)
                    }
                }
                focusID = newID
            } else if trimmed.isEmpty {
                endEditing()
            } else {
                var newID: UUID?
                mutate { newID = $0.insertItem(after: id) }
                focusID = newID
            }
        }
    }

    private func headerTitle(from text: String) -> String? {
        guard let m = text.wholeMatch(of: #/^#{1,6}\s*(.*?)\s*$/#) else { return nil }
        let t = String(m.1)
        return t.isEmpty ? nil : t
    }

    /// Backspace pressed in an empty field.
    func handleDeleteEmpty(_ id: UUID, kind: FieldKind) {
        switch kind {
        case .title:
            return
        case .header:
            let prev = doc.previousEditable(before: id)
            mutate { $0.deleteSection(id) }
            focusID = prev
        case .item:
            let prev = doc.previousEditable(before: id)
            mutate { $0.deleteItem(id) }
            focusID = prev
        }
    }

    func focusPrevious(_ id: UUID) {
        if let prev = doc.previousEditable(before: id) { focusID = prev }
    }

    func focusNext(_ id: UUID) {
        if let next = doc.nextEditable(after: id) { focusID = next }
    }
}
