import AppKit
import UniformTypeIdentifiers
import LeaflitCore

@MainActor
final class SourceEditingController: NSObject, NSTextViewDelegate {
    enum Mode { case read, source }
    let header = NSStackView()
    let conflictBar = NSStackView()
    let editorHost = NSView()
    private let modes = NSSegmentedControl(labels: ["Read", "Source"], trackingMode: .selectOne, target: nil, action: nil)
    private let status = NSTextField(labelWithString: "")
    private let message = NSTextField(wrappingLabelWithString: "")
    private let saveButton = NSButton(title: "Save", target: nil, action: nil)
    private(set) var textView: NSTextView?
    private(set) var draft: SourceDraft?
    private(set) var baseline: SourceFileSnapshot?
    private(set) var mode = Mode.read
    private(set) var isSaving = false
    private(set) var hasRequestedSource = false
    private(set) var unsavedAlert: NSAlert?
    private var copyPanel: NSSavePanel?
    private var pendingLine: Int?
    private var documentURL: URL?
    private var scope: FolderTree?
    private var scale = 1.0
    private var unavailable = false
    private let undoHistory = UndoManager()
    weak var window: NSWindow?
    var onRequestSource: (() -> Void)?
    var onPreview: ((String, String?) -> Void)?
    var onReadSelected: (() -> Void)?
    var onStateChanged: (() -> Void)?
    var onSaved: (() -> Void)?
    var isDirty: Bool { draft?.isDirty == true }
    var isBusy: Bool { isSaving || unsavedAlert != nil || copyPanel != nil }

    override init() {
        super.init()
        modes.selectedSegment = 0; modes.target = self; modes.action = #selector(modeChanged)
        modes.setAccessibilityLabel("Document mode")
        saveButton.target = self; saveButton.action = #selector(saveAction); saveButton.bezelStyle = .rounded
        status.font = .systemFont(ofSize: 11); status.textColor = .secondaryLabelColor
        status.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let spacer = NSView(); spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        header.orientation = .horizontal; header.spacing = 8; header.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        [modes, spacer, status, saveButton].forEach(header.addArrangedSubview)
        message.maximumNumberOfLines = 3
        message.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let reload = NSButton(title: "Reload from Disk…", target: self, action: #selector(reloadFromDisk))
        let copy = NSButton(title: "Save a Copy…", target: self, action: #selector(saveCopy))
        conflictBar.orientation = .vertical; conflictBar.alignment = .leading; conflictBar.spacing = 6
        conflictBar.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        conflictBar.addArrangedSubview(message); conflictBar.addArrangedSubview(NSStackView(views: [reload, copy]))
        header.isHidden = true; conflictBar.isHidden = true; editorHost.isHidden = true
    }
    func reset(url: URL, within folder: FolderTree?) {
        documentURL = url; scope = folder; draft = nil; baseline = nil
        hasRequestedSource = false; pendingLine = nil; mode = .read; unavailable = false
        textView?.string = ""; textView?.undoManager?.removeAllActions()
        message.stringValue = ""; conflictBar.isHidden = true; header.isHidden = false
        updateState()
    }
    func receive(_ snapshot: SourceFileSnapshot) throws {
        guard snapshot.url == documentURL, !isSaving else { return }
        unavailable = false
        if var existing = draft {
            let wasDirty = existing.isDirty
            try existing.observeDisk(snapshot.data, sameIdentity: baseline?.identity == snapshot.identity)
            draft = existing
            if !wasDirty {
                let changed = baseline?.identity != snapshot.identity || baseline?.data != snapshot.data
                baseline = snapshot; replaceEditorText(existing.text, clearUndo: changed)
            }
        } else {
            let initial = try SourceDraft(data: snapshot.data)
            baseline = snapshot; draft = initial; replaceEditorText(initial.text, clearUndo: true)
        }
        if draft?.hasExternalChanges == true { showMessage(SourceFileError.changed.localizedDescription) }
        else { conflictBar.isHidden = true }
        if let line = pendingLine { pendingLine = nil; revealLine(line) }
        updateState()
    }
    func readFailed() {
        unavailable = true
        if draft != nil { draft?.markUnavailable(); showMessage(SourceFileError.unavailable.localizedDescription) }
        updateState()
    }
    func select(_ mode: Mode, line: Int? = nil, anchor: String? = nil) {
        guard documentURL != nil, !isBusy else { return }
        self.mode = mode
        if mode == .source {
            createEditorIfNeeded()
            updateState(); window?.contentView?.layoutSubtreeIfNeeded()
            if let line { pendingLine = line }
            if !hasRequestedSource {
                hasRequestedSource = true; onRequestSource?()
            } else if let line, draft != nil { pendingLine = nil; revealLine(line) }
        } else {
            updateState(); window?.contentView?.layoutSubtreeIfNeeded()
            if let draft { onPreview?(draft.text, anchor) }
        }
        updateState()
        if mode == .source { window?.makeFirstResponder(textView) }
        else { onReadSelected?() }
    }
    private func createEditorIfNeeded() {
        guard textView == nil else { return }
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true; scroll.borderType = .noBorder
        let editor = NSTextView(frame: editorHost.bounds)
        editor.isRichText = false; editor.importsGraphics = false; editor.allowsUndo = true
        editor.isAutomaticQuoteSubstitutionEnabled = false; editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false; editor.isAutomaticSpellingCorrectionEnabled = false
        editor.isAutomaticLinkDetectionEnabled = false; editor.isAutomaticTextCompletionEnabled = false
        editor.isContinuousSpellCheckingEnabled = false; editor.isGrammarCheckingEnabled = false
        editor.usesFindBar = true; editor.isIncrementalSearchingEnabled = true
        editor.font = .monospacedSystemFont(ofSize: 14 * scale, weight: .regular)
        editor.textColor = .textColor; editor.backgroundColor = .textBackgroundColor
        editor.textContainerInset = NSSize(width: 16, height: 16)
        editor.isVerticallyResizable = true; editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]; editor.textContainer?.widthTracksTextView = true
        editor.minSize = .zero; editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.setAccessibilityLabel("Markdown source")
        editor.delegate = self; textView = editor; scroll.documentView = editor
        scroll.translatesAutoresizingMaskIntoConstraints = false; editorHost.addSubview(scroll)
        NSLayoutConstraint.activate([scroll.leadingAnchor.constraint(equalTo: editorHost.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: editorHost.trailingAnchor), scroll.topAnchor.constraint(equalTo: editorHost.topAnchor), scroll.bottomAnchor.constraint(equalTo: editorHost.bottomAnchor)])
    }
    private func replaceEditorText(_ text: String, clearUndo: Bool) {
        guard let editor = textView else { return }
        if !editor.string.utf8.elementsEqual(text.utf8) {
            undoHistory.disableUndoRegistration(); editor.string = text; undoHistory.enableUndoRegistration()
        }
        if clearUndo { editor.undoManager?.removeAllActions() }
    }
    func textDidChange(_ notification: Notification) {
        guard !isSaving, let textView else { return }
        draft?.replaceText(textView.string); updateState()
    }
    func undoManager(for view: NSTextView) -> UndoManager? { undoHistory }
    func stop() {
        textView?.delegate = nil; undoHistory.removeAllActions()
        textView?.string = ""; draft = nil; baseline = nil
    }
    func revealLine(_ line: Int) {
        guard line >= 0, let editor = textView, draft != nil else { return }
        let text = editor.string as NSString
        var position = 0, current = 0
        func lineRange(at start: Int) -> NSRange {
            let boundary = text.rangeOfCharacter(from: CharacterSet(charactersIn: "\r\n"), range: NSRange(location: start, length: text.length - start))
            guard boundary.location != NSNotFound else { return NSRange(location: start, length: text.length - start) }
            var end = NSMaxRange(boundary)
            if text.character(at: boundary.location) == 13 && end < text.length && text.character(at: end) == 10 { end += 1 }
            return NSRange(location: start, length: end - start)
        }
        while current < line && position < text.length { position = NSMaxRange(lineRange(at: position)); current += 1 }
        guard current == line else { return }
        let range = lineRange(at: position)
        editor.setSelectedRange(range); editor.scrollRangeToVisible(range); window?.makeFirstResponder(editor)
    }
    func find(_ action: NSTextFinder.Action) {
        guard mode == .source, let textView else { return }
        window?.makeFirstResponder(textView)
        let item = NSMenuItem(); item.tag = action.rawValue; textView.performFindPanelAction(item)
    }
    func zoom(_ scale: Double) {
        self.scale = scale
        guard let editor = textView, editor.font?.pointSize != 14 * scale else { return }
        // Presentation changes must not become Source content undo operations.
        undoHistory.disableUndoRegistration()
        editor.font = .monospacedSystemFont(ofSize: 14 * scale, weight: .regular)
        undoHistory.enableUndoRegistration()
    }
    func save(completion: @escaping (Bool) -> Void = { _ in }) {
        guard !isSaving, unsavedAlert == nil, let baseline, let draft else { completion(false); return }
        guard !draft.hasExternalChanges else { showMessage(SourceFileError.changed.localizedDescription); completion(false); return }
        guard draft.isDirty else { completion(true); return }
        isSaving = true; updateState()
        let data = draft.encodedData, scope = scope
        Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) { Result { try SourceFileWriter.save(data, replacing: baseline, within: scope) } }.value
            guard let self else { completion(false); return }
            self.isSaving = false
            switch result {
            case .success(let saved):
                self.baseline = saved; self.draft?.didSave(); self.conflictBar.isHidden = true
                self.updateState(); self.onSaved?(); completion(true)
            case .failure(let error):
                if let issue = error as? SourceFileError, issue == .changed || issue == .unavailable { self.draft?.markUnavailable() }
                self.showMessage(error.localizedDescription)
                self.updateState(); completion(false)
            }
        }
    }
    func confirmBeforeLeaving(_ completion: @escaping (Bool) -> Void) {
        guard !isBusy else { completion(false); return }
        guard isDirty, let window else { completion(!isDirty); return }
        let alert = NSAlert(); alert.messageText = "Save changes to “\(documentURL?.lastPathComponent ?? "document")”?"
        alert.informativeText = "Your changes will be lost if you discard them."
        alert.addButton(withTitle: "Save"); alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Discard Changes")
        alert.buttons[1].keyEquivalent = "\u{1b}"
        unsavedAlert = alert
        updateState()
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self else { completion(false); return }
            self.unsavedAlert = nil
            self.updateState()
            switch response {
            case .alertFirstButtonReturn: self.save(completion: completion)
            case .alertThirdButtonReturn:
                self.draft?.discardChanges()
                if let draft = self.draft {
                    self.replaceEditorText(draft.text, clearUndo: true)
                    if self.mode == .read { self.onPreview?(draft.text, nil) }
                }
                self.updateState(); completion(true)
            default: completion(false)
            }
        }
    }
    private func showMessage(_ text: String) { message.stringValue = text; conflictBar.isHidden = false }
    private func updateState() {
        modes.selectedSegment = mode == .read ? 0 : 1; modes.isEnabled = documentURL != nil && !isBusy
        editorHost.isHidden = mode != .source
        textView?.isEditable = draft != nil && !isBusy
        saveButton.isEnabled = isDirty && !isBusy && draft?.hasExternalChanges != true
        status.stringValue = isSaving ? "Saving…" : isDirty ? (mode == .read ? "Unsaved preview" : "Unsaved changes") : (mode == .source && draft == nil ? (unavailable ? "Source unavailable" : "Loading source…") : "")
        window?.isDocumentEdited = isDirty
        onStateChanged?()
    }
    @objc private func modeChanged() { select(modes.selectedSegment == 0 ? .read : .source) }
    @objc private func saveAction() { save() }
    @objc func saveCopy() {
        guard !isBusy, let draft, let window else { return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = documentURL?.deletingPathExtension().lastPathComponent.appending(" copy.md") ?? "copy.md"
        panel.allowedContentTypes = [UTType(filenameExtension: "md")!]
        panel.message = "Save a new copy. The original draft and any conflict stay open."
        let data = draft.encodedData
        copyPanel = panel
        updateState()
        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }; self.copyPanel = nil; self.updateState()
            guard response == .OK, let url = panel.url else { return }
            do { try SourceFileWriter.copy(data, to: url, excluding: self.documentURL) }
            catch { self.showMessage("Could not save a new copy. Choose a path that does not already exist. " + error.localizedDescription) }
        }
    }
    @objc private func reloadFromDisk() {
        guard !isBusy, let window else { return }
        func reload() { draft = nil; baseline = nil; unavailable = false; textView?.string = ""; textView?.undoManager?.removeAllActions(); onRequestSource?(); updateState() }
        guard isDirty else { reload(); return }
        let alert = NSAlert(); alert.messageText = "Discard your edits and reload from disk?"
        alert.informativeText = "This cannot be undone. You can save a new copy first."
        alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Discard and Reload")
        unsavedAlert = alert
        updateState()
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }; self.unsavedAlert = nil; self.updateState()
            if response == .alertSecondButtonReturn { reload() }
        }
    }
}
