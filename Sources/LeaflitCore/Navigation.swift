import Foundation

public struct FolderEntry: Hashable, Sendable {
    public let url: URL
    public let name: String
    public let isDirectory: Bool
}

public struct FolderTree: Sendable {
    public let root: URL
    public init(root: URL) { self.root = DocumentPath.canonical(root) }
    public func contains(_ url: URL) -> Bool {
        let path = DocumentPath.canonical(url).path
        return path == root.path || path.hasPrefix(root.path == "/" ? "/" : root.path + "/")
    }
    public func canOpen(_ url: URL) -> Bool {
        guard contains(url), DocumentPath.isMarkdown(url),
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
              values.isSymbolicLink != true, values.isRegularFile == true else { return false }
        return true
    }
    public func entries(in directory: URL) throws -> [FolderEntry] {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .isHiddenKey]
        guard contains(directory), try directory.resourceValues(forKeys: keys).isSymbolicLink != true else {
            throw CocoaError(.fileReadNoPermission)
        }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]).compactMap { url in
            guard let values = try? url.resourceValues(forKeys: keys), values.isHidden != true,
                  values.isSymbolicLink != true, contains(url),
                  values.isDirectory == true || (values.isRegularFile == true && DocumentPath.isMarkdown(url)) else { return nil }
            return FolderEntry(url: DocumentPath.canonical(url), name: url.lastPathComponent, isDirectory: values.isDirectory == true)
        }.sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
}

public struct DocumentHeading: Equatable, Sendable {
    public let id: String
    public let title: String
    public let level: Int
    public init(id: String, title: String, level: Int) { self.id = id; self.title = title; self.level = level }
    public init?(message: [String: Any]) {
        guard let id = message["id"] as? String, !id.isEmpty,
              let title = message["title"] as? String, let level = message["level"] as? Int,
              (1...6).contains(level) else { return nil }
        self.init(id: id, title: title, level: level)
    }
}

public final class HeadingNode: NSObject {
    public let heading: DocumentHeading
    public fileprivate(set) var children: [HeadingNode] = []
    fileprivate weak var parent: HeadingNode?
    fileprivate init(_ heading: DocumentHeading) { self.heading = heading }
}

public struct HeadingOutline {
    public private(set) var roots: [HeadingNode] = []
    private var nodes: [String: HeadingNode] = [:]
    public init(_ headings: [DocumentHeading]) {
        var stack: [HeadingNode] = []
        for heading in headings where nodes[heading.id] == nil {
            let node = HeadingNode(heading)
            while let previous = stack.last, previous.heading.level >= heading.level { stack.removeLast() }
            if let parent = stack.last { node.parent = parent; parent.children.append(node) }
            else { roots.append(node) }
            stack.append(node); nodes[heading.id] = node
        }
    }
    public func node(id: String) -> HeadingNode? { nodes[id] }
    public func ancestors(of id: String) -> [HeadingNode] {
        var result: [HeadingNode] = [], parent = nodes[id]?.parent
        while let node = parent { result.insert(node, at: 0); parent = node.parent }
        return result
    }
}
