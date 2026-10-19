import AppKit
import WebKit
import LeaflitCore
import os

final class ReaderController: NSWindowController, WKScriptMessageHandler, WKNavigationDelegate, NSSearchFieldDelegate, NSToolbarDelegate, NSWindowDelegate {
    let webView: ReaderWebView
    let resources: ResourceHandler
    private(set) var documentURL: URL?
    private(set) var revision = RevisionGate()
    private var readRevision = RevisionGate()
    private(set) var renderedURL: URL?
    private(set) var displayedRevision = 0
    private(set) var completedRevision = 0
    private(set) var measurements: [String: Double] = [:]
    private(set) var displayTimings: [String: String] = [:]
    private var requestedAt = Date()
    private let performanceLog = Logger(subsystem: "io.github.magicsih.leaflit", category: "performance")
    private var ready = false
    private var watcher: FileWatcher?
    private var reading: Task<Void, Never>?
    private var history: [(URL, [String: Any], FolderTree?)] = []
    private var documentScope: FolderTree?
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
    let editing = SourceEditingController()
    var sourceReader: @Sendable (URL, FolderTree?) throws -> SourceFileSnapshot = SourceFileSnapshot.read
    let sidebar: NavigationSidebarController
    let splitController = NSSplitViewController()
    private let documentController = NSViewController()
    private lazy var sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebar)
    private let preferences: UserDefaults
    private var sidebarRequested: Bool
    private var settingSidebar = false
    private var sidebarObservation: NSKeyValueObservation?
    private var navigationSerial = 0
    var isSidebarVisible: Bool { !sidebarItem.isCollapsed }
    var onClose: (() -> Void)?
    var openFiles: (([URL]) -> Void)?
    var canNavigate: ((URL) -> Bool)?

    init(preferences: UserDefaults = .standard) {
        self.preferences = preferences
        sidebar = NavigationSidebarController(preferences: preferences)
        sidebarRequested = preferences.object(forKey: "sidebar.visible") == nil ? true : preferences.bool(forKey: "sidebar.visible")
        resources = ResourceHandler(root: Bundle.main.resourceURL!.appendingPathComponent("Web"))
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.setURLSchemeHandler(resources, forURLScheme: "leaflit")
        config.setURLSchemeHandler(resources, forURLScheme: "leaflit-image")
        webView = ReaderWebView(frame: .zero, configuration: config)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 700), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        super.init(window: window)
        window.windowController = self
        window.title = "Leaflit"; window.minSize = NSSize(width: 480, height: 340); window.center(); window.delegate = self
        window.isReleasedWhenClosed = false
        setupLayout(); setupToolbar()
        editing.window = window
        editing.onRequestSource = { [weak self] in self?.reload(preserve: true) }
        editing.onPreview = { [weak self] text, anchor in self?.render(text, preserve: true, location: anchor.map { ["anchor": $0] }) }
        editing.onReadSelected = { [weak self] in guard let self else { return }; self.window?.makeFirstResponder(self.webView) }
        editing.onSaved = { [weak self] in self?.reload(preserve: true) }
        editing.onStateChanged = { [weak self] in
            guard let self else { return }
            self.webView.isHidden = self.documentURL == nil || self.editing.mode == .source
            if self.editing.mode == .source { self.findBar.isHidden = true }
        }
        sidebar.onFileSelected = { [weak self] url in
            guard let self, let folder = self.sidebar.folder else { return }
            self.navigate(to: url, within: folder)
        }
        sidebar.onHeadingSelected = { [weak self] id in
            guard let self, self.displayedRevision == self.revision.current else { return }
            if self.editing.mode == .source {
                let hasDraft = self.editing.draft != nil
                self.editing.select(.read, anchor: id)
                if hasDraft { return }
            }
            self.webView.callAsyncJavaScript("window.Leaflit.anchor(value)", arguments: ["value": id], in: nil, in: .page) { _ in }
        }
        sidebar.onModeChanged = { [weak self] in self?.updateOutlineTracking() }
        sidebarObservation = sidebarItem.observe(\.isCollapsed, options: [.new]) { [weak self] _, _ in
            guard let self, !self.settingSidebar else { return }
            if (self.window?.contentView?.bounds.width ?? 900) >= 620 {
                self.sidebarRequested = !self.sidebarItem.isCollapsed
                self.preferences.set(self.sidebarRequested, forKey: "sidebar.visible")
            }
            self.updateOutlineTracking()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(splitResized), name: NSSplitView.didResizeSubviewsNotification, object: splitController.splitView)
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
        let root = DropView(); root.onDrop = { [weak self] in self?.openFiles?($0) }
        window?.contentView = root
        documentController.view = content
        splitController.splitView.isVertical = true; splitController.splitView.dividerStyle = .thin
        sidebarItem.minimumThickness = 180; sidebarItem.maximumThickness = 320
        sidebarItem.canCollapse = true; sidebarItem.preferredThicknessFraction = 230.0 / 900.0
        let documentItem = NSSplitViewItem(viewController: documentController); documentItem.minimumThickness = 300
        splitController.addSplitViewItem(sidebarItem); splitController.addSplitViewItem(documentItem)
        let split = splitController.view; split.translatesAutoresizingMaskIntoConstraints = false; root.addSubview(split)
        NSLayoutConstraint.activate([split.leadingAnchor.constraint(equalTo: root.leadingAnchor), split.trailingAnchor.constraint(equalTo: root.trailingAnchor), split.topAnchor.constraint(equalTo: root.topAnchor), split.bottomAnchor.constraint(equalTo: root.bottomAnchor)])
        root.layoutSubtreeIfNeeded()
        restoreSidebarWidth()
        updateSidebarLayout()
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
        search.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        errorBar.orientation = .horizontal; errorBar.spacing = 8
        status.lineBreakMode = .byWordWrapping; status.maximumNumberOfLines = 3
        status.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        status.setAccessibilityRole(.staticText)
        [status, button("Retry", #selector(retry)), button("Open…", #selector(openPanel))].forEach(errorBar.addArrangedSubview)
        let stack = NSStackView(views: [editing.header, findBar, errorBar, editing.conflictBar, webView, editing.editorHost]); stack.orientation = .vertical; stack.spacing = 0; stack.alignment = .width
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
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [.init("sidebar"), .init("back"), .init("open"), .flexibleSpace, .init("find"), .init("smaller"), .init("larger")] }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: id)
        if id.rawValue == "sidebar" {
            item.label = "Toggle Sidebar"; item.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: "Toggle Sidebar")
            item.target = self; item.action = #selector(toggleSidebar); item.toolTip = "Show or hide sidebar (⌃⌘S)"; return item
        }
        if id.rawValue == "back" { item.view = back; item.label = "Back"; return item }
        let options: [String: (String, String, Selector)] = ["open": ("Open", "folder", #selector(openPanel)), "find": ("Find", "magnifyingglass", #selector(showFind)), "smaller": ("Zoom Out", "minus.magnifyingglass", #selector(zoomOut)), "larger": ("Zoom In", "plus.magnifyingglass", #selector(zoomIn))]
        guard let (label, symbol, action) = options[id.rawValue] else { return nil }
        item.label = label; item.toolTip = label; item.target = self; item.action = action
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        return item
    }
    func open(_ url: URL, location: [String: Any]? = nil, within folder: FolderTree? = nil) {
        editing.confirmBeforeLeaving { [weak self] accepted in
            if accepted { self?.openResolved(url, location: location, within: folder) }
        }
    }
    private func openResolved(_ url: URL, location: [String: Any]? = nil, within folder: FolderTree? = nil) {
        guard folder?.canOpen(url) != false else { showError("This file is no longer available in the selected folder."); return }
        navigationSerial += 1
        documentScope = folder
        documentURL = DocumentPath.canonical(url); pendingLocation = location
        editing.reset(url: documentURL!, within: folder)
        requestedAt = Date()
        lastText = nil; watcher = nil
        window?.title = url.lastPathComponent; window?.representedURL = documentURL
        sidebar.setDocument(documentURL)
        watcher = FileWatcher(url: documentURL!) { [weak self] in self?.reload(preserve: true) }
        reload(preserve: false)
    }
    func reload(preserve: Bool) {
        reading?.cancel(); reading = nil
        let request = readRevision.next()
        guard let url = documentURL, ready || editing.hasRequestedSource else { return }
        let requestDate = preserve ? Date() : requestedAt
        let location = pendingLocation; pendingLocation = nil
        let scope = documentScope
        let wantsSource = editing.hasRequestedSource, sourceReader = sourceReader
        reading = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                Result { () throws -> (DocumentSnapshot, SourceFileSnapshot?) in
                    if wantsSource {
                        let source = try sourceReader(url, scope)
                        return (try DocumentSnapshot.decode(source.data, at: source.url), source)
                    }
                    return (try FolderDocumentReader.read(url, within: scope), nil)
                }
            }.value
            guard let self, !Task.isCancelled, self.readRevision.accepts(request) else { return }
            guard !self.editing.isSaving else { return }
            switch result {
            case .failure:
                self.editing.readFailed()
                self.showError(self.lastText == nil ? "Could not read this file. Choose a UTF-8 Markdown file or retry." : "This file could not be refreshed. The previous content is still shown.")
            case .success(let (snapshot, source)):
                do { if let source { try self.editing.receive(source) } }
                catch { self.editing.readFailed(); self.showError("Could not decode this UTF-8 source. Your edits are still here."); return }
                self.requestedAt = requestDate
                self.render(self.editing.draft?.text ?? snapshot.text, preserve: preserve, location: location)
            }
        }
    }
    private func render(_ text: String, preserve: Bool, location: [String: Any]? = nil) {
        guard ready, let url = documentURL else { return }
        errorBar.isHidden = true; empty.isHidden = true
        webView.isHidden = editing.mode == .source
        if preserve && location == nil && lastText?.utf8.elementsEqual(text.utf8) == true { return }
        let number = revision.next()
        renderedURL = url; lastText = text
        resources.images = LocalImages.references(in: text, document: url); resources.revision = number
        var payload: [String: Any] = ["text": text, "revision": number, "preserve": preserve]
        if let location { payload["location"] = location }
        webView.callAsyncJavaScript("await window.Leaflit.render(payload)", arguments: ["payload": payload], in: nil, in: .page) { [weak self] result in
            if case .failure = result, self?.revision.accepts(number) == true { self?.showError("This document could not be displayed. Retry to reload it.") }
        }
    }
    private func showError(_ message: String) { status.stringValue = message; errorBar.isHidden = false; empty.isHidden = true }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "ready": ready = true; updateOutlineTracking(); reload(preserve: false)
        case "displayed":
            guard documentURL?.path == renderedURL?.path, let number = body["revision"] as? Int, revision.accepts(number), let phase = body["phase"] as? String else { return }
            measurements[phase] = Date().timeIntervalSince(requestedAt) * 1000
            let timing = body["timing"] as? String ?? "unknown"
            displayTimings[phase] = ["animationFrames", "timerFallback"].contains(timing) ? timing : "unknown"
            performanceLog.info("display phase=\(phase, privacy: .public) ms=\(self.measurements[phase] ?? 0, privacy: .public) timing=\(self.displayTimings[phase] ?? "unknown", privacy: .public)")
            if phase == "body" {
                displayedRevision = number
                let messages = body["headings"] as? [[String: Any]] ?? []
                sidebar.setHeadings(messages.compactMap(DocumentHeading.init(message:)))
            } else if phase == "complete" { completedRevision = number }
        case "activeHeading":
            if documentURL == renderedURL, let number = body["revision"] as? Int, revision.accepts(number), let id = body["id"] as? String { sidebar.setActiveHeading(id) }
        case "navigate":
            if documentURL?.path == renderedURL?.path, let number = body["revision"] as? Int, revision.accepts(number), let href = body["href"] as? String { navigate(href) }
        case "editSource":
            if documentURL == renderedURL, let number = body["revision"] as? Int, revision.accepts(number), let line = body["line"] as? Int, line >= 0 { editing.select(.source, line: line) }
        case "appearance": lastText = nil; reload(preserve: true)
        default: break
        }
    }
    func navigate(_ href: String) {
        guard let url = documentURL else { return }
        switch DocumentPath.link(href, from: url) {
        case .anchor(let anchor): webView.callAsyncJavaScript("window.Leaflit.anchor(value)", arguments: ["value": anchor], in: nil, in: .page) { _ in }
        case .document(let target, let anchor):
            navigate(to: target, anchor: anchor)
        case .web(let target): NSWorkspace.shared.open(target)
        case .blocked: NSSound.beep()
        }
    }
    func navigate(to raw: URL, anchor: String? = nil, within folder: FolderTree? = nil) {
        guard !editing.isBusy else { sidebar.setDocument(documentURL); return }
        let target = DocumentPath.canonical(raw)
        guard DocumentPath.isMarkdown(target), folder?.canOpen(raw) != false, canNavigate?(target) != false else { sidebar.setDocument(documentURL); return }
        if target == documentURL { if let anchor { navigate("#" + anchor) }; return }
        guard let origin = documentURL, ready else { open(raw, location: anchor.map { ["anchor": $0] }, within: folder); return }
        navigationSerial += 1; let request = navigationSerial
        webView.callAsyncJavaScript("return window.Leaflit.position()", arguments: [:], in: nil, in: .page) { [weak self] result in
            guard let self, self.navigationSerial == request, self.documentURL == origin else { return }
            if let folder, (self.sidebar.folder?.root != folder.root || !folder.canOpen(raw)) { self.sidebar.setDocument(self.documentURL); return }
            guard self.canNavigate?(target) != false else { self.sidebar.setDocument(self.documentURL); return }
            let location = (try? result.get()) as? [String: Any] ?? [:]
            self.editing.confirmBeforeLeaving { [weak self] accepted in
                guard let self else { return }
                guard accepted, self.navigationSerial == request, self.documentURL == origin,
                      folder?.canOpen(raw) != false, self.canNavigate?(target) != false else { self.sidebar.setDocument(self.documentURL); return }
                self.history.append((origin, location, self.documentScope)); self.back.isEnabled = true
                self.openResolved(raw, location: anchor.map { ["anchor": $0] }, within: folder)
            }
        }
    }
    @objc func toggleSidebar() {
        sidebarRequested = !isSidebarVisible; preferences.set(sidebarRequested, forKey: "sidebar.visible")
        if sidebarRequested, let window, window.contentView!.bounds.width < 620 {
            window.setContentSize(NSSize(width: 720, height: window.contentView!.bounds.height))
        }
        updateSidebarLayout()
    }
    func windowDidResize(_ notification: Notification) { updateSidebarLayout() }
    private func updateSidebarLayout() {
        let wasCollapsed = sidebarItem.isCollapsed
        settingSidebar = true
        sidebarItem.isCollapsed = !sidebarRequested || (window?.contentView?.bounds.width ?? 900) < 620
        if wasCollapsed && !sidebarItem.isCollapsed {
            window?.contentView?.layoutSubtreeIfNeeded()
            restoreSidebarWidth()
        }
        settingSidebar = false
        updateOutlineTracking()
    }
    private func restoreSidebarWidth() {
        let split = splitController.splitView
        guard let pane = split.arrangedSubviews.first else { return }
        let savedWidth = preferences.double(forKey: "sidebar.width")
        let width = savedWidth > 0 ? min(320, max(180, savedWidth)) : 230
        // The native split pane can include margins outside the sidebar's view.
        let frame = sidebar.view.convert(sidebar.view.bounds, to: split)
        split.setPosition(pane.frame.maxX + width - frame.width, ofDividerAt: 0)
    }
    @objc private func splitResized(_ notification: Notification) {
        // Automatic layout compression must not replace the user's chosen width.
        guard (notification.userInfo?["NSSplitViewUserResizeKey"] as? NSNumber)?.boolValue == true,
              !settingSidebar, isSidebarVisible, (window?.contentView?.bounds.width ?? 0) >= 620 else { return }
        let width = sidebar.view.bounds.width
        if (180...320).contains(width) { preferences.set(Double(width), forKey: "sidebar.width") }
    }
    private func updateOutlineTracking() {
        guard ready else { return }
        webView.callAsyncJavaScript("window.Leaflit.setOutlineEnabled(value)", arguments: ["value": isSidebarVisible && sidebar.mode == .outline], in: nil, in: .page) { _ in }
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
        guard let (url, location, scope) = history.last else { return }
        editing.confirmBeforeLeaving { [weak self] accepted in
            guard let self, accepted, scope?.canOpen(url) != false, self.canNavigate?(url) != false else { return }
            self.history.removeLast(); self.back.isEnabled = !self.history.isEmpty
            self.openResolved(url, location: location, within: scope)
        }
    }
    @objc func showRead() { editing.select(.read) }
    @objc func showSource() { editing.select(.source); editing.zoom(webView.pageZoom) }
    @objc func saveDocument() { editing.save() }
    @objc func saveCopy() { editing.saveCopy() }
    @objc func showFind() {
        if editing.mode == .source { editing.find(.showFindInterface) }
        else { findBar.isHidden = false; window?.makeFirstResponder(search) }
    }
    override func cancelOperation(_ sender: Any?) { hideFind() }
    @objc func hideFind() {
        if editing.mode == .source { editing.find(.hideFindInterface) }
        else { findBar.isHidden = true; window?.makeFirstResponder(webView) }
    }
    func controlTextDidChange(_ obj: Notification) { find(backwards: false) }
    @objc func findNext() { if editing.mode == .source { editing.find(.nextMatch) } else { find(backwards: false) } }
    @objc func findPrevious() { if editing.mode == .source { editing.find(.previousMatch) } else { find(backwards: true) } }
    private func find(backwards: Bool) {
        guard !search.stringValue.isEmpty else { resultLabel.stringValue = ""; return }
        let config = WKFindConfiguration(); config.backwards = backwards; config.wraps = true; config.caseSensitive = false
        webView.find(search.stringValue, configuration: config) { [weak self] result in self?.resultLabel.stringValue = result.matchFound ? "" : "Not found" }
    }
    @objc func zoomIn() { webView.pageZoom = min(3, (webView.pageZoom * 10 + 1).rounded() / 10); editing.zoom(webView.pageZoom) }
    @objc func zoomOut() { webView.pageZoom = max(0.5, (webView.pageZoom * 10 - 1).rounded() / 10); editing.zoom(webView.pageZoom) }
    @objc func actualSize() { webView.pageZoom = 1; editing.zoom(1) }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard !editing.isBusy else { return false }
        guard editing.isDirty else { return true }
        editing.confirmBeforeLeaving { [weak sender] accepted in if accepted { sender?.close() } }
        return false
    }
    func windowWillClose(_ notification: Notification) {
        reading?.cancel(); reading = nil; watcher = nil
        editing.stop()
        sidebar.stop(); sidebarObservation = nil
        NotificationCenter.default.removeObserver(self, name: NSSplitView.didResizeSubviewsNotification, object: splitController.splitView)
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
