import Foundation

public enum DocumentLink: Equatable {
    case document(URL, String?)
    case anchor(String)
    case web(URL)
    case blocked
}

public enum DocumentPath {
    public static let extensions: Set<String> = ["md", "markdown", "mdown"]
    public static func canonical(_ url: URL) -> URL {
        URL(fileURLWithPath: url.standardizedFileURL.resolvingSymlinksInPath().path)
    }
    public static func isMarkdown(_ url: URL) -> Bool { url.isFileURL && extensions.contains(url.pathExtension.lowercased()) }
    public static func link(_ href: String, from document: URL) -> DocumentLink {
        let raw = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.hasPrefix("//"), !raw.contains("\0") else { return .blocked }
        if raw.hasPrefix("#") { return .anchor(String(raw.dropFirst()).removingPercentEncoding ?? String(raw.dropFirst())) }
        guard let parts = URLComponents(string: raw) else { return .blocked }
        if let scheme = parts.scheme {
            guard ["http", "https"].contains(scheme.lowercased()), let url = parts.url, url.host != nil else { return .blocked }
            return .web(url)
        }
        guard parts.host == nil, parts.query == nil, !parts.path.isEmpty, !parts.path.hasPrefix("/") else { return .blocked }
        let target = canonical(document.deletingLastPathComponent().appendingPathComponent(parts.path))
        guard isMarkdown(target) else { return .blocked }
        return .document(target, parts.fragment)
    }
}

public struct DocumentSnapshot: Sendable {
    public let url: URL
    public let text: String
    public let images: [String: URL]
    public static func read(_ url: URL) throws -> DocumentSnapshot {
        let url = DocumentPath.canonical(url)
        guard DocumentPath.isMarkdown(url) else { throw CocoaError(.fileReadUnsupportedScheme) }
        let data = try Data(contentsOf: url)
        return try decode(data, at: url)
    }
    public static func decode(_ data: Data, at url: URL) throws -> DocumentSnapshot {
        guard DocumentPath.isMarkdown(url) else { throw CocoaError(.fileReadUnsupportedScheme) }
        guard let text = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        return DocumentSnapshot(url: url, text: text, images: LocalImages.references(in: text, document: url))
    }
}

public struct RevisionGate {
    public private(set) var current = 0
    public init() {}
    @discardableResult public mutating func next() -> Int { current += 1; return current }
    public func accepts(_ revision: Int) -> Bool { current == revision }
}

public enum LocalImages {
    // Conservative allow-list. Web content cannot request arbitrary files from the disk.
    public static func references(in text: String, document: URL) -> [String: URL] {
        let destination = #"(?:\\.|[^\s()\\]|\((?:\\.|[^()\\])*\))+"#
        let patterns = [#"!\[(?:\\.|[^\]\n])*\]\(\s*(?:<([^>\n]+)>|("# + destination + "))",
                        #"(?m)^ {0,3}\[[^\]\n]+\]:\s*(?:<([^>\n]+)>|([^\s]+))"#]
        var result: [String: URL] = [:]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                for group in 1..<match.numberOfRanges {
                    guard let range = Range(match.range(at: group), in: text) else { continue }
                    let raw = String(text[range]).replacingOccurrences(of: ##"\\([!"#$%&'()*+,\-./:;<=>?@\[\]\\^_`{|}~ ])"##, with: "$1", options: .regularExpression)
                    guard let parts = URLComponents(string: raw), parts.scheme == nil, parts.host == nil,
                          parts.query == nil, parts.fragment == nil, !parts.path.hasPrefix("/"), !parts.path.isEmpty else { continue }
                    let path = parts.path
                    guard ["png", "jpg", "jpeg"].contains(URL(fileURLWithPath: path).pathExtension.lowercased()) else { continue }
                    result[path] = DocumentPath.canonical(document.deletingLastPathComponent().appendingPathComponent(path))
                }
            }
        }
        return result
    }
}
