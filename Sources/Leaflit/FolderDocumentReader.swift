import Foundation
import Darwin
import LeaflitCore

enum FolderDocumentReader {
    static func read(_ url: URL, within folder: FolderTree?) throws -> DocumentSnapshot {
        guard let folder else { return try DocumentSnapshot.read(url) }
        guard folder.canOpen(url) else { throw CocoaError(.fileReadNoPermission) }
        let expected = DocumentPath.canonical(url)
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var path = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        guard fcntl(handle.fileDescriptor, F_GETPATH, &path) == 0 else { throw CocoaError(.fileReadNoPermission) }
        let actual = DocumentPath.canonical(URL(fileURLWithPath: String(cString: path)))
        guard actual.path == expected.path, folder.contains(actual), folder.canOpen(url) else { throw CocoaError(.fileReadNoPermission) }
        let data = try handle.readToEnd() ?? Data()
        return try DocumentSnapshot.decode(data, at: actual)
    }
}
