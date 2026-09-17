import AppKit

if CommandLine.arguments.contains("--selftest") {
    exit(SelfTest.run())
}

if let i = CommandLine.arguments.firstIndex(of: "--render"), CommandLine.arguments.count > i + 2 {
    exit(OffscreenRender.run(markdown: CommandLine.arguments[i + 1], png: CommandLine.arguments[i + 2],
                             fontSize: Double(CommandLine.arguments.dropFirst(i + 3).first ?? "") ?? 20))
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
