import AppKit

/// Inline styling inside a line: `*bold*` renders bold, `_kursiv_` renders italic.
/// The markers are kept in the model and the file. While a line is edited they are shown dimmed;
/// otherwise they are hidden, like a markdown editor.
enum InlineMarkup {
    private static let bold = #/\*([^*\n]+?)\*/#
    private static let italic = #/_([^_\n]+?)_(?!\w)/#

    static func baseAttributes(font: NSFont, color: NSColor, strikethrough: Bool) -> [NSAttributedString.Key: Any] {
        var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        if strikethrough {
            attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            attrs[.strikethroughColor] = color
        }
        return attrs
    }

    /// Styled copy of `text`. With `showMarkers` false the `*` and `_` markers are removed.
    static func styled(_ text: String, font: NSFont, color: NSColor, strikethrough: Bool,
                       showMarkers: Bool) -> NSAttributedString {
        let result = NSMutableAttributedString(
            string: text, attributes: baseAttributes(font: font, color: color, strikethrough: strikethrough))
        applyPass(result, regex: bold, trait: .boldFontMask, fallback: font, markerColor: color, showMarkers: showMarkers)
        applyPass(result, regex: italic, trait: .italicFontMask, fallback: font, markerColor: color, showMarkers: showMarkers)
        return result
    }

    /// Re-applies attributes in place (markers shown) without changing characters,
    /// so it is safe on a live text storage while typing.
    static func restyle(_ storage: NSMutableAttributedString, font: NSFont, color: NSColor, strikethrough: Bool) {
        let whole = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.setAttributes(baseAttributes(font: font, color: color, strikethrough: strikethrough), range: whole)
        applyPass(storage, regex: bold, trait: .boldFontMask, fallback: font, markerColor: color, showMarkers: true)
        applyPass(storage, regex: italic, trait: .italicFontMask, fallback: font, markerColor: color, showMarkers: true)
        storage.endEditing()
    }

    private static func applyPass(_ storage: NSMutableAttributedString, regex: Regex<(Substring, Substring)>,
                                  trait: NSFontTraitMask, fallback: NSFont, markerColor: NSColor, showMarkers: Bool) {
        let text = storage.string
        let manager = NSFontManager.shared
        let dim = markerColor.withAlphaComponent(0.35)
        // Walk matches back to front so removals do not shift the ranges still to be processed.
        for m in text.matches(of: regex).reversed() {
            let full = NSRange(m.range, in: text)
            let content = NSRange(m.1.startIndex..<m.1.endIndex, in: text)
            if trait == .italicFontMask, full.location > 0 {
                // `_` inside a word (snake_case) is not a marker.
                let before = (text as NSString).character(at: full.location - 1)
                if CharacterSet.alphanumerics.contains(UnicodeScalar(before)!) { continue }
            }
            let open = NSRange(location: full.location, length: content.location - full.location)
            let closeStart = content.location + content.length
            let close = NSRange(location: closeStart, length: full.location + full.length - closeStart)

            storage.enumerateAttribute(.font, in: content) { value, range, _ in
                let current = value as? NSFont ?? fallback
                storage.addAttribute(.font, value: manager.convert(current, toHaveTrait: trait), range: range)
            }
            if showMarkers {
                storage.addAttribute(.foregroundColor, value: dim, range: open)
                storage.addAttribute(.foregroundColor, value: dim, range: close)
            } else {
                storage.deleteCharacters(in: close)
                storage.deleteCharacters(in: open)
            }
        }
    }
}
