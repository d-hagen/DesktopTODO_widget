import AppKit

if CommandLine.arguments.contains("--selftest") {
    exit(SelfTest.run())
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
