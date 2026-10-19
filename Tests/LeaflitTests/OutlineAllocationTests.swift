import XCTest
import AppKit
import WebKit
import LeaflitCore
@testable import Leaflit

@MainActor
extension ReaderTests {
    func testBodyOnlySavesReuseLargeOutlineAndPreserveReadingState() async throws {
        let source = "# Guide\n\nRevision: initial.\n\n" + (0..<1_000).map {
            "## Section \($0)\n\nA reading paragraph.\n\n### Detail \($0)\n\nMore reading.\n\n"
        }.joined()
        let url = try write(source, name: "outline allocations.md")
        reader.open(url)
        try await wait { self.reader.completedRevision > 0 && self.reader.sidebar.headings.count == 2_001 }
        let sidebar = reader.sidebar, list = sidebar.outlineView
        sidebar.setMode(.outline)
        let originalRoot = try XCTUnwrap(list.item(atRow: 0) as? HeadingNode)
        let collapsed = try XCTUnwrap(originalRoot.children.first)
        list.collapseItem(collapsed)
        _ = try await js("document.getElementById('section-400').scrollIntoView(); return true")
        try await wait { self.reader.sidebar.activeHeadingID == "section-400" }
        let selectedRow = list.selectedRow
        XCTAssertGreaterThanOrEqual(selectedRow, 0)
        guard selectedRow >= 0 else { return }
        let selectedID = (list.item(atRow: selectedRow) as? HeadingNode)?.heading.id
        list.scrollRowToVisible(selectedRow)
        let listY = try XCTUnwrap(list.enclosingScrollView).contentView.bounds.origin.y
        let bodyY = try await js("return scrollY") as? Double ?? 0
        XCTAssertGreaterThan(bodyY, 0)

        for mode in [NavigationSidebarController.Mode.outline, .files] {
            sidebar.setMode(mode)
            let previous = reader.completedRevision
            let updated = source.replacingOccurrences(of: "Revision: initial.", with: "Revision: \(mode.rawValue).")
            try updated.write(to: url, atomically: true, encoding: .utf8)
            try await wait { self.reader.completedRevision > previous }
            let currentRoot = try XCTUnwrap(list.item(atRow: 0) as? HeadingNode)
            XCTAssertTrue(currentRoot === originalRoot, "Unchanged heading metadata must retain the existing native tree")
            XCTAssertFalse(list.isItemExpanded(collapsed))
            XCTAssertEqual((list.item(atRow: list.selectedRow) as? HeadingNode)?.heading.id, selectedID)
            XCTAssertEqual(list.enclosingScrollView!.contentView.bounds.origin.y, listY, accuracy: 1)
            let currentY = try await js("return scrollY") as? Double ?? 0
            XCTAssertEqual(currentY, bodyY, accuracy: 2)
            try await assertJS("return document.querySelector('article').textContent.includes('Revision: \(mode.rawValue).')", true)
            XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), updated)
        }
    }

    func testChangedHeadingMetadataAndDocumentSwitchStillRefreshOutline() throws {
        let sidebar = reader.sidebar, list = sidebar.outlineView
        sidebar.setMode(.outline)
        let first = try write("# Guide", name: "first outline.md")
        let second = try write("# Guide", name: "second outline.md")
        let guide = DocumentHeading(id: "guide", title: "Guide", level: 1)
        let entry = DocumentHeading(id: "entry", title: "Entry", level: 2)
        sidebar.setDocument(first)
        sidebar.setHeadings([guide, entry])
        let originalRoot = try XCTUnwrap(list.item(atRow: 0) as? HeadingNode)
        sidebar.setHeadings([guide, DocumentHeading(id: "entry", title: "ENTRY", level: 2)])
        let retitledRoot = try XCTUnwrap(list.item(atRow: 0) as? HeadingNode)
        XCTAssertFalse(retitledRoot === originalRoot)
        XCTAssertEqual(retitledRoot.children.first?.heading.title, "ENTRY")

        sidebar.setHeadings([guide, DocumentHeading(id: "entry", title: "ENTRY", level: 1)])
        let flattenedRoot = try XCTUnwrap(list.item(atRow: 0) as? HeadingNode)
        XCTAssertTrue(flattenedRoot.children.isEmpty)
        XCTAssertEqual((list.item(atRow: 1) as? HeadingNode)?.heading.level, 1)
        sidebar.setHeadings([guide, DocumentHeading(id: "entry-1", title: "ENTRY", level: 1)])
        XCTAssertEqual((list.item(atRow: 1) as? HeadingNode)?.heading.id, "entry-1")

        sidebar.setHeadings([guide, entry])
        list.collapseItem(try XCTUnwrap(list.item(atRow: 0)))
        sidebar.setActiveHeading("entry")
        sidebar.setDocument(second)
        XCTAssertTrue(sidebar.headings.isEmpty)
        XCTAssertEqual(list.numberOfRows, 0)
        XCTAssertNil(sidebar.activeHeadingID)
        func texts(_ view: NSView) -> [String] {
            (view as? NSTextField).map { [$0.stringValue] } ?? view.subviews.flatMap(texts)
        }
        XCTAssertTrue(texts(sidebar.view).contains("No headings in this document"))
        sidebar.setHeadings([guide, entry])
        let nextDocumentRoot = try XCTUnwrap(list.item(atRow: 0) as? HeadingNode)
        XCTAssertTrue(list.isItemExpanded(nextDocumentRoot), "A new document must not inherit the previous document's collapsed headings")
        XCTAssertEqual(list.numberOfRows, 2)
        XCTAssertFalse(texts(sidebar.view).contains("No headings in this document"))
        sidebar.setHeadings([])
        sidebar.setHeadings([])
        XCTAssertTrue(texts(sidebar.view).contains("No headings in this document"))
        sidebar.setDocument(nil)
        XCTAssertTrue(texts(sidebar.view).contains("Open a Markdown file to see its headings."))
    }

    func testClosingOneReaderReleasesItsViewsWithoutStoppingAnotherReader() async throws {
        try await loaded("# Survivor\n\nA stable searchable paragraph.")
        let url = try write("# Closed document\n\nA read-only lifetime fixture.", name: "closed document.md")
        let original = try Data(contentsOf: url)
        let suite = "Leaflit Lifetime \(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suite))
        preferences.removePersistentDomain(forName: suite)
        var closing: ReaderController? = ReaderController(preferences: preferences)
        var reopened: ReaderController?
        defer {
            closing?.close(); reopened?.close()
            preferences.removePersistentDomain(forName: suite)
        }
        weak var releasedReader = closing
        weak var releasedWindow = closing?.window
        weak var releasedWebView = closing?.webView
        weak var releasedSidebar = closing?.sidebar
        closing?.open(url); closing?.showWindow(nil)
        try await wait { (closing?.completedRevision ?? 0) > 0 }
        closing?.close(); closing = nil
        try await wait({ releasedReader == nil && releasedWindow == nil && releasedWebView == nil && releasedSidebar == nil }, seconds: 5)

        try await assertJS("return document.querySelector('h1').textContent", "Survivor")
        let found: Bool = await withCheckedContinuation { continuation in
            self.reader.webView.find("searchable", configuration: WKFindConfiguration()) {
                continuation.resume(returning: $0.matchFound)
            }
        }
        XCTAssertTrue(found)
        reopened = ReaderController(preferences: preferences)
        reopened?.open(url); reopened?.showWindow(nil)
        try await wait { (reopened?.completedRevision ?? 0) > 0 }
        let reopenedView = try XCTUnwrap(reopened?.webView)
        let title = try await reopenedView.callAsyncJavaScript("return document.querySelector('h1').textContent", arguments: [:], in: nil, contentWorld: .page) as? String
        XCTAssertEqual(title, "Closed document")
        XCTAssertEqual(try Data(contentsOf: url), original)
    }
}
