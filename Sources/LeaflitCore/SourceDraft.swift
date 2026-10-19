import Foundation

public struct SourceDraft: Sendable {
    public private(set) var originalData: Data
    public private(set) var text: String
    public private(set) var hasExternalChanges = false
    private var hasBOM: Bool

    public init(data: Data) throws {
        hasBOM = data.starts(with: [0xef, 0xbb, 0xbf])
        let content = hasBOM ? Data(data.dropFirst(3)) : data
        guard let text = String(data: content, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        self.text = text; originalData = data
    }
    public var encodedData: Data {
        (hasBOM ? Data([0xef, 0xbb, 0xbf]) : Data()) + Data(text.utf8)
    }
    // Swift String equality is canonically equivalent; document identity is byte exact.
    public var isDirty: Bool { encodedData != originalData }
    public mutating func replaceText(_ text: String) { self.text = text }
    public mutating func observeDisk(_ data: Data, sameIdentity: Bool = true) throws {
        if isDirty {
            if data != originalData || !sameIdentity { hasExternalChanges = true }
        } else { self = try SourceDraft(data: data) }
    }
    public mutating func markUnavailable() { hasExternalChanges = true }
    public mutating func didSave() { originalData = encodedData; hasExternalChanges = false }
    public mutating func discardChanges() {
        // originalData is validated UTF-8 from initialization or a completed explicit save.
        text = String(decoding: hasBOM ? originalData.dropFirst(3) : originalData[...], as: UTF8.self)
    }
}
