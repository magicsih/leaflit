import XCTest
@testable import LeaflitCore

final class DocumentTests: XCTestCase {
    func testLinkClassification() throws {
        let base = URL(fileURLWithPath: "/tmp/한글 folder/start.md")
        XCTAssertEqual(DocumentPath.link("next%20page.markdown#hello", from: base), .document(URL(fileURLWithPath: "/tmp/한글 folder/next page.markdown"), "hello"))
        XCTAssertEqual(DocumentPath.link("#한글-😀", from: base), .anchor("한글-😀"))
        XCTAssertEqual(DocumentPath.link("https://example.com", from: base), .web(URL(string: "https://example.com")!))
        for bad in ["javascript:alert(1)", "data:text/html,hello", "file:///etc/passwd", "leaflit://app/index.html", "//example.com/a", "mailto:a@b.com"] {
            XCTAssertEqual(DocumentPath.link(bad, from: base), .blocked, bad)
        }
    }
    func testUTF8AndSpaces() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("한글 😀.mdown")
        try "# 안녕 😀\nhello".write(to: file, atomically: true, encoding: .utf8)
        XCTAssertEqual(try DocumentSnapshot.read(file).text, "# 안녕 😀\nhello")
        try Data([0xff, 0xfe]).write(to: file)
        XCTAssertThrowsError(try DocumentSnapshot.read(file))
    }
    func testOnlyLatestRevisionIsAccepted() {
        var gate = RevisionGate()
        let a = gate.next(), b = gate.next()
        XCTAssertFalse(gate.accepts(a))
        XCTAssertTrue(gate.accepts(b))
    }
    func testExplicitImagesOnly() {
        let base = URL(fileURLWithPath: "/tmp/docs/start.md")
        let text = "![a](images/a%20b.png)\n![b](<../photo.jpg> \"Photo\")\n![ref][pic]\n[pic]: images/c.jpeg\n![bad](https://example.com/a.png)\n![bad](secret.txt)"
        let images = LocalImages.references(in: text, document: base)
        XCTAssertEqual(images.count, 3)
        XCTAssertNotNil(images["images/a b.png"])
        XCTAssertNotNil(images["../photo.jpg"])
        XCTAssertNotNil(images["images/c.jpeg"])
        XCTAssertNil(images["secret.txt"])
    }
    func testParenthesesAndEscapedImageDestinations() {
        let text = #"![a](images/a(b).png) ![b](images/c\(d\).jpg) ![c](<images/with space.png>)"#
        let images = LocalImages.references(in: text, document: URL(fileURLWithPath: "/tmp/docs/read.md"))
        XCTAssertNotNil(images["images/a(b).png"])
        XCTAssertNotNil(images["images/c(d).jpg"])
        XCTAssertNotNil(images["images/with space.png"])
    }

}
