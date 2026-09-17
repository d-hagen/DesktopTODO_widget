import AppKit
import SwiftUI

/// Fonts and sizes derived from one base text size (the widget's "Text Size" setting).
struct Theme {
    let base: CGFloat

    static let cornerRadius: CGFloat = 16
    static let sidePadding: CGFloat = 28

    var title: NSFont { Theme.font(size: round(base * 1.7), weight: .heavy) }
    var header: NSFont { Theme.font(size: round(base * 1.05), weight: .bold) }
    var item: NSFont { Theme.font(size: base, weight: .regular) }
    var checkbox: CGFloat { round(base * 1.3) }
    var rowSpacing: CGFloat { round(base * 0.1) }
    var sectionSpacing: CGFloat { round(base * 1.1) }

    static func font(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let name: String
        switch weight {
        case .heavy, .black: name = "AvenirNext-Heavy"
        case .bold, .semibold: name = "AvenirNext-Bold"
        case .medium: name = "AvenirNext-Medium"
        default: name = "AvenirNext-Regular"
        }
        return NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
    }
}
