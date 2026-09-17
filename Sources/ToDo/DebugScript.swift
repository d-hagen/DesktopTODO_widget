import AppKit

/// Debug aid, triggered by `kill -USR2 <pid>`: drives the real AppKit text fields through a
/// scripted editing session (type, Enter, header conversion, Backspace, Up/Down, Esc, toggle)
/// so the focus and delegate logic can be exercised without Accessibility permission.
/// Writes progress to $TMPDIR/todo-debug.log.
final class DebugScript {
    private let window: NSWindow
    private let store: Store
    private var steps: [() -> Void] = []
    private var log: [String] = []

    init(window: NSWindow, store: Store) {
        self.window = window
        self.store = store
    }

    private func field(for id: UUID) -> RowTextField? {
        func find(_ v: NSView) -> RowTextField? {
            if let f = v as? RowTextField, f.rowID == id { return f }
            for sub in v.subviews { if let f = find(sub) { return f } }
            return nil
        }
        return window.contentView.flatMap(find)
    }

    private func editor() -> NSTextView? {
        window.firstResponder as? NSTextView
    }

    private func focusedID() -> UUID? {
        (editor()?.delegate as? RowTextField)?.rowID
    }

    private func note(_ s: String) { log.append(s) }

    private func type(_ text: String) {
        editor()?.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    private func command(_ sel: Selector) {
        editor()?.doCommand(by: sel)
    }

    func run() {
        log = []
        let firstItem = store.doc.sections.first?.items.first?.id
        steps = [
            { [self] in
                note("focus first item via store.focusID")
                store.focusID = firstItem
            },
            { [self] in
                note("focused=\(focusedID() == firstItem) key=\(window.isKeyWindow)")
                command(#selector(NSResponder.moveToEndOfLine(_:)))
                command(#selector(NSResponder.insertNewline(_:)))
            },
            { [self] in
                note("after Enter: focused new empty item = \(focusedID() != nil && focusedID() != firstItem)")
                type("Buy milk")
                command(#selector(NSResponder.insertNewline(_:)))
            },
            { [self] in
                type("## Work")
                command(#selector(NSResponder.insertNewline(_:)))
            },
            { [self] in
                note("after header: sections=\(store.doc.sections.map { $0.title ?? "-" })")
                type("Ship widget")
                command(#selector(NSResponder.insertNewline(_:)))
            },
            { [self] in
                note("empty item focused=\(focusedID() != nil)")
                command(#selector(NSResponder.deleteBackward(_:)))
            },
            { [self] in
                note("after backspace-on-empty: focused text='\(editor()?.string ?? "nil")'")
                command(#selector(NSResponder.moveUp(_:)))
            },
            { [self] in
                note("after Up: focused text='\(editor()?.string ?? "nil")'")
                command(#selector(NSResponder.moveDown(_:)))
            },
            { [self] in
                note("after Down: focused text='\(editor()?.string ?? "nil")'")
                command(#selector(NSResponder.cancelOperation(_:)))
            },
            { [self] in
                note("after Esc: firstResponder is textview = \(editor() != nil)")
                if let id = store.doc.sections.first?.items.first?.id { store.toggle(id) }
            },
            { [self] in
                let doneID = store.doc.doneIndex.flatMap { store.doc.sections[$0].items.last?.id }
                note("done item present=\(doneID != nil)")
                store.focusID = doneID
            },
            { [self] in
                note("done item focused=\(focusedID() != nil) text='\(editor()?.string ?? "nil")'")
                command(#selector(NSResponder.selectAll(_:)))
                command(#selector(NSResponder.deleteBackward(_:)))
            },
            { [self] in
                note("after clearing done text: editor text='\(editor()?.string ?? "nil")'")
                command(#selector(NSResponder.deleteBackward(_:)))
            },
            { [self] in
                note("after backspace on empty done item: Done section exists=\(store.doc.doneIndex != nil)")
            },
            { [self] in
                store.saveNow()
                note("final sections=\(store.doc.sections.map { "\($0.title ?? "-"):\($0.items.map(\.text))" })")
                let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("todo-debug.log")
                try? log.joined(separator: "\n").appending("\n").write(to: url, atomically: true, encoding: .utf8)
            },
        ]
        next()
    }

    private func next() {
        guard !steps.isEmpty else { return }
        let step = steps.removeFirst()
        step()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in self?.next() }
    }
}
