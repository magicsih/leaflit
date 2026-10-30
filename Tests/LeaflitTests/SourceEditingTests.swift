import XCTest
import AppKit
import LeaflitCore
@testable import Leaflit

@MainActor
extension ReaderTests {
    func source(_ text: String) async throws {
        reader.showSource()
        try await wait { self.reader.editing.draft != nil }
        _ = try XCTUnwrap(reader.editing.draft, "Source must load before editing a test draft")
        let editor = try XCTUnwrap(reader.editing.textView)
        editor.insertText(text, replacementRange: NSRange(location: 0, length: (editor.string as NSString).length))
        XCTAssertTrue(reader.editing.isDirty)
    }
    func testLazySourcePreviewExplicitSaveAndUndo() async throws {
        let original = Data([0xef, 0xbb, 0xbf]) + Data("# Original 한글 😀\r\n".utf8)
        let url = dir.appendingPathComponent("BOM space.md"); try original.write(to: url)
        reader.open(url); try await wait { self.reader.completedRevision > 0 }
        XCTAssertNil(reader.editing.textView)
        try await source("# Draft 한글 😀\r\n")
        XCTAssertTrue(reader.editing.textView?.undoManager?.canUndo == true)
        XCTAssertEqual(try Data(contentsOf: url), original)
        let old = reader.completedRevision; reader.showRead()
        try await wait { self.reader.completedRevision > old }
        try await assertJS("return document.querySelector('h1').textContent", "Draft 한글 😀")
        XCTAssertEqual(try Data(contentsOf: url), original)
        let done = expectation(description: "explicit save")
        reader.editing.save { saved in XCTAssertTrue(saved); done.fulfill() }
        await fulfillment(of: [done], timeout: 10)
        XCTAssertFalse(reader.editing.isDirty)
        XCTAssertEqual(try Data(contentsOf: url), Data([0xef, 0xbb, 0xbf]) + Data("# Draft 한글 😀\r\n".utf8))
        XCTAssertTrue(reader.editing.textView?.undoManager?.canUndo == true)
        reader.showSource()
        reader.editing.textView?.undoManager?.undo()
        XCTAssertEqual(reader.editing.textView?.string, "# Original 한글 😀\r\n")
        try await wait { self.reader.editing.isDirty }
        XCTAssertTrue(reader.editing.isDirty)
        XCTAssertEqual(reader.editing.draft?.text, "# Original 한글 😀\r\n")
        reader.editing.textView?.undoManager?.redo()
        XCTAssertFalse(reader.editing.isDirty)
    }
    func testSaveSeparatesTypingGroupsAndSameByteReplacementKeepsUndo() async throws {
        let url = try write("# Original"); reader.open(url); try await wait { self.reader.completedRevision > 0 }
        reader.showSource(); try await wait { self.reader.editing.draft != nil }
        let editor = try XCTUnwrap(reader.editing.textView), manager = try XCTUnwrap(editor.undoManager)
        // Direct XCTest insertText calls share a run-loop turn. Model two distinct native input events.
        manager.groupsByEvent = false
        func typeEvent(_ value: String, range: NSRange) {
            manager.beginUndoGrouping(); editor.insertText(value, replacementRange: range); manager.endUndoGrouping()
        }
        typeEvent("# Saved", range: NSRange(location: 0, length: (editor.string as NSString).length))
        let done = expectation(description: "save typing boundary")
        reader.editing.save { saved in XCTAssertTrue(saved); done.fulfill() }
        await fulfillment(of: [done], timeout: 10)
        try Data("# Saved".utf8).write(to: url, options: .atomic)
        let identity = try SourceFileSnapshot.read(url, within: nil).identity
        try await wait { self.reader.editing.baseline?.identity == identity }
        typeEvent(" after save", range: NSRange(location: (editor.string as NSString).length, length: 0))
        editor.breakUndoCoalescing(); editor.undoManager?.undo()
        XCTAssertEqual(editor.string, "# Saved"); XCTAssertFalse(reader.editing.isDirty)
        editor.undoManager?.undo()
        XCTAssertEqual(editor.string, "# Original"); XCTAssertTrue(reader.editing.isDirty)
        editor.undoManager?.redo()
        XCTAssertEqual(editor.string, "# Saved"); XCTAssertFalse(reader.editing.isDirty)
        XCTAssertEqual(try String(contentsOf: url), "# Saved")
    }
    func testCancelAfterWatcherUpdateRestoresEditorAndKeepsSinglePrompt() async throws {
        try await loaded("# Original"); try await source("# Unsaved")
        var accepted: Bool?
        reader.editing.confirmBeforeLeaving { accepted = $0 }
        let alert = try XCTUnwrap(reader.editing.unsavedAlert)
        reader.editing.readFailed()
        XCTAssertFalse(reader.editing.textView?.isEditable == true)
        reader.editing.confirmBeforeLeaving { XCTAssertFalse($0) }
        XCTAssertTrue(reader.editing.unsavedAlert === alert)
        alert.buttons[1].performClick(nil)
        try await wait { accepted != nil }
        XCTAssertEqual(accepted, false); XCTAssertTrue(reader.editing.isDirty)
        XCTAssertTrue(reader.editing.textView?.isEditable == true)
    }
    func testSourceOutlineOpensCurrentUnsavedReadPreviewAtAnchor() async throws {
        try await loaded("# Original\n\n## Target\n\nEnd")
        reader.sidebar.setMode(.outline)
        try await source("# Draft\n\n" + String(repeating: "Paragraph.\n\n", count: 80) + "## Target\n\n" + String(repeating: "Tail.\n\n", count: 40))
        let previous = reader.completedRevision
        reader.sidebar.onHeadingSelected?("target")
        try await wait { self.reader.completedRevision > previous && self.reader.completedRevision == self.reader.revision.current }
        XCTAssertEqual(reader.editing.mode, .read); XCTAssertTrue(reader.editing.isDirty)
        try await assertJS("return document.querySelector('h1').textContent", "Draft")
        let top = try await js("return document.getElementById('target').getBoundingClientRect().top") as? Double ?? 1000
        XCTAssertEqual(top, 24, accuracy: 2)
        XCTAssertTrue((reader.window?.firstResponder as? NSView)?.isDescendant(of: reader.webView) == true)
    }
    func testOutlineCanReturnToExistingReadAnchorWhileFirstSourceReadIsPending() async throws {
        try await loaded("# Original\n\n" + String(repeating: "Before.\n\n", count: 60) + "## Target\n\n" + String(repeating: "After.\n\n", count: 40))
        let started = expectation(description: "pending first Source"), gate = DispatchSemaphore(value: 0)
        reader.sourceReader = { url, folder in
            let snapshot = try SourceFileSnapshot.read(url, within: folder)
            started.fulfill(); _ = gate.wait(timeout: .now() + 10); return snapshot
        }
        reader.showSource(); await fulfillment(of: [started], timeout: 5)
        reader.sidebar.onHeadingSelected?("target")
        XCTAssertEqual(reader.editing.mode, .read)
        let top = try await js("return document.getElementById('target').getBoundingClientRect().top") as? Double ?? 1000
        XCTAssertEqual(top, 24, accuracy: 2)
        gate.signal(); reader.sourceReader = SourceFileSnapshot.read
        try await wait { self.reader.editing.draft != nil }
    }
    func testMultiwindowQuitDiscardThenCancelSynchronizesDiscardedEditor() async throws {
        try await loaded("# First"); try await source("# First draft")
        let second = ReaderController(preferences: UserDefaults(suiteName: dir.lastPathComponent)!)
        defer { second.close() }
        let url = try write("# Second", name: "second.md"); second.open(url); second.showWindow(nil)
        second.showSource(); try await wait { second.editing.draft != nil }
        let editor = try XCTUnwrap(second.editing.textView)
        editor.insertText("# Second draft", replacementRange: NSRange(location: 0, length: (editor.string as NSString).length))
        let delegate = AppDelegate(readers: [reader, second]), done = expectation(description: "cancel quit")
        delegate.resolveUnsavedDocuments { accepted in XCTAssertFalse(accepted); done.fulfill() }
        reader.editing.unsavedAlert?.buttons[2].performClick(nil)
        try await wait { second.editing.unsavedAlert != nil }
        second.editing.unsavedAlert?.buttons[1].performClick(nil)
        await fulfillment(of: [done], timeout: 5)
        XCTAssertEqual(delegate.readers.count, 2)
        XCTAssertFalse(reader.editing.isDirty); XCTAssertEqual(reader.editing.textView?.string, "# First")
        XCTAssertTrue(second.editing.isDirty); XCTAssertEqual(try String(contentsOf: url), "# Second")
    }
    func testQuitStopsOnFailedSaveWithoutDiscardingDraft() async throws {
        let url = try write("# Original"); reader.open(url); try await wait { self.reader.completedRevision > 0 }
        try await source("# Unsaved")
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: url.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path) }
        let delegate = AppDelegate(readers: [reader]), done = expectation(description: "failed quit save")
        delegate.resolveUnsavedDocuments { accepted in XCTAssertFalse(accepted); done.fulfill() }
        reader.editing.unsavedAlert?.buttons[0].performClick(nil)
        await fulfillment(of: [done], timeout: 10)
        XCTAssertEqual(delegate.readers.count, 1); XCTAssertTrue(reader.editing.isDirty)
        XCTAssertTrue(reader.window?.isVisible == true); XCTAssertEqual(try String(contentsOf: url), "# Original")
    }
    func testLargeSourceEditsStayInMemoryUntilExplicitSave() async throws {
        for size in [1024 * 1024, 5 * 1024 * 1024] {
            let row = "A source paragraph with 한글 😀.\r\n"
            let text = "# Large Source\r\n\r\n" + String(repeating: row, count: size / row.utf8.count)
            let url = try write(text, name: "source-\(size).md"), before = try Data(contentsOf: url)
            let previous = reader.completedRevision; reader.open(url)
            try await wait({ self.reader.completedRevision > previous }, seconds: 60)
            reader.showSource(); try await wait({ self.reader.editing.draft != nil }, seconds: 60)
            let editor = try XCTUnwrap(reader.editing.textView)
            editor.insertText("Appended.\r\n", replacementRange: NSRange(location: (editor.string as NSString).length, length: 0))
            XCTAssertTrue(reader.editing.isDirty); XCTAssertEqual(try Data(contentsOf: url), before)
            let done = expectation(description: "save large source")
            reader.editing.save { saved in XCTAssertTrue(saved); done.fulfill() }
            await fulfillment(of: [done], timeout: 20)
            XCTAssertEqual(try Data(contentsOf: url), before + Data("Appended.\r\n".utf8))
        }
    }
    func testDirtyExternalReplacementAndAppearanceKeepDraftAndUndo() async throws {
        let url = try write("# Original"); reader.open(url); try await wait { self.reader.completedRevision > 0 }
        try await source("# My draft")
        try "# External".write(to: url, atomically: true, encoding: .utf8)
        try await wait { self.reader.editing.draft?.hasExternalChanges == true }
        reader.showRead()
        reader.window?.appearance = NSAppearance(named: .darkAqua)
        try await assertJS("for(let n=0;n<100 && !matchMedia('(prefers-color-scheme: dark)').matches;n++) await new Promise(r=>setTimeout(r,10)); return matchMedia('(prefers-color-scheme: dark)').matches", true)
        let previous = reader.completedRevision; reader.retry()
        try await wait { self.reader.completedRevision > previous && self.reader.completedRevision == self.reader.revision.current }
        XCTAssertEqual(reader.editing.draft?.text, "# My draft")
        try await assertJS("return document.querySelector('h1').textContent", "My draft")
        let done = expectation(description: "conflict rejected")
        reader.editing.save { saved in XCTAssertFalse(saved); done.fulfill() }
        await fulfillment(of: [done], timeout: 10)
        XCTAssertEqual(try String(contentsOf: url), "# External")
        XCTAssertEqual(reader.editing.draft?.text, "# My draft")
        XCTAssertTrue(reader.editing.textView?.undoManager?.canUndo == true)
    }
    func testCancelledBackPreservesHistoryAndDirtyDraft() async throws {
        let first = try write("# First", name: "first.md"), next = try write("# Next", name: "next.md")
        reader.open(first); try await wait { self.reader.completedRevision > 0 }
        let previous = reader.completedRevision
        reader.navigate(to: next); try await wait { self.reader.documentURL == DocumentPath.canonical(next) && self.reader.completedRevision > previous }
        try await source("# Unsaved Next")
        reader.goBack(); try await wait { self.reader.editing.unsavedAlert != nil }
        reader.editing.unsavedAlert?.buttons[1].performClick(nil)
        try await wait { self.reader.editing.unsavedAlert == nil }
        XCTAssertEqual(reader.documentURL, DocumentPath.canonical(next)); XCTAssertTrue(reader.editing.isDirty)
        reader.goBack(); try await wait { self.reader.editing.unsavedAlert != nil }
        reader.editing.unsavedAlert?.buttons[2].performClick(nil)
        try await wait { self.reader.documentURL == DocumentPath.canonical(first) }
        XCTAssertFalse(reader.editing.isDirty); XCTAssertEqual(reader.editing.mode, .read)
    }
    func testLateReadCannotReplaceNewEditsAndCancelledOpenKeepsDraft() async throws {
        let url = try write("# Original"); reader.open(url); try await wait { self.reader.completedRevision > 0 }
        reader.showSource(); try await wait { self.reader.editing.draft != nil }
        let started = expectation(description: "source read started"), gate = DispatchSemaphore(value: 0)
        reader.sourceReader = { url, folder in
            let snapshot = try SourceFileSnapshot.read(url, within: folder)
            started.fulfill(); _ = gate.wait(timeout: .now() + 10); return snapshot
        }
        reader.reload(preserve: true)
        await fulfillment(of: [started], timeout: 5)
        reader.editing.textView?.insertText("# Keep new edits", replacementRange: NSRange(location: 0, length: 10))
        gate.signal(); reader.sourceReader = SourceFileSnapshot.read
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(reader.editing.draft?.text, "# Keep new edits")
        let next = try write("# Next", name: "next.md")
        reader.open(next); try await wait { self.reader.editing.unsavedAlert != nil }
        reader.editing.unsavedAlert?.buttons[1].performClick(nil)
        try await wait { self.reader.editing.unsavedAlert == nil }
        XCTAssertEqual(reader.documentURL, DocumentPath.canonical(url))
        XCTAssertTrue(reader.editing.isDirty)
        reader.sourceReader = SourceFileSnapshot.read
    }
    func testLateSourceReadCannotAdoptContentAfterDocumentSwitch() async throws {
        let url = try write("# Original"), next = try write("# Next", name: "next.md")
        reader.open(url); try await wait { self.reader.completedRevision > 0 }
        reader.showSource(); try await wait { self.reader.editing.draft != nil }
        _ = try XCTUnwrap(reader.editing.draft)
        let started = expectation(description: "held source read"), gate = DispatchSemaphore(value: 0)
        reader.sourceReader = { url, folder in
            let snapshot = try SourceFileSnapshot.read(url, within: folder)
            started.fulfill(); _ = gate.wait(timeout: .now() + 10); return snapshot
        }
        reader.reload(preserve: true); await fulfillment(of: [started], timeout: 5)
        let previous = reader.completedRevision; reader.open(next)
        gate.signal(); reader.sourceReader = SourceFileSnapshot.read
        try await wait { self.reader.completedRevision > previous && self.reader.documentURL == DocumentPath.canonical(next) }
        try await Task.sleep(nanoseconds: 150_000_000)
        try await assertJS("return document.querySelector('h1').textContent", "Next")
        XCTAssertNil(reader.editing.draft)
    }
    func testSourceLineMappingAndLazyZoomUseParserLineBoundaries() async throws {
        let raw = "# One\u{85}Two\u{2028}Three\u{2029}Four\r\n\r\n```mermaid\r\ninvalid!\r\n```\r\n"
        try await loaded(raw)
        for _ in 0..<10 { reader.zoomIn() }
        reader.editing.select(.source, line: 2)
        try await wait { self.reader.editing.draft != nil }
        let editor = try XCTUnwrap(reader.editing.textView)
        XCTAssertEqual(editor.font?.pointSize ?? 0, 28, accuracy: 0.01)
        XCTAssertEqual((editor.string as NSString).substring(to: editor.selectedRange().location), "# One\u{85}Two\u{2028}Three\u{2029}Four\r\n\r\n")
        reader.hideFind(); XCTAssertTrue(reader.window?.firstResponder === editor)
    }
    func testDiscardSynchronizesEditorEvenWhenFinalNavigationIsRejected() async throws {
        let url = try write("# Original"), next = try write("# Next", name: "next.md")
        reader.open(url); try await wait { self.reader.completedRevision > 0 }
        try await source("# Unsaved")
        reader.navigate(to: next); try await wait { self.reader.editing.unsavedAlert != nil }
        reader.canNavigate = { _ in false }
        reader.editing.unsavedAlert?.buttons[2].performClick(nil)
        try await wait { self.reader.editing.unsavedAlert == nil }
        XCTAssertEqual(reader.documentURL, DocumentPath.canonical(url))
        XCTAssertEqual(reader.editing.textView?.string, "# Original")
        XCTAssertEqual(reader.editing.draft?.text, "# Original"); XCTAssertFalse(reader.editing.isDirty)
        XCTAssertFalse(reader.editing.textView?.undoManager?.canUndo == true)
    }
    func testDraftPreviewRebuildsImageAllowlistAndKeepsHostileInputInert() async throws {
        try await loaded("# Original\n\n![old](old.png)")
        try await source("# Draft\n\n![new](new.png)\n\n<script>window.compromised=true</script>\n\n![remote](https://example.com/private.png)\n\n[x](javascript:alert(1))")
        let previous = reader.completedRevision; reader.showRead()
        try await wait { self.reader.completedRevision > previous }
        XCTAssertEqual(Set(reader.resources.images.keys), ["new.png"])
        try await assertJS("return window.compromised === undefined", true)
        try await assertJS("return document.querySelectorAll('img[src^=https],script:not([src]),a[href^=javascript]').length", 0)
    }
    func testRendererRestartRetainsDraftAndUndo() async throws {
        try await loaded("# Original")
        try await source("# Unsaved")
        reader.showRead(); let previous = reader.completedRevision
        reader.webViewWebContentProcessDidTerminate(reader.webView); reader.retry()
        try await wait { self.reader.completedRevision > previous && self.reader.completedRevision == self.reader.revision.current }
        XCTAssertEqual(reader.editing.draft?.text, "# Unsaved"); XCTAssertTrue(reader.editing.isDirty)
        XCTAssertTrue(reader.editing.textView?.undoManager?.canUndo == true)
        try await assertJS("return document.querySelector('h1').textContent", "Unsaved")
    }
    func testFirstSourceLoadWorksWhileRendererIsUnavailable() async throws {
        try await loaded("# Original 한글 😀\r\n")
        XCTAssertNil(reader.editing.draft)
        reader.webViewWebContentProcessDidTerminate(reader.webView)
        reader.showSource()
        try await wait { self.reader.editing.draft != nil }
        XCTAssertEqual(reader.editing.textView?.string, "# Original 한글 😀\r\n")
        XCTAssertTrue(reader.editing.textView?.isEditable == true)
        XCTAssertFalse(reader.editing.isDirty)
    }
    func testFailedSaveCancelsNavigationAndClose() async throws {
        let url = try write("# Original"), next = try write("# Next", name: "next.md")
        reader.open(url); try await wait { self.reader.completedRevision > 0 }
        try await source("# Unsaved")
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: url.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path) }
        reader.navigate(to: next); try await wait { self.reader.editing.unsavedAlert != nil }
        reader.editing.unsavedAlert?.buttons[0].performClick(nil)
        try await wait { self.reader.editing.unsavedAlert == nil && !self.reader.editing.isSaving }
        XCTAssertEqual(reader.documentURL, DocumentPath.canonical(url)); XCTAssertTrue(reader.editing.isDirty)
        reader.window?.performClose(nil); try await wait { self.reader.editing.unsavedAlert != nil }
        reader.editing.unsavedAlert?.buttons[0].performClick(nil)
        try await wait { self.reader.editing.unsavedAlert == nil && !self.reader.editing.isSaving }
        XCTAssertTrue(reader.window?.isVisible == true); XCTAssertTrue(reader.editing.isDirty)
        XCTAssertEqual(try String(contentsOf: url), "# Original")
    }
    func testErrorEditSourceTargetsSecondIdenticalBlock() async throws {
        let raw = "# 😀\r\n\r\n```mermaid\r\ninvalid!\r\n```\r\n\r\n```mermaid\r\ninvalid!\r\n```\r\n"
        let url = dir.appendingPathComponent("errors.md"); try (Data([0xef, 0xbb, 0xbf]) + Data(raw.utf8)).write(to: url)
        reader.open(url); try await wait { self.reader.completedRevision > 0 }
        try await assertJS("return document.querySelectorAll('.edit-source').length", 2)
        _ = try await js("document.querySelectorAll('.edit-source')[1].click(); return true")
        try await wait { self.reader.editing.textView != nil && self.reader.editing.draft != nil }
        let editor = try XCTUnwrap(reader.editing.textView), range = editor.selectedRange()
        let prefix = (editor.string as NSString).substring(to: range.location)
        XCTAssertEqual(prefix, "# 😀\r\n\r\n```mermaid\r\ninvalid!\r\n```\r\n\r\n")
        XCTAssertEqual(try Data(contentsOf: url), Data([0xef, 0xbb, 0xbf]) + Data(raw.utf8))
    }
    func testFrontMatterStaysInSourceWhileReadAndErrorRepairUseOnlyTheBody() async throws {
        let metadata = "---\r\ntitle: Internal metadata\r\ntags: [draft, notes]\r\n---\r\n\r\n"
        let raw = metadata + "# Project notes\r\n\r\n```mermaid\r\ninvalid!\r\n```\r\n"
        let original = Data([0xef, 0xbb, 0xbf]) + Data(raw.utf8)
        let url = dir.appendingPathComponent("Front matter.md"); try original.write(to: url)
        reader.open(url); try await wait { self.reader.completedRevision > 0 }
        XCTAssertEqual(reader.window?.title, "Front matter.md")
        try await assertJS("return document.querySelector('article').firstElementChild.textContent", "Project notes")
        try await assertJS("return document.querySelectorAll('h1,h2,h3,h4,h5,h6').length", 1)
        try await assertJS("return document.querySelector('article').textContent.includes('Internal metadata')", false)
        try await assertJS("return document.querySelector('h1').dataset.sourceLine", "5")
        _ = try await js("document.querySelector('.edit-source').click(); return true")
        try await wait { self.reader.editing.draft != nil }
        let editor = try XCTUnwrap(reader.editing.textView)
        XCTAssertEqual(editor.string, raw)
        XCTAssertEqual((editor.string as NSString).substring(to: editor.selectedRange().location), metadata + "# Project notes\r\n\r\n")
        XCTAssertEqual(try Data(contentsOf: url), original)

        let edited = raw.replacingOccurrences(of: "# Project notes", with: "# Updated notes")
        try await source(edited)
        let previous = reader.completedRevision; reader.showRead()
        try await wait { self.reader.completedRevision > previous }
        try await assertJS("return document.querySelector('h1').textContent", "Updated notes")
        try await assertJS("return document.querySelector('article').textContent.includes('Internal metadata')", false)
        XCTAssertEqual(try Data(contentsOf: url), original)
        let saved = expectation(description: "explicit save preserves front matter")
        reader.editing.save { success in XCTAssertTrue(success); saved.fulfill() }
        await fulfillment(of: [saved], timeout: 10)
        XCTAssertEqual(try Data(contentsOf: url), Data([0xef, 0xbb, 0xbf]) + Data(edited.utf8))
    }
}
