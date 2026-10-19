import XCTest
@testable import LeaflitCore

final class SourceDraftTests: XCTestCase {
    func testUnchangedBOMCRLFAndUnicodeRoundTripExactly() throws {
        let data = Data([0xef, 0xbb, 0xbf]) + Data("# 한글 😀\r\n\r\n  text\t\r\n".utf8)
        let draft = try SourceDraft(data: data)
        XCTAssertEqual(draft.text, "# 한글 😀\r\n\r\n  text\t\r\n")
        XCTAssertEqual(draft.encodedData, data)
        XCTAssertEqual(draft.originalData, data)
        XCTAssertFalse(draft.isDirty)
    }

    func testEditsAreAnInMemoryDraftWithoutFormatting() throws {
        let original = Data("# Plan\n".utf8)
        var draft = try SourceDraft(data: original)
        let edited = "# Plan\n\n```mermaid\nwrong syntax\n```\n\t'quoted'  \n"
        draft.replaceText(edited)
        XCTAssertEqual(draft.originalData, original)
        XCTAssertEqual(draft.encodedData, Data(edited.utf8))
        XCTAssertTrue(draft.isDirty)
    }

    func testDirtyDraftSurvivesExternalChangesAndDeletion() throws {
        let original = Data("# Original\n".utf8)
        var draft = try SourceDraft(data: original)
        draft.replaceText("# Mine\n")
        try draft.observeDisk(Data("# From the terminal\n".utf8))
        XCTAssertEqual(draft.text, "# Mine\n")
        XCTAssertEqual(draft.originalData, original)
        XCTAssertTrue(draft.hasExternalChanges)
        draft.markUnavailable()
        XCTAssertEqual(draft.text, "# Mine\n")
        XCTAssertTrue(draft.isDirty)
    }

    func testCleanDraftAcceptsAnExternalRefresh() throws {
        var draft = try SourceDraft(data: Data("# Original\n".utf8))
        let external = Data("# External 😀\r\n".utf8)
        try draft.observeDisk(external)
        XCTAssertEqual(draft.text, "# External 😀\r\n")
        XCTAssertEqual(draft.originalData, external)
        XCTAssertEqual(draft.encodedData, external)
        XCTAssertFalse(draft.isDirty)
        XCTAssertFalse(draft.hasExternalChanges)
    }

    func testAtomicReplacementIsAConflictEvenWithTheSameBytes() throws {
        let original = Data("# Original\n".utf8)
        var draft = try SourceDraft(data: original)
        draft.replaceText("# Mine\n")
        try draft.observeDisk(original, sameIdentity: false)
        XCTAssertTrue(draft.hasExternalChanges)
        XCTAssertEqual(draft.text, "# Mine\n")
    }

    func testInvalidUTF8DoesNotDestroyADirtyDraft() throws {
        let invalid = Data([0xff, 0xfe, 0xfd])
        XCTAssertThrowsError(try SourceDraft(data: invalid))
        var draft = try SourceDraft(data: Data("# Original\n".utf8))
        draft.replaceText("# Mine\n")
        try draft.observeDisk(invalid)
        XCTAssertTrue(draft.hasExternalChanges)
        XCTAssertEqual(draft.text, "# Mine\n")
    }

    func testSaveAndUndoUseTheLastSavedTextAsTheBaseline() throws {
        var draft = try SourceDraft(data: Data("first\n".utf8))
        draft.replaceText("second\n")
        draft.didSave()
        XCTAssertFalse(draft.isDirty)
        XCTAssertEqual(draft.originalData, Data("second\n".utf8))
        draft.replaceText("first\n")
        XCTAssertTrue(draft.isDirty)
        draft.discardChanges()
        XCTAssertEqual(draft.text, "second\n")
        XCTAssertFalse(draft.isDirty)
    }
}
