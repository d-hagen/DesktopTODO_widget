import AppKit
import SwiftUI

final class RowTextField: NSTextField {
    var onAttach: (() -> Void)?
    var rowID: UUID?
    var styleKey = ""

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { onAttach?() }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
}

/// Single-line AppKit text field that reports Enter, Backspace-on-empty, Up, Down and Esc to the store.
struct EditableText: NSViewRepresentable {
    let id: UUID
    let kind: FieldKind
    let text: String
    let placeholder: String
    let font: NSFont
    let color: NSColor
    let strikethrough: Bool
    @ObservedObject var store: Store

    func makeNSView(context: Context) -> RowTextField {
        let field = RowTextField()
        field.delegate = context.coordinator
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.isEditable = true
        field.isSelectable = true
        field.allowsEditingTextAttributes = false
        field.cell?.isScrollable = false
        field.cell?.wraps = true
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = 0
        field.rowID = id
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.onAttach = { [weak field] in
            guard let field else { return }
            context.coordinator.focusIfRequested(field)
        }
        apply(to: field)
        return field
    }

    func updateNSView(_ field: RowTextField, context: Context) {
        context.coordinator.parent = self
        field.rowID = id
        apply(to: field)
        context.coordinator.focusIfRequested(field)
    }

    /// Wrap to the width SwiftUI offers and report the resulting height.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView field: RowTextField, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        field.preferredMaxLayoutWidth = width
        let bounds = NSRect(x: 0, y: 0, width: width, height: CGFloat.greatestFiniteMagnitude)
        let measured = field.stringValue.isEmpty ? placeholder : field.stringValue
        let cell = NSTextFieldCell(textCell: "")
        cell.font = font
        cell.wraps = true
        cell.lineBreakMode = .byWordWrapping
        cell.attributedStringValue = InlineMarkup.styled(measured, font: font, color: color, strikethrough: false)
        let height = ceil(cell.cellSize(forBounds: bounds).height)
        return CGSize(width: width, height: height)
    }

    private var styleKey: String { "\(font.fontName)/\(font.pointSize)/\(color.hexString)/\(strikethrough)" }

    private func apply(to field: RowTextField) {
        field.font = font
        field.textColor = color
        if field.stringValue != text || field.styleKey != styleKey {
            if let editor = field.currentEditor() as? NSTextView, field.stringValue == text, let storage = editor.textStorage {
                // Style changed while editing (e.g. text size): restyle in place to keep the caret.
                InlineMarkup.restyle(storage, font: font, color: color, strikethrough: strikethrough)
            } else {
                field.attributedStringValue = InlineMarkup.styled(text, font: font, color: color, strikethrough: strikethrough)
            }
            field.styleKey = styleKey
        }
        field.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [.font: font, .foregroundColor: color.withAlphaComponent(0.4)]
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: EditableText

        init(_ parent: EditableText) { self.parent = parent }

        func focusIfRequested(_ field: RowTextField) {
            guard parent.store.focusID == parent.id, let window = field.window else { return }
            let store = parent.store
            let id = parent.id
            DispatchQueue.main.async {
                guard store.focusID == id else { return }
                store.focusID = nil
                if !NSApp.isActive { NSApp.activate(ignoringOtherApps: true) }
                if !window.isKeyWindow { window.makeKeyAndOrderFront(nil) }
                window.makeFirstResponder(field)
                if let editor = field.currentEditor() {
                    let end = field.stringValue.utf16.count
                    editor.selectedRange = NSRange(location: end, length: 0)
                }
            }
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            parent.store.beganEditing(parent.id)
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            if let editor = field.currentEditor() as? NSTextView, let storage = editor.textStorage {
                InlineMarkup.restyle(storage, font: parent.font, color: parent.color, strikethrough: parent.strikethrough)
                editor.typingAttributes = InlineMarkup.baseAttributes(
                    font: parent.font, color: parent.color, strikethrough: parent.strikethrough)
            }
            parent.store.updateText(parent.id, field.stringValue)
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.store.endedEditing(parent.id, kind: parent.kind, text: field.stringValue)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            let store = parent.store
            let id = parent.id
            switch selector {
            case #selector(NSResponder.insertNewline(_:)):
                store.handleEnter(id, kind: parent.kind, text: textView.string) {
                    control.window?.makeFirstResponder(nil)
                }
                return true
            case #selector(NSResponder.deleteBackward(_:)):
                if textView.string.isEmpty {
                    store.handleDeleteEmpty(id, kind: parent.kind)
                    return true
                }
                return false
            case #selector(NSResponder.moveUp(_:)):
                store.focusPrevious(id)
                return true
            case #selector(NSResponder.moveDown(_:)):
                store.focusNext(id)
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                control.window?.makeFirstResponder(nil)
                return true
            default:
                return false
            }
        }
    }
}
