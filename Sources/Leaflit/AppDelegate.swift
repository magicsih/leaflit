import AppKit
import UniformTypeIdentifiers
import LeaflitCore

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private(set) var readers: [ReaderController] = []
    private var terminating = false
    init(readers: [ReaderController] = []) { self.readers = readers; super.init() }
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
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminating, !readers.contains(where: { $0.editing.isBusy }) else { return .terminateCancel }
        guard readers.contains(where: { $0.editing.isDirty || $0.editing.isBusy }) else { return .terminateNow }
        terminating = true
        resolveUnsavedDocuments { [weak self] accepted in
            self?.terminating = false; sender.reply(toApplicationShouldTerminate: accepted)
        }
        return .terminateLater
    }
    func resolveUnsavedDocuments(_ completion: @escaping (Bool) -> Void) {
        guard !readers.contains(where: { $0.editing.isBusy }) else { completion(false); return }
        guard let reader = readers.first(where: { $0.editing.isDirty }) else { completion(true); return }
        reader.window?.makeKeyAndOrderFront(nil)
        reader.editing.confirmBeforeLeaving { [weak self] accepted in
            guard accepted, let self else { completion(false); return }
            self.resolveUnsavedDocuments(completion)
        }
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
        for window in [NSApp.keyWindow, NSApp.mainWindow] + NSApp.orderedWindows.map({ Optional($0) }) {
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
    @objc func toggleSidebar(_ sender: Any?) { activeReader?.toggleSidebar() }
    @objc func openFolder(_ sender: Any?) { activeReader?.sidebar.openFolder() }
    @objc func saveDocument(_ sender: Any?) { activeReader?.saveDocument() }
    @objc func saveCopy(_ sender: Any?) { activeReader?.saveCopy() }
    @objc func showRead(_ sender: Any?) { activeReader?.showRead() }
    @objc func showSource(_ sender: Any?) { activeReader?.showSource() }
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(saveDocument(_:)): return activeReader?.editing.isDirty == true && activeReader?.editing.isBusy == false && activeReader?.editing.draft?.hasExternalChanges != true
        case #selector(saveCopy(_:)): return activeReader?.editing.draft != nil && activeReader?.editing.isBusy == false
        case #selector(showRead(_:)), #selector(showSource(_:)):
            let source = item.action == #selector(showSource(_:))
            item.state = activeReader?.editing.mode == (source ? .source : .read) ? .on : .off
            return activeReader?.documentURL != nil && activeReader?.editing.isBusy == false
        default: return true
        }
    }
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
        add(file, "Open Folder…", #selector(openFolder(_:)), "o", target: self, modifiers: [.command, .shift])
        file.addItem(.separator()); add(file, "Save", #selector(saveDocument(_:)), "s", target: self)
        add(file, "Save a Copy…", #selector(saveCopy(_:)), "s", target: self, modifiers: [.command, .shift])
        file.addItem(.separator()); add(file, "Close Window", #selector(NSWindow.performClose(_:)), "w")
        let edit = menu("Edit")
        add(edit, "Undo", NSSelectorFromString("undo:"), "z")
        add(edit, "Redo", NSSelectorFromString("redo:"), "z", modifiers: [.command, .shift])
        edit.addItem(.separator())
        add(edit, "Cut", #selector(NSText.cut(_:)), "x")
        add(edit, "Copy", #selector(NSText.copy(_:)), "c")
        add(edit, "Paste", #selector(NSText.paste(_:)), "v")
        add(edit, "Select All", #selector(NSText.selectAll(_:)), "a")
        edit.addItem(.separator()); add(edit, "Find…", #selector(find(_:)), "f", target: self)
        add(edit, "Find Next", #selector(findNext(_:)), "g", target: self)
        add(edit, "Find Previous", #selector(findPrevious(_:)), "g", target: self, modifiers: [.command, .shift])
        let view = menu("View")
        add(view, "Read", #selector(showRead(_:)), "1", target: self, modifiers: [.command, .option])
        add(view, "Source", #selector(showSource(_:)), "2", target: self, modifiers: [.command, .option])
        view.addItem(.separator())
        add(view, "Toggle Sidebar", #selector(toggleSidebar(_:)), "s", target: self, modifiers: [.command, .control])
        add(view, "Back", #selector(back(_:)), "[", target: self)
        view.addItem(.separator()); add(view, "Zoom In", #selector(zoomIn(_:)), "+", target: self)
        add(view, "Zoom Out", #selector(zoomOut(_:)), "-", target: self)
        add(view, "Actual Size", #selector(actualSize(_:)), "0", target: self)
        let windows = menu("Window"); NSApp.windowsMenu = windows
        add(windows, "Minimize", #selector(NSWindow.performMiniaturize(_:)), "m")
        add(windows, "Zoom", #selector(NSWindow.performZoom(_:)))
    }
}
