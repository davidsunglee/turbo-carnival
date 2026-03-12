import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let rect = NSRect(x: 0, y: 0, width: 540, height: 960)
        window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        let metalView = MetalView(frame: rect)
        window.contentView = metalView
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.title = "Project 2043"
        window.minSize = NSSize(width: 360, height: 640)
        window.makeFirstResponder(metalView)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
