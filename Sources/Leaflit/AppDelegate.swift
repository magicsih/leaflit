import AppKit
import UniformTypeIdentifiers
import LeaflitCore

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var readers: [ReaderController] = []
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate(); app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
    func applicationWillFinishLaunching(_ notification: Notification) { buildMenus() }
    func applicationDidFinishLaunching(_ notification: Notification) {
        if readers.isEmpty { newWindow(nil) }
        NSApp.activate(ignoringOtherApps: true)
    }
    func application(_ sender: NSApplication, open urls: [URL]) { open(urls) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { newWindow(nil) }; return true
    }
    func open(_ urls: [URL]) {
        for raw in urls {
            let url = DocumentPath.canonical(raw)
            guard DocumentPath.isMarkdown(url) else { continue }
            if let existing = readers.first(where: { $0.documentURL == url }) { existing.showWindow(nil); existing.window?.makeKeyAndOrderFront(nil); continue }
            let reader = readers.first(where: { $0.documentURL == nil }) ?? makeReader()
            reader.open(url); reader.showWindow(nil); reader.window?.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    @discardableResult private func makeReader() -> ReaderController {
        let reader = ReaderController()
        readers.append(reader)
        reader.onClose = { [weak self, weak reader] in self?.readers.removeAll { $0 === reader } }
        reader.openFiles = { [weak self] in self?.open($0) }
        reader.canNavigate = { [weak self, weak reader] url in
            if let existing = self?.readers.first(where: { $0 !== reader && $0.documentURL == url }) {
                existing.window?.makeKeyAndOrderFront(nil); return false
            }
            return true
        }
        return reader
    }
    @objc func newWindow(_ sender: Any?) { makeReader().showWindow(nil) }
    @objc func openPanel(_ sender: Any?) {
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = true
        panel.allowedContentTypes = ["md", "markdown", "mdown"].compactMap { UTType(filenameExtension: $0) }
        panel.message = "Choose a Markdown file to read."
        if panel.runModal() == .OK { open(panel.urls) }
    }
    private var activeReader: ReaderController? {
        for window in [NSApp.keyWindow, NSApp.mainWindow] {
            if let reader = window?.delegate as? ReaderController { return reader }
        }
        return nil
    }
    @objc func find(_ sender: Any?) { activeReader?.showFind() }
    @objc func findNext(_ sender: Any?) { activeReader?.findNext() }
    @objc func findPrevious(_ sender: Any?) { activeReader?.findPrevious() }
    @objc func back(_ sender: Any?) { activeReader?.goBack() }
    @objc func zoomIn(_ sender: Any?) { activeReader?.zoomIn() }
    @objc func zoomOut(_ sender: Any?) { activeReader?.zoomOut() }
    @objc func actualSize(_ sender: Any?) { activeReader?.actualSize() }
    private func buildMenus() {
        let main = NSMenu(); NSApp.mainMenu = main
        func menu(_ title: String) -> NSMenu {
            let item = NSMenuItem(); item.title = title; let menu = NSMenu(title: title); item.submenu = menu; main.addItem(item); return menu
        }
        func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String = "", target: AnyObject? = nil, modifiers: NSEvent.ModifierFlags = .command) {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key); item.target = target; item.keyEquivalentModifierMask = modifiers; menu.addItem(item)
        }
        let app = menu("Leaflit")
        add(app, "About Leaflit", #selector(NSApplication.orderFrontStandardAboutPanel(_:)), target: NSApp)
        app.addItem(.separator()); add(app, "Hide Leaflit", #selector(NSApplication.hide(_:)), "h", target: NSApp)
        app.addItem(.separator()); add(app, "Quit Leaflit", #selector(NSApplication.terminate(_:)), "q", target: NSApp)
        let file = menu("File")
        add(file, "New Window", #selector(newWindow(_:)), "n", target: self)
        add(file, "Open…", #selector(openPanel(_:)), "o", target: self)
        file.addItem(.separator()); add(file, "Close Window", #selector(NSWindow.performClose(_:)), "w")
        let edit = menu("Edit")
        add(edit, "Cut", #selector(NSText.cut(_:)), "x")
        add(edit, "Copy", #selector(NSText.copy(_:)), "c")
        add(edit, "Paste", #selector(NSText.paste(_:)), "v")
        add(edit, "Select All", #selector(NSText.selectAll(_:)), "a")
        edit.addItem(.separator()); add(edit, "Find…", #selector(find(_:)), "f", target: self)
        add(edit, "Find Next", #selector(findNext(_:)), "g", target: self)
        add(edit, "Find Previous", #selector(findPrevious(_:)), "g", target: self, modifiers: [.command, .shift])
        let view = menu("View")
        add(view, "Back", #selector(back(_:)), "[", target: self)
        view.addItem(.separator()); add(view, "Zoom In", #selector(zoomIn(_:)), "+", target: self)
        add(view, "Zoom Out", #selector(zoomOut(_:)), "-", target: self)
        add(view, "Actual Size", #selector(actualSize(_:)), "0", target: self)
        let windows = menu("Window"); NSApp.windowsMenu = windows
        add(windows, "Minimize", #selector(NSWindow.performMiniaturize(_:)), "m")
        add(windows, "Zoom", #selector(NSWindow.performZoom(_:)))
    }
}
