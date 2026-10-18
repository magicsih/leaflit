import XCTest
import AppKit
import LeaflitCore
@testable import Leaflit

@MainActor
extension ReaderTests {
    private func fileRow(_ name: String) -> Int? {
        let list = reader.sidebar.filesView
        return (0..<list.numberOfRows).first { (list.view(atColumn: 0, row: $0, makeIfNecessary: true) as? NSTableCellView)?.textField?.stringValue == name }
    }
    private func sidebarViews(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(sidebarViews) }

    func testReexpandedFolderRefreshesChangesMadeWhileCollapsed() async throws {
        let nested = dir.appendingPathComponent("Guides")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "# Old".write(to: nested.appendingPathComponent("old.md"), atomically: true, encoding: .utf8)
        reader.sidebar.chooseFolder(dir)
        try await wait { self.fileRow("Guides") != nil }
        let list = reader.sidebar.filesView
        let folder = try XCTUnwrap(list.item(atRow: try XCTUnwrap(fileRow("Guides"))))
        list.expandItem(folder)
        try await wait { self.fileRow("old.md") != nil }
        list.collapseItem(folder)
        try "# New".write(to: nested.appendingPathComponent("new.md"), atomically: true, encoding: .utf8)
        try await Task.sleep(nanoseconds: 180_000_000)
        list.expandItem(folder)
        try await wait { self.fileRow("new.md") != nil }
    }

    func testOtherDirectoryRefreshPreservesOutstandingFolderErrorAndRetry() async throws {
        let a = dir.appendingPathComponent("A"), b = dir.appendingPathComponent("B")
        for folder in [a, b] { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: a.path) }
        try "# A".write(to: a.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        try "# B".write(to: b.appendingPathComponent("b.md"), atomically: true, encoding: .utf8)
        reader.sidebar.chooseFolder(dir)
        try await wait { self.fileRow("A") != nil && self.fileRow("B") != nil }
        let list = reader.sidebar.filesView
        list.expandItem(list.item(atRow: try XCTUnwrap(fileRow("A"))))
        list.expandItem(list.item(atRow: try XCTUnwrap(fileRow("B"))))
        try await wait { self.fileRow("a.md") != nil && self.fileRow("b.md") != nil }
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: a.path)
        XCTAssertThrowsError(try FolderTree(root: dir).entries(in: a))
        func hasError() -> Bool { sidebarViews(reader.sidebar.view).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "Could not read A." } }
        try await wait { hasError() }
        try "# Added".write(to: b.appendingPathComponent("added.md"), atomically: true, encoding: .utf8)
        try await wait { self.fileRow("added.md") != nil }
        XCTAssertTrue(hasError())
        let retry = try XCTUnwrap(sidebarViews(reader.sidebar.view).compactMap { $0 as? NSButton }.first { $0.title == "Retry" })
        XCTAssertFalse(retry.isHiddenOrHasHiddenAncestor)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: a.path)
        retry.performClick(nil)
        try await wait { !hasError() && self.fileRow("a.md") != nil }
    }

    func testFilesRevalidateAfterAsyncPositionAndRestoreRejectedSelection() async throws {
        let root = dir.appendingPathComponent("Root")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let first = root.appendingPathComponent("first.md"), next = root.appendingPathComponent("next.md")
        let outside = try write("# Outside", name: "outside.md")
        try "# First".write(to: first, atomically: true, encoding: .utf8)
        try "# Next".write(to: next, atomically: true, encoding: .utf8)
        reader.open(first); try await wait { self.reader.completedRevision > 0 }
        reader.sidebar.chooseFolder(root); try await wait { self.fileRow("next.md") != nil }
        let list = reader.sidebar.filesView
        var activatedExisting = false
        reader.canNavigate = { _ in activatedExisting = true; return false }
        list.selectRowIndexes(IndexSet(integer: try XCTUnwrap(fileRow("next.md"))), byExtendingSelection: false)
        XCTAssertTrue(activatedExisting)
        XCTAssertEqual(list.selectedRow, fileRow("first.md"))
        reader.canNavigate = nil
        _ = try await js("window.Leaflit.position = async () => { await new Promise(resolve => setTimeout(resolve, 250)); return {y:0}; }; return true")
        list.selectRowIndexes(IndexSet(integer: try XCTUnwrap(fileRow("next.md"))), byExtendingSelection: false)
        try FileManager.default.removeItem(at: next)
        try FileManager.default.createSymbolicLink(at: next, withDestinationURL: outside)
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(reader.documentURL, DocumentPath.canonical(first))
        try await assertJS("return document.querySelector('h1').textContent", "First")
        XCTAssertThrowsError(try FolderDocumentReader.read(next, within: FolderTree(root: root)))
        XCTAssertEqual(try FolderDocumentReader.read(first, within: FolderTree(root: root)).text, "# First")
    }

    func testFileOpenedElsewhereDuringPositionCaptureKeepsOriginalDocument() async throws {
        let first = try write("# First", name: "first.md"), next = try write("# Next", name: "next.md")
        reader.open(first); try await wait { self.reader.completedRevision > 0 }
        reader.sidebar.chooseFolder(dir); try await wait { self.fileRow("next.md") != nil }
        _ = try await js("window.Leaflit.position = async () => { await new Promise(resolve => setTimeout(resolve, 250)); return {y:0}; }; return true")
        var openedElsewhere = false, evaluations = 0
        reader.canNavigate = { target in
            XCTAssertEqual(target, DocumentPath.canonical(next))
            evaluations += 1
            return !openedElsewhere
        }
        let list = reader.sidebar.filesView
        list.selectRowIndexes(IndexSet(integer: try XCTUnwrap(fileRow("next.md"))), byExtendingSelection: false)
        XCTAssertEqual(evaluations, 1)
        openedElsewhere = true
        try await wait { evaluations == 2 }
        XCTAssertEqual(reader.documentURL, DocumentPath.canonical(first))
        XCTAssertEqual(list.selectedRow, fileRow("first.md"))
        try await assertJS("return document.querySelector('h1').textContent", "First")
    }

    func testSidebarModesPreserveBodyAndNativeOutlineNavigates() async throws {
        let text = "# Hello **world**\n\n" + (0..<70).map { "## Section \($0)\n\nA paragraph to read.\n\n" }.joined() + "## 한글 😀\n\n## 한글 😀"
        let url = try write(text); let before = try Data(contentsOf: url)
        reader.open(url); try await wait { self.reader.completedRevision > 0 && self.reader.sidebar.headings.count == 73 }
        XCTAssertEqual(reader.sidebar.headings.first?.title, "Hello world")
        XCTAssertEqual(reader.sidebar.headings.suffix(2).map(\.id), ["한글-😀", "한글-😀-1"])
        _ = try await js("scrollTo(0, 1600); return true")
        let y = try await js("return scrollY") as? Double ?? 0
        let revision = reader.completedRevision
        reader.showFind()
        reader.sidebar.setMode(.outline)
        try await wait { self.reader.sidebar.activeHeadingID != nil }
        reader.sidebar.setMode(.files)
        reader.sidebar.setMode(.outline)
        XCTAssertEqual(reader.completedRevision, revision)
        let afterY = try await js("return scrollY") as? Double ?? 0
        XCTAssertEqual(afterY, y, accuracy: 2)
        let list = reader.sidebar.outlineView
        let row = (0..<list.numberOfRows).first { (list.view(atColumn: 0, row: $0, makeIfNecessary: true) as? NSTableCellView)?.textField?.stringValue == "Section 40" }
        list.selectRowIndexes(IndexSet(integer: try XCTUnwrap(row)), byExtendingSelection: false)
        try await wait { self.reader.sidebar.activeHeadingID == "section-40" }
        let top = try await js("return document.getElementById('section-40').getBoundingClientRect().top") as? Double ?? 100
        XCTAssertEqual(top, 24, accuracy: 2)
        _ = try await js("window.webkit.messageHandlers.leaflit.postMessage({type:'activeHeading',revision:0,id:'obsolete'}); return true")
        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(reader.sidebar.activeHeadingID, "section-40")
        XCTAssertEqual(try Data(contentsOf: url), before)
    }

    func testFilesNavigationBackAndDirectoryUpdates() async throws {
        let first = try write("# First\n\nA source document.", name: "first.md")
        let next = try write("# Next", name: "next space.md")
        reader.open(first); try await wait { self.reader.completedRevision > 0 }
        reader.sidebar.chooseFolder(dir)
        let list = reader.sidebar.filesView
        func row(_ name: String) -> Int? {
            (0..<list.numberOfRows).first { (list.view(atColumn: 0, row: $0, makeIfNecessary: true) as? NSTableCellView)?.textField?.stringValue == name }
        }
        try await wait { row("next space.md") != nil }
        let revision = reader.completedRevision
        list.selectRowIndexes(IndexSet(integer: try XCTUnwrap(row("next space.md"))), byExtendingSelection: false)
        try await wait { self.reader.documentURL == DocumentPath.canonical(next) && self.reader.completedRevision > revision }
        try await assertJS("return document.querySelector('h1').textContent", "Next")
        let nextRevision = reader.completedRevision; reader.goBack()
        try await wait { self.reader.documentURL == DocumentPath.canonical(first) && self.reader.completedRevision > nextRevision }
        let added = try write("# Added", name: "new 한글.md")
        try await wait { row("new 한글.md") != nil }
        try FileManager.default.removeItem(at: added)
        try await wait { row("new 한글.md") == nil }
        XCTAssertEqual(reader.documentURL, DocumentPath.canonical(first))
    }

    func testOutlineReplacementSaveAndLatestNavigationWins() async throws {
        let initial = try write("# Initial\n\n## Old", name: "initial.md")
        reader.open(initial); try await wait { self.reader.completedRevision > 0 }
        reader.sidebar.setMode(.outline)
        let revision = reader.completedRevision
        try "# Updated\n\n#### Deep".write(to: initial, atomically: true, encoding: .utf8)
        try await wait { self.reader.completedRevision > revision && self.reader.sidebar.headings.first?.id == "updated" }
        XCTAssertEqual(reader.sidebar.headings.map(\.level), [1, 4])
        let intermediate = try write("# Intermediate", name: "intermediate.md")
        let latest = try write("# Latest", name: "latest.md")
        reader.navigate(to: intermediate); reader.navigate(to: latest)
        try await wait { self.reader.documentURL == DocumentPath.canonical(latest) && self.reader.completedRevision == self.reader.revision.current }
        XCTAssertEqual(reader.sidebar.headings.map(\.id), ["latest"])
        try await assertJS("return document.querySelector('h1').textContent", "Latest")
    }

    func testSidebarNarrowWindowAndVisibilityPreference() async throws {
        try await loaded("# Narrow\n\nA readable document.")
        reader.window?.setContentSize(NSSize(width: 480, height: 500))
        try await wait { !self.reader.isSidebarVisible }
        XCTAssertGreaterThan(reader.webView.frame.width, 400)
        reader.window?.setContentSize(NSSize(width: 900, height: 700))
        try await wait { self.reader.isSidebarVisible }
        let menu = try XCTUnwrap(NSApp.mainMenu?.item(withTitle: "View")?.submenu)
        let item = try XCTUnwrap(menu.item(withTitle: "Toggle Sidebar"))
        XCTAssertEqual(item.keyEquivalent, "s")
        XCTAssertTrue(item.keyEquivalentModifierMask.contains([.command, .control]))
        menu.performActionForItem(at: menu.index(of: item))
        try await wait { !self.reader.isSidebarVisible }
        reader.window?.setContentSize(NSSize(width: 640, height: 500))
        reader.window?.setContentSize(NSSize(width: 900, height: 700))
        XCTAssertFalse(reader.isSidebarVisible)
        reader.toggleSidebar(); XCTAssertTrue(reader.isSidebarVisible)
    }
}
