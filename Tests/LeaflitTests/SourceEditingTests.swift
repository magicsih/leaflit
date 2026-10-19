import XCTest
import AppKit
import LeaflitCore
@testable import Leaflit

@MainActor
extension ReaderTests {
    func source(_ text: String) async throws {
        reader.showSource()
        try await wait { self.reader.editing.draft != nil }
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
        reader.showSource(); reader.editing.textView?.undoManager?.undo()
        XCTAssertTrue(reader.editing.isDirty)
        XCTAssertEqual(reader.editing.draft?.text, "# Original 한글 😀\r\n")
        reader.editing.textView?.undoManager?.redo()
        XCTAssertFalse(reader.editing.isDirty)
    }
    func testDirtyExternalReplacementAndAppearanceKeepDraftAndUndo() async throws {
        let url = try write("# Original"); reader.open(url); try await wait { self.reader.completedRevision > 0 }
        try await source("# My draft")
        try "# External".write(to: url, atomically: true, encoding: .utf8)
        try await wait { self.reader.editing.draft?.hasExternalChanges == true }
        reader.showRead(); reader.window?.appearance = NSAppearance(named: .darkAqua); reader.retry()
        try await wait { self.reader.completedRevision == self.reader.revision.current }
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
        reader.navigate(to: next); try await wait { self.reader.documentURL == DocumentPath.canonical(next) }
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
}
