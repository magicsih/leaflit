import XCTest
import Darwin
import LeaflitCore
@testable import Leaflit

final class SourceFileTests: XCTestCase {
    var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("Leaflit Source \(UUID().uuidString)").resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }
    func fixture(_ data: Data = Data("# Original\n".utf8)) throws -> SourceFileSnapshot {
        let url = directory.appendingPathComponent("한글 😀 source file.md")
        try data.write(to: url)
        return try SourceFileSnapshot.read(url, within: nil)
    }
    func testExplicitSavePreservesEncodingPermissionsAndMetadata() throws {
        let bytes = Data([0xef, 0xbb, 0xbf]) + Data("# 한글 😀\r\n".utf8)
        let original = try fixture(bytes)
        try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: original.url.path)
        let attribute = Data("retained".utf8)
        XCTAssertEqual(attribute.withUnsafeBytes { setxattr(original.url.path, "user.leaflit-test", $0.baseAddress, $0.count, 0, 0) }, 0)
        var draft = try SourceDraft(data: original.data); draft.replaceText(draft.text + "Edited\r\n")
        let saved = try SourceFileWriter.save(draft.encodedData, replacing: original, within: nil)
        XCTAssertEqual(saved.data, draft.encodedData)
        XCTAssertEqual(try Data(contentsOf: original.url), draft.encodedData)
        XCTAssertEqual((try FileManager.default.attributesOfItem(atPath: original.url.path)[.posixPermissions] as? NSNumber)?.intValue, 0o640)
        var value = [UInt8](repeating: 0, count: 32)
        let count = getxattr(original.url.path, "user.leaflit-test", &value, value.count, 0, 0)
        XCTAssertEqual(count, attribute.count); XCTAssertEqual(Data(value.prefix(max(0, count))), attribute)
    }
    func testNoOpSaveDoesNotReplaceOriginal() throws {
        let original = try fixture()
        let attributes = try FileManager.default.attributesOfItem(atPath: original.url.path)
        let saved = try SourceFileWriter.save(original.data, replacing: original, within: nil)
        XCTAssertEqual(saved.identity, original.identity)
        XCTAssertEqual(saved.data, original.data)
        XCTAssertEqual(try SourceFileSnapshot.read(original.url, within: nil).identity, original.identity)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: original.url.path)[.modificationDate] as? Date, attributes[.modificationDate] as? Date)
        XCTAssertEqual(try Data(contentsOf: original.url), original.data)
        try Data("# External".utf8).write(to: original.url)
        XCTAssertThrowsError(try SourceFileWriter.save(original.data, replacing: original, within: nil))
    }
    func testChangesDuringStagingAreRejectedAndTemporaryFileIsRemoved() throws {
        let original = try fixture(), changed = Data("# New external bytes".utf8)
        XCTAssertThrowsError(try SourceFileWriter.save(Data("# Draft".utf8), replacing: original, within: nil, beforeReplace: {
            try changed.write(to: original.url, options: .atomic)
        }))
        XCTAssertEqual(try Data(contentsOf: original.url), changed)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [original.url.lastPathComponent])
    }
    func testCopyRefusesSymlinksDirectoriesAndConcurrentCreation() throws {
        let original = try fixture(), link = directory.appendingPathComponent("link.md")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: directory.appendingPathComponent("missing.md"))
        XCTAssertThrowsError(try SourceFileWriter.copy(original.data, to: link))
        XCTAssertThrowsError(try SourceFileWriter.copy(original.data, to: directory))
        let copy = directory.appendingPathComponent("concurrent.md")
        let queue = DispatchQueue(label: "LeaflitCopyTest", attributes: .concurrent)
        let group = DispatchGroup(), lock = NSLock()
        var winners = [Data]()
        for text in ["# One", "# Two"] {
            group.enter(); queue.async {
                defer { group.leave() }
                let data = Data(text.utf8)
                if (try? SourceFileWriter.copy(data, to: copy)) != nil { lock.lock(); winners.append(data); lock.unlock() }
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        XCTAssertEqual(winners.count, 1); XCTAssertEqual(try Data(contentsOf: copy), try XCTUnwrap(winners.first))
        XCTAssertEqual(try Data(contentsOf: original.url), original.data)
    }
    func testChangedBytesOrAtomicReplacementRejectSave() throws {
        let original = try fixture()
        try Data("# External\n".utf8).write(to: original.url)
        XCTAssertThrowsError(try SourceFileWriter.save(Data("# Draft".utf8), replacing: original, within: nil))
        XCTAssertEqual(try Data(contentsOf: original.url), Data("# External\n".utf8))
        try original.data.write(to: original.url, options: .atomic)
        XCTAssertNotEqual(try SourceFileSnapshot.read(original.url, within: nil).identity, original.identity)
        XCTAssertThrowsError(try SourceFileWriter.save(Data("# Draft".utf8), replacing: original, within: nil))
        XCTAssertEqual(try Data(contentsOf: original.url), original.data)
    }
    func testDeletedReadOnlyAndSymlinkOriginalsAreNeverOverwritten() throws {
        let original = try fixture(), draft = Data("# Draft".utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: original.url.path)
        XCTAssertThrowsError(try SourceFileWriter.save(draft, replacing: original, within: nil))
        try FileManager.default.removeItem(at: original.url)
        XCTAssertThrowsError(try SourceFileWriter.save(draft, replacing: original, within: nil))
        XCTAssertFalse(FileManager.default.fileExists(atPath: original.url.path))
        let target = directory.appendingPathComponent("target.md"); try original.data.write(to: target)
        try FileManager.default.createSymbolicLink(at: original.url, withDestinationURL: target)
        XCTAssertThrowsError(try SourceFileSnapshot.read(original.url, within: nil))
        XCTAssertThrowsError(try SourceFileWriter.save(draft, replacing: original, within: nil))
        XCTAssertEqual(try Data(contentsOf: target), original.data)
    }
    func testCopyCreatesOnlyNewFileAndFolderScopeIsRevalidated() throws {
        let original = try fixture(), data = Data("# Copy".utf8)
        let copy = directory.appendingPathComponent("new copy.md")
        try SourceFileWriter.copy(data, to: copy)
        XCTAssertEqual(try Data(contentsOf: copy), data)
        XCTAssertThrowsError(try SourceFileWriter.copy(original.data, to: copy))
        XCTAssertEqual(try Data(contentsOf: copy), data)
        let other = directory.appendingPathComponent("Other")
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        XCTAssertThrowsError(try SourceFileWriter.save(data, replacing: original, within: FolderTree(root: other)))
        XCTAssertEqual(try Data(contentsOf: original.url), original.data)
    }
}
