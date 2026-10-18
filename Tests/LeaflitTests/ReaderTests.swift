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
        let preferences = UserDefaults(suiteName: dir.lastPathComponent)!
        preferences.removePersistentDomain(forName: dir.lastPathComponent)
        reader = ReaderController(preferences: preferences); reader.showWindow(nil)
        reader.window?.level = .floating
        reader.window?.orderFrontRegardless()
    }
    override func tearDown() async throws {
        reader.close(); reader = nil
        UserDefaults(suiteName: dir.lastPathComponent)?.removePersistentDomain(forName: dir.lastPathComponent)
        try? FileManager.default.removeItem(at: dir)
    }
    func write(_ text: String, name: String = "한글 😀 file.md") throws -> URL {
        let url = dir.appendingPathComponent(name); try text.write(to: url, atomically: true, encoding: .utf8); return url
    }
    func wait(_ condition: @escaping () -> Bool, seconds: Double = 20, file: StaticString = #filePath, line: UInt = #line) async throws {
        let end = Date().addingTimeInterval(seconds)
        while !condition() && Date() < end { try await Task.sleep(nanoseconds: 30_000_000) }
        if !condition() { print("LEAFLIT_TIMEOUT doc=\(String(describing: reader.documentURL)) rendered=\(String(describing: reader.renderedURL)) revision=\(reader.revision.current) body=\(reader.displayedRevision) complete=\(reader.completedRevision) visible=\(reader.window?.isVisible == true) occluded=\(reader.window?.occlusionState.contains(.visible) != true)") }
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
        try await assertJS("return document.querySelector('.diagram svg').textContent.includes('Open')", true)
        try await assertJS("return document.querySelector('.diagram').getAttribute('aria-label').includes('Read')", true)
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
        let firstRevision = reader.completedRevision
        reader.navigate("second%20page.md#target")
        try await wait { self.reader.documentURL?.lastPathComponent == "second page.md" && self.reader.completedRevision > firstRevision }
        let title = try await js("return document.querySelector('h1').textContent") as? String
        XCTAssertEqual(title, "Second")
        let secondRevision = reader.completedRevision
        reader.window?.orderFrontRegardless()
        let delegate = try XCTUnwrap(NSApp.delegate as? AppDelegate)
        delegate.back(nil)
        try await wait { self.reader.documentURL == DocumentPath.canonical(first) && self.reader.completedRevision > secondRevision }
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
            print("LEAFLIT_LARGE bytes=\(before.count) bodyMs=\(reader.measurements["body"] ?? -1) completeMs=\(reader.measurements["complete"] ?? -1)")
            try await assertJS("return document.querySelector('h1').textContent", "Large")
        }
    }
    func testPerformanceTransitions() async throws {
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/Benchmark100KiB.md")
        let text = try String(contentsOf: fixture, encoding: .utf8)
        XCTAssertEqual(text.utf8.count, 102400)
        let a = try write(text, name: "a.md"), b = try write(text, name: "b.md")
        reader.open(a); try await wait { self.reader.completedRevision > 0 }
        var samples: [[String: Double]] = []
        for n in 0..<20 {
            let old = reader.completedRevision
            reader.open(n % 2 == 0 ? b : a)
            try await wait { self.reader.completedRevision > old }
            samples.append(reader.measurements)
        }
        let data = try JSONSerialization.data(withJSONObject: samples, options: [.sortedKeys])
        print("LEAFLIT_TRANSITIONS " + String(data: data, encoding: .utf8)!)
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "100KiB-transitions-20"; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testAppearanceZoomAndOfflinePolicy() async throws {
        try await loaded("# Appearance\n\nA paragraph with 한글 and emoji 🌿.\n\n$x^2$\n\n```mermaid\nflowchart LR\n A[Open] --> B[Read]\n```\n\n```text\n" + String(repeating: "long ", count: 100) + "\n```\n")
        reader.window?.setContentSize(NSSize(width: 640, height: 540))
        reader.webView.pageZoom = 2
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", NSAppearance.Name.darkAqua)] {
            reader.window?.appearance = NSAppearance(named: appearance)
            try await Task.sleep(nanoseconds: 350_000_000)
            try await assertJS("return matchMedia('(prefers-color-scheme: dark)').matches", name == "dark")
            try await assertJS("return document.documentElement.scrollWidth <= innerWidth", true)
            try await assertJS("return [...document.querySelectorAll('pre')].some(p => p.scrollWidth > p.clientWidth)", true)
            let snapshot = try await reader.webView.takeSnapshot(configuration: nil)
            let attachment = XCTAttachment(image: snapshot); attachment.name = "640pt-200percent-" + name; attachment.lifetime = .keepAlways; add(attachment)
        }
        try await assertJS("try { await fetch('https://example.com/blocked'); return false; } catch { return true; }", true)
    }

    func testReloadLatency100KiB() async throws {
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/Benchmark100KiB.md")
        let text = try String(contentsOf: fixture, encoding: .utf8)
        let url = try write(text)
        reader.open(url); try await wait { self.reader.completedRevision > 0 }
        let old = reader.displayedRevision
        let start = Date()
        try (text + "\nChanged.").write(to: url, atomically: true, encoding: .utf8)
        try await wait { self.reader.displayedRevision > old }
        print("LEAFLIT_RELOAD bodyMs=\(Date().timeIntervalSince(start) * 1000)")
        try await wait { self.reader.completedRevision == self.reader.revision.current }
    }

    func testUnchangedSaveAndSiblingChangeKeepLinksActive() async throws {
        let text = "# First\n\n[Next](next.md)"
        let first = try write(text, name: "first.md")
        _ = try write("# Next", name: "next.md")
        reader.open(first); try await wait { self.reader.completedRevision > 0 }
        let old = reader.completedRevision
        try text.write(to: first, atomically: true, encoding: .utf8)
        try "sibling".write(to: dir.appendingPathComponent("unrelated.txt"), atomically: true, encoding: .utf8)
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(reader.revision.current, old)
        _ = try await js("document.querySelector('a').click(); return true")
        try await wait { self.reader.documentURL?.lastPathComponent == "next.md" && self.reader.completedRevision > old }
        try await assertJS("return document.querySelector('h1').textContent", "Next")
    }

    func testUserScrollDuringDiagramRenderingIsKept() async throws {
        let diagrams = String(repeating: "```mermaid\nflowchart LR\n A[Open] --> B[Read]\n```\n\n", count: 10)
        let text = "# Scroll\n\n" + diagrams + String(repeating: "A paragraph to read while rendering.\n\n", count: 100)
        reader.open(try write(text))
        try await wait { self.reader.displayedRevision > 0 }
        _ = try await js("scrollTo(0, 1200); return true")
        try await wait { self.reader.completedRevision == self.reader.revision.current }
        let y = try await js("return scrollY") as? Double ?? 0
        XCTAssertGreaterThan(y, 500)
    }

    func testMenuValidationAndDispatch() async throws {
        let first = try write("# First\n\n[Next](next.md)", name: "first.md")
        _ = try write("# Next", name: "next.md")
        reader.open(first); try await wait { self.reader.completedRevision > 0 }
        let menu = try XCTUnwrap(NSApp.mainMenu?.item(withTitle: "View")?.submenu)
        menu.update()
        let zoom = try XCTUnwrap(menu.item(withTitle: "Zoom In"))
        let target = try XCTUnwrap(zoom.target as? NSObject)
        print("LEAFLIT_MENU action=\(String(describing: zoom.action)) target=\(type(of: target)) responds=\(target.responds(to: zoom.action!)) enabled=\(zoom.isEnabled)")
        XCTAssertTrue(target is AppDelegate)
        XCTAssertTrue(target.responds(to: zoom.action!))
        XCTAssertTrue(zoom.isEnabled)
        menu.performActionForItem(at: menu.index(of: zoom))
        XCTAssertEqual(reader.webView.pageZoom, 1.1, accuracy: 0.001)
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        let field = try XCTUnwrap(descendants(reader.window!.contentView!).compactMap { $0 as? NSSearchField }.first)
        XCTAssertTrue(field.isHiddenOrHasHiddenAncestor)
        let key = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0, windowNumber: reader.window!.windowNumber, context: nil, characters: "f", charactersIgnoringModifiers: "f", isARepeat: false, keyCode: 3))
        XCTAssertTrue(NSApp.mainMenu!.performKeyEquivalent(with: key))
        XCTAssertFalse(field.isHiddenOrHasHiddenAncestor)
        let old = reader.completedRevision
        reader.navigate("next.md")
        try await wait { self.reader.documentURL?.lastPathComponent == "next.md" && self.reader.completedRevision > old }
        menu.update()
        let back = try XCTUnwrap(menu.item(withTitle: "Back"))
        XCTAssertTrue(back.isEnabled)
        let second = reader.completedRevision
        menu.performActionForItem(at: menu.index(of: back))
        try await wait { self.reader.documentURL == DocumentPath.canonical(first) && self.reader.completedRevision > second }
        try await assertJS("return document.querySelector('h1').textContent", "First")
    }

}
