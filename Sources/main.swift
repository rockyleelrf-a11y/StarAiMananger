import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // pure menu bar app, hidden from dock

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
