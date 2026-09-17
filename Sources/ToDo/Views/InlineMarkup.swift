import AppKit

/// Inline styling inside a line: `*bold*` renders bold, `°kursiv°` renders italic.
/// Markers stay in the text (and in the file) but are drawn dimmed.
enum InlineMarkup {
    private static let bold = #/\*([^*\n]+?)\*/#
    private static let italic = #/°([^°\n]+?)°/#

    static func baseAttributes(font: NSFont, color: NSColor, strikethrough: Bool) -> [NSAttributedString.Key: Any] {
        var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        if strikethrough {
            attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            attrs[.strikethroughColor] = color
        }
        return attrs
    }

    static func styled(_ text: String, font: NSFont, color: NSColor, strikethrough: Bool) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text)
        restyle(result, font: font, color: color, strikethrough: strikethrough)
        return result
    }

    /// Re-applies attributes in place without changing characters, so it is safe on a live text storage.
    static func restyle(_ storage: NSMutableAttributedString, font: NSFont, color: NSColor, strikethrough: Bool) {
        let text = storage.string
        let whole = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.setAttributes(baseAttributes(font: font, color: color, strikethrough: strikethrough), range: whole)
        let manager = NSFontManager.shared
        let markerColor = color.withAlphaComponent(0.35)

        for m in text.matches(of: bold) {
            let content = NSRange(m.1.startIndex..<m.1.endIndex, in: text)
            let full = NSRange(m.range, in: text)
            storage.addAttribute(.font, value: manager.convert(font, toHaveTrait: .boldFontMask), range: content)
            dim(storage, full: full, content: content, color: markerColor)
        }
        for m in text.matches(of: italic) {
            let content = NSRange(m.1.startIndex..<m.1.endIndex, in: text)
            let full = NSRange(m.range, in: text)
            storage.enumerateAttribute(.font, in: content) { value, range, _ in
                let current = value as? NSFont ?? font
                storage.addAttribute(.font, value: manager.convert(current, toHaveTrait: .italicFontMask), range: range)
            }
            dim(storage, full: full, content: content, color: markerColor)
        }
        storage.endEditing()
    }

    private static func dim(_ storage: NSMutableAttributedString, full: NSRange, content: NSRange, color: NSColor) {
        let open = NSRange(location: full.location, length: content.location - full.location)
        let closeStart = content.location + content.length
        let close = NSRange(location: closeStart, length: full.location + full.length - closeStart)
        storage.addAttribute(.foregroundColor, value: color, range: open)
        storage.addAttribute(.foregroundColor, value: color, range: close)
    }
}
