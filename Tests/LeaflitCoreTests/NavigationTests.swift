import XCTest
@testable import LeaflitCore

final class NavigationTests: XCTestCase {
    func testFolderListsOnlyVisibleDirectoriesAndMarkdownWithoutFollowingLinks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let nested = root.appendingPathComponent("Guides")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        for name in ["한글 😀.MD", "A space.markdown", "note.mdown", ".hidden.md", "image.png"] {
            try Data().write(to: root.appendingPathComponent(name))
        }
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("escape"), withDestinationURL: root.deletingLastPathComponent())
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("alias.md"), withDestinationURL: root.appendingPathComponent("note.mdown"))
        let tree = FolderTree(root: root)
        let entries = try tree.entries(in: root)
        XCTAssertEqual(entries.first?.name, "Guides")
        XCTAssertEqual(Set(entries.map(\.name)), ["Guides", "한글 😀.MD", "A space.markdown", "note.mdown"])
        XCTAssertTrue(try tree.entries(in: nested).isEmpty)
        XCTAssertThrowsError(try tree.entries(in: root.deletingLastPathComponent()))
        XCTAssertThrowsError(try tree.entries(in: root.appendingPathComponent("escape")))
        XCTAssertFalse(tree.canOpen(root.appendingPathComponent("alias.md")))
        XCTAssertTrue(tree.canOpen(root.appendingPathComponent("한글 😀.MD")))
        try FileManager.default.removeItem(at: root.appendingPathComponent("note.mdown"))
        XCTAssertFalse(tree.canOpen(root.appendingPathComponent("note.mdown")))
    }

    func testOutlineBuildsSkippedLevelsAndRetainsDuplicateTitleIdentity() {
        let headings = [DocumentHeading(id: "a", title: "A", level: 1),
                        DocumentHeading(id: "deep", title: "Deep", level: 4),
                        DocumentHeading(id: "same", title: "Same", level: 2),
                        DocumentHeading(id: "same-1", title: "Same", level: 2),
                        DocumentHeading(id: "b", title: "B", level: 1)]
        let outline = HeadingOutline(headings)
        XCTAssertEqual(outline.roots.map(\.heading.id), ["a", "b"])
        XCTAssertEqual(outline.roots[0].children.map(\.heading.id), ["deep", "same", "same-1"])
        XCTAssertEqual(outline.node(id: "same-1")?.heading.title, "Same")
        XCTAssertEqual(outline.ancestors(of: "deep").map(\.heading.id), ["a"])
        XCTAssertNil(DocumentHeading(message: ["id": "x", "title": "X", "level": 9]))
        XCTAssertNil(DocumentHeading(message: ["id": "", "title": "X", "level": 1]))
    }
}
