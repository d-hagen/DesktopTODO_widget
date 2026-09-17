import Foundation

/// One line inside a section: a checkbox task or a plain note line.
struct Item: Identifiable, Equatable {
    var id = UUID()
    var text: String
    var isTask: Bool = true
    var done: Bool = false
    var doneAt: Date? = nil
    var from: String? = nil

    var markdown: String {
        guard isTask else { return text }
        var line = "- [\(done ? "x" : " ")] \(text)"
        if let doneAt { line += " @done(\(Document.dateFormatter.string(from: doneAt)))" }
        if let from, !from.isEmpty { line += " @from(\(from))" }
        return line
    }
}

struct Section: Identifiable, Equatable {
    var id = UUID()
    /// nil = the unnamed block of items before the first `##` heading.
    var title: String?
    var items: [Item] = []

    static let doneTitle = "Done"

    var isDone: Bool {
        guard let title else { return false }
        return title.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(Section.doneTitle) == .orderedSame
    }
}

struct Document: Equatable {
    static let titleID = UUID()
    static let defaultTitle = "TO DO:"

    var title: String
    var sections: [Section]

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    static let starter = Document(
        title: defaultTitle,
        sections: [
            Section(title: nil, items: [
                Item(text: "Click a line to edit it"),
                Item(text: "Press Enter for a new task"),
                Item(text: "Type ## Name and press Enter for a header"),
            ]),
        ]
    )

    // MARK: Parsing

    private static let headingPattern = #/^(#{1,6})\s+(.*?)\s*$/#
    private static let taskPattern = #/^\s*[-*+]\s+\[([ xX])\]\s?(.*?)\s*$/#
    private static let donePattern = #/\s*@done\(([^)]*)\)/#
    private static let fromPattern = #/\s*@from\(([^)]*)\)/#

    static func parse(_ text: String) -> Document {
        var title: String?
        var sections: [Section] = []
        var current = Section(title: nil)
        var seenAnything = false

        func flush() {
            if current.title != nil || !current.items.isEmpty { sections.append(current) }
        }

        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if let m = line.wholeMatch(of: headingPattern) {
                let level = m.1.count
                let heading = String(m.2)
                if level == 1, title == nil, !seenAnything {
                    title = heading
                    seenAnything = true
                    continue
                }
                flush()
                current = Section(title: heading)
            } else if let m = line.wholeMatch(of: taskPattern) {
                var body = String(m.2)
                var item = Item(text: "", isTask: true, done: m.1 != " ")
                if let d = body.firstMatch(of: donePattern) {
                    item.doneAt = dateFormatter.date(from: String(d.1).trimmingCharacters(in: .whitespaces))
                    body.removeSubrange(d.range)
                }
                if let f = body.firstMatch(of: fromPattern) {
                    item.from = String(f.1).trimmingCharacters(in: .whitespaces)
                    body.removeSubrange(f.range)
                }
                item.text = body.trimmingCharacters(in: .whitespaces)
                current.items.append(item)
            } else {
                current.items.append(Item(text: line, isTask: false))
            }
            seenAnything = true
        }
        flush()
        return Document(title: title ?? defaultTitle, sections: sections)
    }

    // MARK: Serialization

    func serialized() -> String {
        var out = "# \(title.isEmpty ? Document.defaultTitle : title)\n"
        for section in sections {
            out += "\n"
            if let t = section.title { out += "## \(t)\n" }
            for item in section.items {
                if item.isTask, item.text.trimmingCharacters(in: .whitespaces).isEmpty { continue }
                out += item.markdown + "\n"
            }
        }
        return out
    }

    // MARK: Lookup

    func location(of id: UUID) -> (section: Int, item: Int)? {
        for (s, section) in sections.enumerated() {
            if let i = section.items.firstIndex(where: { $0.id == id }) { return (s, i) }
        }
        return nil
    }

    func item(_ id: UUID) -> Item? {
        guard let loc = location(of: id) else { return nil }
        return sections[loc.section].items[loc.item]
    }

    func sectionIndex(of id: UUID) -> Int? {
        sections.firstIndex { $0.id == id }
    }

    var doneIndex: Int? { sections.firstIndex { $0.isDone } }

    /// Editable rows in visual order: title, then each section's header (Done's is fixed) and items.
    var editableIDs: [UUID] {
        var ids = [Document.titleID]
        for section in sections {
            if section.title != nil, !section.isDone { ids.append(section.id) }
            ids += section.items.map(\.id)
        }
        return ids
    }

    func previousEditable(before id: UUID) -> UUID? {
        let ids = editableIDs
        guard let i = ids.firstIndex(of: id), i > 0 else { return nil }
        return ids[i - 1]
    }

    func nextEditable(after id: UUID) -> UUID? {
        let ids = editableIDs
        guard let i = ids.firstIndex(of: id), i + 1 < ids.count else { return nil }
        return ids[i + 1]
    }

    // MARK: Mutation

    mutating func setText(_ id: UUID, _ text: String) {
        let clean = text.replacingOccurrences(of: "\n", with: " ")
        if id == Document.titleID { title = clean; return }
        if let loc = location(of: id) { sections[loc.section].items[loc.item].text = clean; return }
        if let s = sectionIndex(of: id) { sections[s].title = clean }
    }

    /// Index of the last section that is not Done, creating an unnamed one if needed.
    private mutating func lastOpenSectionIndex() -> Int {
        if let i = sections.lastIndex(where: { !$0.isDone }) { return i }
        sections.insert(Section(title: nil), at: 0)
        return 0
    }

    private mutating func firstOpenSectionIndex() -> Int {
        if let i = sections.firstIndex(where: { !$0.isDone }) { return i }
        sections.insert(Section(title: nil), at: 0)
        return 0
    }

    @discardableResult
    mutating func insertItem(after id: UUID) -> UUID? {
        guard let loc = location(of: id) else { return nil }
        let item = Item(text: "")
        sections[loc.section].items.insert(item, at: loc.item + 1)
        return item.id
    }

    @discardableResult
    mutating func insertItem(atStartOfSection sectionID: UUID) -> UUID? {
        guard let s = sectionIndex(of: sectionID) else { return nil }
        let item = Item(text: "")
        sections[s].items.insert(item, at: 0)
        return item.id
    }

    @discardableResult
    mutating func insertItemAtTop() -> UUID {
        let s = firstOpenSectionIndex()
        let item = Item(text: "")
        sections[s].items.insert(item, at: 0)
        return item.id
    }

    @discardableResult
    mutating func appendItem() -> UUID {
        let s = lastOpenSectionIndex()
        let item = Item(text: "")
        sections[s].items.append(item)
        return item.id
    }

    @discardableResult
    mutating func appendSection(title: String) -> UUID {
        let section = Section(title: title)
        if let d = doneIndex {
            sections.insert(section, at: d)
        } else {
            sections.append(section)
        }
        return section.id
    }

    mutating func deleteItem(_ id: UUID) {
        guard let loc = location(of: id) else { return }
        sections[loc.section].items.remove(at: loc.item)
        pruneEmptyDone()
    }

    /// Turns an item into a `##` header. Items after it in the same section move under the new header.
    @discardableResult
    mutating func convertToSection(_ id: UUID, title: String) -> UUID? {
        guard let loc = location(of: id) else { return nil }
        var section = sections[loc.section]
        let following = Array(section.items[(loc.item + 1)...])
        section.items.removeSubrange(loc.item...)
        sections[loc.section] = section
        let newSection = Section(title: title, items: following)
        sections.insert(newSection, at: loc.section + 1)
        if sections[loc.section].title == nil, sections[loc.section].items.isEmpty {
            sections.remove(at: loc.section)
        }
        return newSection.id
    }

    /// Removes a header; its items join the previous section (or become the unnamed top block).
    mutating func deleteSection(_ id: UUID) {
        guard let s = sectionIndex(of: id), !sections[s].isDone else { return }
        let items = sections[s].items
        sections.remove(at: s)
        if items.isEmpty { return }
        if s > 0, !sections[s - 1].isDone {
            sections[s - 1].items += items
        } else if s == 0 {
            sections.insert(Section(title: nil, items: items), at: 0)
        } else {
            sections.insert(Section(title: nil, items: items), at: s)
        }
    }

    private mutating func ensureDoneSection() -> Int {
        if let d = doneIndex {
            if d != sections.count - 1 {
                let done = sections.remove(at: d)
                sections.append(done)
            }
            return sections.count - 1
        }
        sections.append(Section(title: Section.doneTitle))
        return sections.count - 1
    }

    private mutating func pruneEmptyDone() {
        if let d = doneIndex, sections[d].items.isEmpty { sections.remove(at: d) }
    }

    /// Check → move to Done with a timestamp. Uncheck → move back to the origin section.
    mutating func toggle(_ id: UUID, now: Date = Date()) {
        guard let loc = location(of: id) else { return }
        var item = sections[loc.section].items[loc.item]
        guard item.isTask else { return }

        if sections[loc.section].isDone || item.done {
            sections[loc.section].items.remove(at: loc.item)
            let origin = item.from
            item.done = false
            item.doneAt = nil
            item.from = nil
            let target: Int
            if let origin, let t = sections.firstIndex(where: { $0.title == origin && !$0.isDone }) {
                target = t
            } else {
                target = firstOpenSectionIndex()
            }
            sections[target].items.append(item)
            pruneEmptyDone()
        } else {
            sections[loc.section].items.remove(at: loc.item)
            item.done = true
            item.doneAt = now
            item.from = sections[loc.section].title
            let d = ensureDoneSection()
            sections[d].items.append(item)
        }
    }

    /// Makes an externally edited file consistent. Returns true if anything changed.
    @discardableResult
    mutating func normalize(now: Date = Date()) -> Bool {
        let before = self
        // Done items outside Done move into Done.
        var moved: [Item] = []
        for s in sections.indices where !sections[s].isDone {
            let origin = sections[s].title
            let done = sections[s].items.filter { $0.isTask && $0.done }
            if done.isEmpty { continue }
            sections[s].items.removeAll { $0.isTask && $0.done }
            moved += done.map { var i = $0; i.doneAt = i.doneAt ?? now; i.from = i.from ?? origin; return i }
        }
        if !moved.isEmpty {
            let d = ensureDoneSection()
            sections[d].items += moved
        }
        // Items in Done are always done and stamped.
        if let d = doneIndex {
            for i in sections[d].items.indices where sections[d].items[i].isTask {
                sections[d].items[i].done = true
                if sections[d].items[i].doneAt == nil { sections[d].items[i].doneAt = now }
            }
            if d != sections.count - 1 { _ = ensureDoneSection() }
        }
        pruneEmptyDone()
        return self != before
    }

    /// Deletes Done items completed more than `maxAge` ago. Returns true if anything changed.
    @discardableResult
    mutating func purge(now: Date = Date(), maxAge: TimeInterval) -> Bool {
        guard let d = doneIndex else { return false }
        let before = sections[d].items.count
        sections[d].items.removeAll { item in
            guard item.isTask, let at = item.doneAt else { return false }
            return now.timeIntervalSince(at) > maxAge
        }
        let changed = sections[d].items.count != before
        pruneEmptyDone()
        return changed
    }

    mutating func clearCompleted() {
        for s in sections.indices { sections[s].items.removeAll { $0.isTask && $0.done } }
        pruneEmptyDone()
    }
}
