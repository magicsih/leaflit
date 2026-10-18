import AppKit
import LeaflitCore

private final class FileNode: NSObject {
    let url: URL
    let name: String
    let isDirectory: Bool
    var children: [FileNode]?
    var request = 0
    init(url: URL, name: String, isDirectory: Bool) { self.url = url; self.name = name; self.isDirectory = isDirectory }
}

private final class SidebarModeControl: NSSegmentedControl {
    override var intrinsicContentSize: NSSize {
        // The split view owns width; segment geometry must not set its minimum.
        NSSize(width: NSView.noIntrinsicMetric, height: super.intrinsicContentSize.height)
    }
}

@MainActor
final class NavigationSidebarController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    enum Mode: String { case files = "Files", outline = "Outline" }
    private(set) var mode: Mode
    private(set) var folder: FolderTree?
    private(set) var headings: [DocumentHeading] = []
    private(set) var activeHeadingID: String?
    let modeControl: NSSegmentedControl = SidebarModeControl(labels: ["Files", "Outline"], trackingMode: .selectOne, target: nil, action: nil)
    let filesView = NSOutlineView()
    let outlineView = NSOutlineView()
    private let filesPanel = NSView(), outlinePanel = NSView()
    private let folderName = NSTextField(labelWithString: "No folder selected")
    private let documentName = NSTextField(labelWithString: "No document open")
    private let fileStatus = NSTextField(wrappingLabelWithString: "Choose a folder to browse Markdown files.")
    private let outlineStatus = NSTextField(wrappingLabelWithString: "Open a Markdown file to see its headings.")
    private let retryButton = NSButton(title: "Retry", target: nil, action: nil)
    private let preferences: UserDefaults
    private var rootNode: FileNode?
    private var nodes: [URL: FileNode] = [:]
    private var directoryTasks: [URL: Task<Void, Never>] = [:]
    private var directoryWatchers: [URL: FileWatcher] = [:]
    private var directoryErrors: [URL: String] = [:]
    private var generation = 0
    private var documentURL: URL?
    private var outline = HeadingOutline([])
    private var collapsedHeadings: Set<String> = []
    private var adjustingSelection = false
    private var revealingDocument = false
    var onFileSelected: ((URL) -> Void)?
    var onHeadingSelected: ((String) -> Void)?
    var onModeChanged: (() -> Void)?

    init(preferences: UserDefaults) {
        self.preferences = preferences
        mode = Mode(rawValue: preferences.string(forKey: "sidebar.mode") ?? "") ?? .files
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("Not supported") }
    override func loadView() {
        let background = NSVisualEffectView(); background.material = .sidebar; background.blendingMode = .behindWindow
        view = background
        modeControl.target = self; modeControl.action = #selector(sidebarModeChanged)
        modeControl.identifier = .init("sidebarMode"); modeControl.setAccessibilityLabel("Sidebar mode")
        modeControl.setToolTip("Browse files", forSegment: 0); modeControl.setToolTip("Navigate document headings", forSegment: 1)
        [modeControl, filesPanel, outlinePanel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; view.addSubview($0) }
        NSLayoutConstraint.activate([
            modeControl.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            modeControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            modeControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10)
        ])
        for panel in [filesPanel, outlinePanel] {
            NSLayoutConstraint.activate([panel.topAnchor.constraint(equalTo: modeControl.bottomAnchor, constant: 12), panel.bottomAnchor.constraint(equalTo: view.bottomAnchor), panel.leadingAnchor.constraint(equalTo: view.leadingAnchor), panel.trailingAnchor.constraint(equalTo: view.trailingAnchor)])
        }
        let choose = NSButton(title: "Open Folder…", target: self, action: #selector(openFolder))
        choose.bezelStyle = .rounded; choose.identifier = .init("openFolder")
        retryButton.target = self; retryButton.action = #selector(retryFolder); retryButton.isHidden = true
        configure(filesView, label: "Markdown files"); configure(outlineView, label: "Document outline")
        buildPanel(filesPanel, name: folderName, list: filesView, status: fileStatus, actions: [choose, retryButton])
        buildPanel(outlinePanel, name: documentName, list: outlineView, status: outlineStatus, actions: [])
        displayMode()
    }
    override func viewDidLayout() {
        super.viewDidLayout()
        guard modeControl.bounds.width > 4 else { return }
        // Explicit widths invalidate AppKit's cached segment geometry on shrink.
        let width = (modeControl.bounds.width - 2) / CGFloat(modeControl.segmentCount)
        for segment in 0..<modeControl.segmentCount where abs(modeControl.width(forSegment: segment) - width) > 0.5 {
            modeControl.setWidth(width, forSegment: segment)
        }
    }
    private func configure(_ list: NSOutlineView, label: String) {
        let column = NSTableColumn(identifier: .init("title")); column.resizingMask = .autoresizingMask
        list.addTableColumn(column); list.outlineTableColumn = column; list.headerView = nil
        list.dataSource = self; list.delegate = self; list.rowSizeStyle = .default
        list.style = .sourceList; list.floatsGroupRows = false; list.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        list.autoresizingMask = [.width]
        list.setAccessibilityLabel(label); list.identifier = .init(label == "Markdown files" ? "filesTree" : "documentOutline")
    }
    private func buildPanel(_ panel: NSView, name: NSTextField, list: NSOutlineView, status: NSTextField, actions: [NSView]) {
        name.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        name.textColor = .secondaryLabelColor; name.lineBreakMode = .byTruncatingMiddle
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        status.font = .systemFont(ofSize: NSFont.smallSystemFontSize); status.textColor = .secondaryLabelColor
        let header = NSStackView(views: [name] + actions); header.orientation = .vertical; header.alignment = .leading; header.spacing = 8
        let scroll = NSScrollView(); scroll.documentView = list; scroll.hasVerticalScroller = true; scroll.drawsBackground = false; scroll.autohidesScrollers = true
        [header, scroll, status].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; panel.addSubview($0) }
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: panel.topAnchor), header.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 12), header.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8), scroll.leadingAnchor.constraint(equalTo: panel.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            status.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 8), status.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 12), status.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12), status.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -12)
        ])
    }
    @objc private func sidebarModeChanged() { setMode(modeControl.selectedSegment == 0 ? .files : .outline) }
    func setMode(_ mode: Mode) {
        self.mode = mode; preferences.set(mode.rawValue, forKey: "sidebar.mode")
        _ = view; displayMode(); onModeChanged?()
    }
    private func displayMode() {
        modeControl.selectedSegment = mode == .files ? 0 : 1
        filesPanel.isHidden = mode != .files; outlinePanel.isHidden = mode != .outline
    }
    @objc func openFolder() {
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.allowsMultipleSelection = false
        panel.message = "Choose a folder to browse Markdown files."; panel.prompt = "Open Folder"
        guard let window = view.window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }; self?.chooseFolder(url)
        }
    }
    func chooseFolder(_ url: URL) {
        _ = view; cancelDirectoryWork(); directoryErrors.removeAll(); generation += 1
        let tree = FolderTree(root: url); folder = tree
        let root = FileNode(url: tree.root, name: tree.root.lastPathComponent, isDirectory: true)
        rootNode = root; nodes = [tree.root: root]
        folderName.stringValue = root.name; folderName.toolTip = tree.root.path
        revealingDocument = true; filesView.reloadData(); refresh(root); rebuildWatchers()
    }
    @objc private func retryFolder() {
        guard let root = rootNode else { return }
        for node in nodes.values where node === root || filesView.isItemExpanded(node) || directoryErrors[node.url] != nil { refresh(node) }
    }
    private func refresh(_ node: FileNode) {
        guard let tree = folder else { return }
        let currentGeneration = generation; node.request += 1; let request = node.request
        directoryTasks[node.url]?.cancel()
        if node === rootNode { fileStatus.stringValue = "Loading…" }
        directoryTasks[node.url] = Task { [weak self, weak node] in
            guard let node else { return }
            let result = await Task.detached(priority: .userInitiated) { Result { try tree.entries(in: node.url) } }.value
            guard let self, !Task.isCancelled, self.generation == currentGeneration, node.request == request, self.nodes[node.url] === node else { return }
            self.directoryTasks[node.url] = nil
            let expanded = self.nodes.values.filter { self.filesView.isItemExpanded($0) }.map(\.url)
            switch result {
            case .success(let entries):
                let previous = Dictionary(uniqueKeysWithValues: (node.children ?? []).map { ($0.url, $0) })
                node.children = entries.map { entry in
                    if let existing = previous[entry.url], existing.isDirectory == entry.isDirectory { return existing }
                    return FileNode(url: entry.url, name: entry.name, isDirectory: entry.isDirectory)
                }
                self.directoryErrors[node.url] = nil
            case .failure:
                node.children = []
                self.directoryErrors[node.url] = node === self.rootNode ? "Folder unavailable" : "Could not read \(node.name)."
            }
            self.reindexNodes()
            self.adjustingSelection = true
            if node === self.rootNode { self.filesView.reloadData() } else { self.filesView.reloadItem(node, reloadChildren: true) }
            for url in expanded.sorted(by: { $0.pathComponents.count < $1.pathComponents.count }) {
                if let expandedNode = self.nodes[url] { self.filesView.expandItem(expandedNode) }
            }
            self.adjustingSelection = false
            self.rebuildWatchers(); self.updateFileSelection()
            if self.revealingDocument { self.revealDocument() }
            self.updateFileStatus()
        }
    }
    private func reindexNodes() {
        var reachable: [URL: FileNode] = [:]
        func add(_ node: FileNode) { reachable[node.url] = node; node.children?.forEach(add) }
        if let root = rootNode { add(root) }
        for (url, task) in directoryTasks where reachable[url] == nil { task.cancel(); directoryTasks[url] = nil }
        nodes = reachable
        directoryErrors = directoryErrors.filter { reachable[$0.key] != nil }
    }
    private func rebuildWatchers() {
        guard let root = rootNode else { directoryWatchers.removeAll(); return }
        var watched: Set<URL> = [root.url]
        func visit(_ parent: FileNode) {
            for node in parent.children ?? [] where node.isDirectory && filesView.isItemExpanded(node) { watched.insert(node.url); visit(node) }
        }
        visit(root)
        for url in Array(directoryWatchers.keys) where !watched.contains(url) { directoryWatchers[url] = nil }
        for url in watched where directoryWatchers[url] == nil {
            directoryWatchers[url] = FileWatcher(url: url) { [weak self] in
                guard let self, let node = self.nodes[url] else { return }; self.refresh(node)
            }
        }
    }
    private func revealDocument() {
        guard let tree = folder, let documentURL, tree.contains(documentURL), let root = rootNode else { revealingDocument = false; return }
        var parent = root
        let components = documentURL.path.dropFirst(tree.root.path == "/" ? 1 : tree.root.path.count + 1).split(separator: "/")
        for component in components {
            guard let children = parent.children else { refresh(parent); return }
            guard let child = children.first(where: { $0.name == component }) else { revealingDocument = false; return }
            if child.isDirectory {
                filesView.expandItem(child); parent = child
            } else { revealingDocument = false; updateFileSelection(); return }
        }
        revealingDocument = false
    }
    func setDocument(_ url: URL?) {
        _ = view
        if documentURL != url { collapsedHeadings.removeAll(); activeHeadingID = nil; setHeadings([]) }
        documentURL = url
        documentName.stringValue = url?.lastPathComponent ?? "No document open"
        documentName.toolTip = url?.path
        revealingDocument = true; updateFileSelection(); revealDocument()
        updateOutlineStatus()
    }
    private func updateFileSelection() {
        adjustingSelection = true; defer { adjustingSelection = false }
        if let documentURL, let node = nodes[documentURL], filesView.row(forItem: node) >= 0 {
            filesView.selectRowIndexes(IndexSet(integer: filesView.row(forItem: node)), byExtendingSelection: false)
        } else { filesView.deselectAll(nil) }
        updateFileStatus()
    }
    private func updateFileStatus() {
        retryButton.isHidden = directoryErrors.isEmpty
        if let error = folder.flatMap({ directoryErrors[$0.root] }) ?? directoryErrors.sorted(by: { $0.key.path < $1.key.path }).first?.value { fileStatus.stringValue = error }
        else if let documentURL, let folder, !folder.contains(documentURL) { fileStatus.stringValue = "Outside selected folder" }
        else if rootNode == nil { fileStatus.stringValue = "Choose a folder to browse Markdown files." }
        else if rootNode?.children == nil { fileStatus.stringValue = "Loading…" }
        else { fileStatus.stringValue = rootNode?.children?.isEmpty == true ? "No Markdown files" : "" }
    }
    func setHeadings(_ headings: [DocumentHeading]) {
        _ = view; self.headings = headings; outline = HeadingOutline(headings)
        adjustingSelection = true; outlineView.reloadData()
        func expand(_ nodes: [HeadingNode]) {
            for node in nodes where !node.children.isEmpty && !collapsedHeadings.contains(node.heading.id) { outlineView.expandItem(node); expand(node.children) }
        }
        expand(outline.roots); adjustingSelection = false
        updateOutlineStatus(); if let id = activeHeadingID { setActiveHeading(id) }
    }
    private func updateOutlineStatus() { outlineStatus.stringValue = headings.isEmpty ? (documentURL == nil ? "Open a Markdown file to see its headings." : "No headings in this document") : "" }
    func setActiveHeading(_ id: String) {
        activeHeadingID = id
        guard let node = outline.node(id: id) else { return }
        let visible = ([node] + outline.ancestors(of: id).reversed()).first { outlineView.row(forItem: $0) >= 0 }
        guard let visible else { return }
        adjustingSelection = true
        outlineView.selectRowIndexes(IndexSet(integer: outlineView.row(forItem: visible)), byExtendingSelection: false)
        adjustingSelection = false
    }
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if outlineView === filesView { return ((item as? FileNode) ?? rootNode)?.children?.count ?? 0 }
        return (item as? HeadingNode)?.children.count ?? outline.roots.count
    }
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if outlineView === filesView { return ((item as? FileNode) ?? rootNode)!.children![index] }
        return ((item as? HeadingNode)?.children ?? outline.roots)[index]
    }
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let node = item as? FileNode { return node.isDirectory }
        return (item as? HeadingNode)?.children.isEmpty == false
    }
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let cell = (outlineView.makeView(withIdentifier: .init("navigationCell"), owner: self) as? NSTableCellView) ?? makeCell()
        if let node = item as? FileNode {
            cell.textField?.stringValue = node.name
            cell.imageView?.image = NSImage(systemSymbolName: node.isDirectory ? "folder" : "doc.text", accessibilityDescription: node.isDirectory ? "Folder" : "Markdown document")
            cell.toolTip = node.url.path
        } else if let node = item as? HeadingNode {
            cell.textField?.stringValue = node.heading.title
            cell.imageView?.image = nil; cell.toolTip = node.heading.title
        }
        return cell
    }
    private func makeCell() -> NSTableCellView {
        let cell = NSTableCellView(); cell.identifier = .init("navigationCell")
        let image = NSImageView(); let text = NSTextField(labelWithString: "")
        text.lineBreakMode = .byTruncatingTail; text.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        [image, text].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; cell.addSubview($0) }
        cell.imageView = image; cell.textField = text
        NSLayoutConstraint.activate([image.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2), image.widthAnchor.constraint(equalToConstant: 16), image.heightAnchor.constraint(equalToConstant: 16), image.centerYAnchor.constraint(equalTo: cell.centerYAnchor), text.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 5), text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4), text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)])
        return cell
    }
    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !adjustingSelection, let list = notification.object as? NSOutlineView, list.selectedRow >= 0 else { return }
        if list === filesView, let node = list.item(atRow: list.selectedRow) as? FileNode, !node.isDirectory {
            guard folder?.canOpen(node.url) == true else { fileStatus.stringValue = "This file is unavailable."; retryButton.isHidden = false; return }
            onFileSelected?(node.url)
        } else if list === outlineView, let node = list.item(atRow: list.selectedRow) as? HeadingNode { onHeadingSelected?(node.heading.id) }
    }
    func outlineViewItemWillExpand(_ notification: Notification) {
        // Restoring expanded rows after a reload must not start another refresh.
        if !adjustingSelection, let node = notification.userInfo?["NSObject"] as? FileNode { refresh(node) }
    }
    func outlineViewItemDidExpand(_ notification: Notification) {
        if let node = notification.userInfo?["NSObject"] as? HeadingNode, !adjustingSelection { collapsedHeadings.remove(node.heading.id) }
        if notification.object as? NSOutlineView === filesView { rebuildWatchers() }
    }
    func outlineViewItemDidCollapse(_ notification: Notification) {
        if let node = notification.userInfo?["NSObject"] as? HeadingNode, !adjustingSelection { collapsedHeadings.insert(node.heading.id) }
        if notification.object as? NSOutlineView === filesView { rebuildWatchers() }
    }
    private func cancelDirectoryWork() { directoryTasks.values.forEach { $0.cancel() }; directoryTasks.removeAll(); directoryWatchers.removeAll() }
    func stop() { generation += 1; cancelDirectoryWork(); onFileSelected = nil; onHeadingSelected = nil; onModeChanged = nil }
}
