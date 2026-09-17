import AppKit
import Combine

/// Persisted description of one widget.
struct WidgetConfig: Codable, Equatable {
    var id: UUID
    var filePath: String
    var colorHex: String
    var fontSize: Double
    var frameName: String
    var hidden: Bool
}

/// Live, observable settings of one widget. Changes are pushed back to the registry via `onChange`.
final class WidgetSettings: ObservableObject {
    static let defaultColor = NSColor(srgbRed: 188 / 255, green: 107 / 255, blue: 192 / 255, alpha: 1)
    static let defaultFontSize: CGFloat = 20
    static let fontRange: ClosedRange<CGFloat> = 12...40
    static let fontStep: CGFloat = 2

    let id: UUID
    let frameName: String
    @Published var backgroundColor: NSColor { didSet { changed() } }
    @Published var fontSize: CGFloat { didSet { changed() } }
    @Published var fileURL: URL { didSet { changed() } }
    var hidden: Bool { didSet { changed() } }

    var onChange: ((WidgetConfig) -> Void)?

    init(config: WidgetConfig) {
        id = config.id
        frameName = config.frameName
        backgroundColor = NSColor(hex: config.colorHex) ?? WidgetSettings.defaultColor
        fontSize = CGFloat(config.fontSize).clamped(to: WidgetSettings.fontRange)
        fileURL = URL(fileURLWithPath: config.filePath)
        hidden = config.hidden
    }

    var config: WidgetConfig {
        WidgetConfig(
            id: id,
            filePath: fileURL.path,
            colorHex: backgroundColor.hexString,
            fontSize: Double(fontSize),
            frameName: frameName,
            hidden: hidden
        )
    }

    private func changed() { onChange?(config) }

    /// Black or white, whichever reads better on the background.
    var foregroundColor: NSColor {
        let c = backgroundColor.usingColorSpace(.sRGB) ?? backgroundColor
        let lum = 0.2126 * c.redComponent + 0.7152 * c.greenComponent + 0.0722 * c.blueComponent
        return lum > 0.45 ? .black : .white
    }

    var theme: Theme { Theme(base: fontSize) }

    func adjustFont(by delta: CGFloat) {
        fontSize = (fontSize + delta).clamped(to: WidgetSettings.fontRange)
    }

    func resetFont() {
        fontSize = WidgetSettings.defaultFontSize
    }

    // MARK: Color panel

    private lazy var colorBridge = ColorPanelBridge { [weak self] color in
        self?.backgroundColor = color
    }

    func showColorPanel() {
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.color = backgroundColor
        panel.setTarget(colorBridge)
        panel.setAction(#selector(ColorPanelBridge.changeColor(_:)))
        panel.isContinuous = true
        panel.level = .floating
        panel.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class ColorPanelBridge: NSObject {
    private let handler: (NSColor) -> Void
    init(handler: @escaping (NSColor) -> Void) { self.handler = handler }

    @objc func changeColor(_ sender: NSColorPanel) {
        handler(sender.color)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

extension NSColor {
    var hexString: String {
        let c = usingColorSpace(.sRGB) ?? self
        let r = Int(round(c.redComponent * 255))
        let g = Int(round(c.greenComponent * 255))
        let b = Int(round(c.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(
            srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
            green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255,
            alpha: 1
        )
    }
}
