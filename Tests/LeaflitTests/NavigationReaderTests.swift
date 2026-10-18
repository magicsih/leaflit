import XCTest
import AppKit
import LeaflitCore
@testable import Leaflit

@MainActor
extension ReaderTests {
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
        XCTAssertLessThan(abs(top), 2)
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
