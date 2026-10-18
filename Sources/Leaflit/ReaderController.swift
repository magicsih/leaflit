import AppKit
import WebKit
import LeaflitCore

final class ReaderController: NSWindowController, WKScriptMessageHandler, WKNavigationDelegate, NSSearchFieldDelegate, NSToolbarDelegate, NSWindowDelegate {
    let webView: ReaderWebView
    let resources: ResourceHandler
    private(set) var documentURL: URL?
    private(set) var revision = RevisionGate()
    private(set) var displayedRevision = 0
    private(set) var completedRevision = 0
    private(set) var measurements: [String: Double] = [:]
    private var requestedAt = Date()
    private var ready = false
    private var watcher: FileWatcher?
    private var reading: Task<Void, Never>?
    private var history: [(URL, [String: Any])] = []
    private var pendingLocation: [String: Any]?
    private var lastText: String?
    private let search = NSSearchField()
    private let resultLabel = NSTextField(labelWithString: "")
    private let status = NSTextField(labelWithString: "")
    private let empty = NSStackView()
    private let errorBar = NSStackView()
    private let findBar = NSStackView()
    private let back = NSButton(image: NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Back")!, target: nil, action: nil)
    private let content = DropView()
    var onClose: (() -> Void)?
    var openFiles: (([URL]) -> Void)?
    var canNavigate: ((URL) -> Bool)?

    init() {
        resources = ResourceHandler(root: Bundle.main.resourceURL!.appendingPathComponent("Web"))
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.setURLSchemeHandler(resources, forURLScheme: "leaflit")
        config.setURLSchemeHandler(resources, forURLScheme: "leaflit-image")
        webView = ReaderWebView(frame: .zero, configuration: config)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 700), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = "Leaflit"; window.minSize = NSSize(width: 480, height: 340); window.center(); window.delegate = self
        window.isReleasedWhenClosed = false
        setupLayout(); setupToolbar()
        webView.navigationDelegate = self
        config.userContentController.add(self, name: "leaflit")
        webView.setAccessibilityLabel("Markdown document")
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "LeaflitOffline", encodedContentRuleList: #"[{"trigger":{"url-filter":"^https?://"},"action":{"type":"block"}}]"#) { [weak self] list, error in
            DispatchQueue.main.async {
                guard let self else { return }
                guard let list, error == nil else { self.showError("The offline renderer could not be started."); return }
                self.webView.configuration.userContentController.add(list)
                self.webView.load(URLRequest(url: URL(string: "leaflit://app/index.html")!))
            }
        }
    }
    required init?(coder: NSCoder) { fatalError("Not supported") }
    private func button(_ title: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action); button.bezelStyle = .rounded; return button
    }
    private func setupLayout() {
        content.onDrop = { [weak self] urls in self?.openFiles?(urls) }
        webView.onDrop = { [weak self] urls in self?.openFiles?(urls) }
        window?.contentView = content
        let icon = NSImageView(image: NSImage(systemSymbolName: "doc.text", accessibilityDescription: "Markdown file")!)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 44, weight: .light)
        let title = NSTextField(labelWithString: "Open a Markdown file")
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        let subtitle = NSTextField(labelWithString: "Drop a file here to start reading.")
        subtitle.textColor = .secondaryLabelColor
        empty.orientation = .vertical; empty.spacing = 14
        [icon, title, subtitle, button("Open Markdown File…", #selector(openPanel))].forEach(empty.addArrangedSubview)
        search.placeholderString = "Find in Document"; search.delegate = self; search.identifier = .init("documentSearch")
        search.setAccessibilityLabel("Find in Document")
        search.sendsSearchStringImmediately = true
        findBar.orientation = .horizontal; findBar.spacing = 8
        [search, resultLabel, button("Previous", #selector(findPrevious)), button("Next", #selector(findNext)), button("Done", #selector(hideFind))].forEach(findBar.addArrangedSubview)
        search.widthAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
        errorBar.orientation = .horizontal; errorBar.spacing = 8
        status.lineBreakMode = .byWordWrapping; status.maximumNumberOfLines = 3
        status.setAccessibilityRole(.staticText)
        [status, button("Retry", #selector(retry)), button("Open…", #selector(openPanel))].forEach(errorBar.addArrangedSubview)
        let stack = NSStackView(views: [findBar, errorBar, webView]); stack.orientation = .vertical; stack.spacing = 0; stack.alignment = .width
        [stack, empty].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; content.addSubview($0) }
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: content.leadingAnchor), stack.trailingAnchor.constraint(equalTo: content.trailingAnchor), stack.topAnchor.constraint(equalTo: content.topAnchor), stack.bottomAnchor.constraint(equalTo: content.bottomAnchor), empty.centerXAnchor.constraint(equalTo: content.centerXAnchor), empty.centerYAnchor.constraint(equalTo: content.centerYAnchor)])
        findBar.isHidden = true; errorBar.isHidden = true; webView.isHidden = true
    }
    private func setupToolbar() {
        let toolbar = NSToolbar(identifier: "Reader"); toolbar.delegate = self; toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false; window?.toolbar = toolbar
        back.target = self; back.action = #selector(goBack); back.isEnabled = false; back.toolTip = "Back (⌘[)"
    }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { toolbarDefaultItemIdentifiers(toolbar) }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [.init("back"), .init("open"), .flexibleSpace, .init("find"), .init("smaller"), .init("larger")] }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: id)
        if id.rawValue == "back" { item.view = back; item.label = "Back"; return item }
        let options: [String: (String, String, Selector)] = ["open": ("Open", "folder", #selector(openPanel)), "find": ("Find", "magnifyingglass", #selector(showFind)), "smaller": ("Zoom Out", "minus.magnifyingglass", #selector(zoomOut)), "larger": ("Zoom In", "plus.magnifyingglass", #selector(zoomIn))]
        guard let (label, symbol, action) = options[id.rawValue] else { return nil }
        item.label = label; item.toolTip = label; item.target = self; item.action = action
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        return item
    }
    func open(_ url: URL, location: [String: Any]? = nil) {
        documentURL = DocumentPath.canonical(url); pendingLocation = location
        lastText = nil; watcher = nil
        window?.title = url.lastPathComponent; window?.representedURL = documentURL
        watcher = FileWatcher(url: documentURL!) { [weak self] in self?.reload(preserve: true) }
        reload(preserve: false)
    }
    func reload(preserve: Bool) {
        guard ready, let url = documentURL else { return }
        reading?.cancel()
        let number = revision.next(); requestedAt = Date(); let location = pendingLocation; pendingLocation = nil
        reading = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) { Result { try DocumentSnapshot.read(url) } }.value
            guard let self, !Task.isCancelled, self.revision.accepts(number) else { return }
            switch result {
            case .failure:
                self.showError(self.lastText == nil ? "Could not read this file. Choose a UTF-8 Markdown file or retry." : "This file could not be refreshed. The previous content is still shown.")
            case .success(let snapshot):
                if preserve && snapshot.text == self.lastText { self.errorBar.isHidden = true; return }
                self.lastText = snapshot.text
                self.resources.images = snapshot.images; self.resources.revision = number
                self.errorBar.isHidden = true; self.empty.isHidden = true; self.webView.isHidden = false
                var payload: [String: Any] = ["text": snapshot.text, "revision": number, "preserve": preserve]
                if let location { payload["location"] = location }
                self.webView.callAsyncJavaScript("await window.Leaflit.render(payload)", arguments: ["payload": payload], in: nil, in: .page) { [weak self] result in
                    if case .failure = result, self?.revision.accepts(number) == true { self?.showError("This document could not be displayed. Retry to reload it.") }
                }
            }
        }
    }
    private func showError(_ message: String) { status.stringValue = message; errorBar.isHidden = false; empty.isHidden = true }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "ready": ready = true; reload(preserve: false)
        case "displayed":
            guard let number = body["revision"] as? Int, revision.accepts(number), let phase = body["phase"] as? String else { return }
            measurements[phase] = Date().timeIntervalSince(requestedAt) * 1000
            if phase == "body" { displayedRevision = number } else if phase == "complete" { completedRevision = number }
        case "navigate": if let href = body["href"] as? String { navigate(href) }
        case "appearance": lastText = nil; reload(preserve: true)
        default: break
        }
    }
    func navigate(_ href: String) {
        guard let url = documentURL else { return }
        switch DocumentPath.link(href, from: url) {
        case .anchor(let anchor): webView.callAsyncJavaScript("window.Leaflit.anchor(value)", arguments: ["value": anchor], in: nil, in: .page) { _ in }
        case .document(let target, let anchor):
            guard canNavigate?(target) != false else { return }
            webView.callAsyncJavaScript("return window.Leaflit.position()", arguments: [:], in: nil, in: .page) { [weak self] result in
                guard let self, self.documentURL == url else { return }
                let location = (try? result.get()) as? [String: Any] ?? [:]
                self.history.append((url, location)); self.back.isEnabled = true
                self.open(target, location: anchor.map { ["anchor": $0] })
            }
        case .web(let target): NSWorkspace.shared.open(target)
        case .blocked: NSSound.beep()
        }
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.request.url?.absoluteString == "leaflit://app/index.html", navigationAction.navigationType == .other { decisionHandler(.allow) }
        else { decisionHandler(.cancel) }
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        ready = false; showError("The document renderer stopped. Retry to reload it.")
    }
    @objc func retry() {
        if !ready { webView.load(URLRequest(url: URL(string: "leaflit://app/index.html")!)) }
        else { lastText = nil; reload(preserve: true) }
    }
    @objc func openPanel() { (NSApp.delegate as? AppDelegate)?.openPanel(nil) }
    @objc func goBack() {
        guard let (url, location) = history.popLast() else { return }
        back.isEnabled = !history.isEmpty; open(url, location: location)
    }
    @objc func showFind() { findBar.isHidden = false; window?.makeFirstResponder(search) }
    @objc func hideFind() { findBar.isHidden = true; window?.makeFirstResponder(webView) }
    func controlTextDidChange(_ obj: Notification) { find(backwards: false) }
    @objc func findNext() { find(backwards: false) }
    @objc func findPrevious() { find(backwards: true) }
    private func find(backwards: Bool) {
        guard !search.stringValue.isEmpty else { resultLabel.stringValue = ""; return }
        let config = WKFindConfiguration(); config.backwards = backwards; config.wraps = true; config.caseSensitive = false
        webView.find(search.stringValue, configuration: config) { [weak self] result in self?.resultLabel.stringValue = result.matchFound ? "" : "Not found" }
    }
    @objc func zoomIn() { webView.pageZoom = min(3, (webView.pageZoom * 10 + 1).rounded() / 10) }
    @objc func zoomOut() { webView.pageZoom = max(0.5, (webView.pageZoom * 10 - 1).rounded() / 10) }
    @objc func actualSize() { webView.pageZoom = 1 }
    func windowWillClose(_ notification: Notification) {
        reading?.cancel(); watcher = nil
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "leaflit")
        onClose?()
    }
}

final class DropView: NSView {
    var onDrop: (([URL]) -> Void)?
    override init(frame frameRect: NSRect) { super.init(frame: frameRect); registerForDraggedTypes([.fileURL]) }
    required init?(coder: NSCoder) { fatalError("Not supported") }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { urls(sender).isEmpty ? [] : .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let files = urls(sender); guard !files.isEmpty else { return false }; onDrop?(files); return true
    }
    private func urls(_ sender: NSDraggingInfo) -> [URL] {
        (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []).filter(DocumentPath.isMarkdown)
    }
}

final class ReaderWebView: WKWebView {
    var onDrop: (([URL]) -> Void)?
    private func files(_ sender: NSDraggingInfo) -> [URL] {
        (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []).filter(DocumentPath.isMarkdown)
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { files(sender).isEmpty ? [] : .copy }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { files(sender).isEmpty ? [] : .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = files(sender); guard !urls.isEmpty else { return false }; onDrop?(urls); return true
    }
}
