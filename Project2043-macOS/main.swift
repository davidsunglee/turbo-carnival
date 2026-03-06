import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

let mainMenu = NSMenu()
let appMenuItem = NSMenuItem()
mainMenu.addItem(appMenuItem)
let appMenu = NSMenu()
appMenu.addItem(NSMenuItem(
    title: "Quit Project 2043",
    action: #selector(NSApplication.terminate(_:)),
    keyEquivalent: "q"
))
appMenuItem.submenu = appMenu
app.mainMenu = mainMenu

app.run()
