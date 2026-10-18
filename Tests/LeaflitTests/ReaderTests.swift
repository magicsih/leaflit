import XCTest
import AppKit
import WebKit
@testable import Leaflit
import LeaflitCore

@MainActor
final class ReaderTests: XCTestCase {
    var reader: ReaderController!
    var dir: URL!
    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("Leaflit Tests \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        reader = ReaderController(); reader.showWindow(nil)
    }
    override func tearDown() async throws {
        reader.close(); reader = nil
        try? FileManager.default.removeItem(at: dir)
    }
    func write(_ text: String, name: String = "한글 😀 file.md") throws -> URL {
        let url = dir.appendingPathComponent(name); try text.write(to: url, atomically: true, encoding: .utf8); return url
    }
    func wait(_ condition: @escaping () -> Bool, seconds: Double = 20, file: StaticString = #filePath, line: UInt = #line) async throws {
        let end = Date().addingTimeInterval(seconds)
        while !condition() && Date() < end { try await Task.sleep(nanoseconds: 30_000_000) }
        XCTAssertTrue(condition(), "Timed out", file: file, line: line)
    }
    func js(_ source: String) async throws -> Any? {
        try await reader.webView.callAsyncJavaScript(source, arguments: [:], in: nil, contentWorld: .page)
    }
    func assertJS<T: Equatable>(_ source: String, _ expected: T?, file: StaticString = #filePath, line: UInt = #line) async throws {
        let value = try await js(source) as? T
        XCTAssertEqual(value, expected, file: file, line: line)
    }
    func loaded(_ text: String) async throws {
        reader.open(try write(text)); try await wait { self.reader.completedRevision > 0 }
    }
    func testOfflineMarkdownMathAndMermaid() async throws {
        try await loaded("# 안녕 😀\n\n~~old~~\n\n- [x] done\n\n|a|b|\n|-|-|\n|1|2|\n\n$x^2$ and \\(y\\)\n\n$$z$$\n\n\\[w\\]\n\n```mermaid\nflowchart LR\n A[Open] --> B[Read]\n```\n")
        try await assertJS("return document.querySelectorAll('.katex').length", 4)
        try await assertJS("return document.querySelectorAll('.diagram svg').length", 1)
        try await assertJS("return document.querySelector('input').disabled", true)
        try await assertJS("return document.querySelectorAll('table').length", 1)
    }
    func testBadSyntaxAndHostileContent() async throws {
        try await loaded("# Safety\n\n<script>window.compromised=true</script>\n\n![remote](https://example.com/x.png)\n\n[x](javascript:alert(1))\n\n$\\notACommand{x}$\n\n```mermaid\nnot valid syntax!\n```\n")
        try await assertJS("return window.compromised === undefined", true)
        try await assertJS("return document.querySelectorAll('.render-error').length", 2)
        try await assertJS("return document.querySelectorAll('img[src^=https],script:not([src])').length", 0)
        try await assertJS("return document.querySelectorAll('.image-fallback').length", 1)
    }
    func testRelativeNavigationAndBack() async throws {
        let first = try write("# First\n\n[Next](second%20page.md#target)", name: "first.md")
        _ = try write("# Second\n\n## Target\n\nHello", name: "second page.md")
        reader.open(first); try await wait { self.reader.completedRevision > 0 }
        reader.navigate("second%20page.md#target")
        try await wait { self.reader.documentURL?.lastPathComponent == "second page.md" && self.reader.completedRevision == self.reader.revision.current }
        let title = try await js("return document.querySelector('h1').textContent") as? String
        XCTAssertEqual(title, "Second")
        reader.goBack()
        try await wait { self.reader.documentURL == first && self.reader.completedRevision == self.reader.revision.current }
        try await assertJS("return document.querySelector('h1').textContent", "First")
    }
    func testAtomicSaveRapidUpdatesDeletionAndRecovery() async throws {
        let url = try write("# Initial")
        reader.open(url); try await wait { self.reader.completedRevision > 0 }
        let original = reader.completedRevision
        for n in 1...20 { try "# Update \(n)".write(to: url, atomically: true, encoding: .utf8) }
        try await wait { self.reader.completedRevision > original }
        try await assertJS("return document.querySelector('h1').textContent", "Update 20")
        try FileManager.default.removeItem(at: url)
        try await Task.sleep(nanoseconds: 250_000_000)
        try await assertJS("return document.querySelector('h1').textContent", "Update 20")
        let old = reader.completedRevision
        try "# Recovered".write(to: url, atomically: true, encoding: .utf8)
        try await wait { self.reader.completedRevision > old }
        try await assertJS("return document.querySelector('h1').textContent", "Recovered")
    }
    func testLatestRenderWins() async throws {
        let heavy = try write(String(repeating: "```mermaid\nflowchart LR\n A --> B\n```\n", count: 8), name: "heavy.md")
        reader.open(heavy)
        try await wait { self.reader.displayedRevision > 0 }
        let last = try write("# Latest", name: "latest.md")
        reader.open(last)
        try await wait { self.reader.completedRevision == self.reader.revision.current && self.reader.completedRevision > 1 }
        try await Task.sleep(nanoseconds: 500_000_000)
        try await assertJS("return document.querySelector('h1').textContent", "Latest")
        try await assertJS("return document.querySelectorAll('svg').length", 0)
    }
    func testImagesAndScrollRestoration() async throws {
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=")!
        try png.write(to: dir.appendingPathComponent("a b.png"))
        let text = "# Pictures\n\n![pixel](a%20b.png)\n\n![missing](missing.png)\n\n" + (0..<100).map { "## Section \($0)\n\nParagraph \($0)\n\n" }.joined()
        let url = try write(text); reader.open(url); try await wait { self.reader.completedRevision > 0 }
        try await Task.sleep(nanoseconds: 300_000_000)
        try await assertJS("return document.querySelector('img').naturalWidth", 1)
        try await assertJS("return document.querySelectorAll('.image-fallback').length", 1)
        _ = try await js("scrollTo(0, 1800)")
        let before = try await js("return window.Leaflit.position().line") as? Int
        let old = reader.completedRevision
        try (text + "\nEnd").write(to: url, atomically: true, encoding: .utf8)
        try await wait { self.reader.completedRevision > old }
        try await assertJS("return window.Leaflit.position().line", before)
    }
    func testSourceUnchangedAndLargeDocuments() async throws {
        for size in [1024 * 1024, 5 * 1024 * 1024] {
            let row = "A paragraph with **bold** and 한글 😀.\n\n"
            let text = "# Large\n\n" + String(repeating: row, count: size / row.utf8.count)
            let url = try write(text, name: "large.md"); let before = try Data(contentsOf: url)
            let old = reader.completedRevision; reader.open(url)
            try await wait({ self.reader.completedRevision > old }, seconds: 60)
            XCTAssertEqual(try Data(contentsOf: url), before)
            try await assertJS("return document.querySelector('h1').textContent", "Large")
        }
    }
}
