import Foundation
import Darwin
import LeaflitCore

enum SourceFileError: LocalizedError, Equatable {
    case changed, unavailable, readOnly, coordination
    var errorDescription: String? {
        switch self {
        case .changed: return "The file changed on disk. Your edits are still here. Reload from disk or save a new copy."
        case .unavailable: return "The original file is unavailable or is no longer a regular file. Your edits are still here."
        case .readOnly: return "The original file is read-only. Save a new copy or change its permissions outside Leaflit."
        case .coordination: return "The file could not be coordinated for saving. Your edits are still here."
        }
    }
}

struct SourceFileSnapshot: Sendable {
    struct Identity: Equatable, Sendable { let device: dev_t; let inode: ino_t }
    let url: URL
    let data: Data
    let identity: Identity

    static func read(_ url: URL, within folder: FolderTree?) throws -> Self {
        guard folder?.canOpen(url) != false else { throw SourceFileError.unavailable }
        let descriptor = Darwin.open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { throw SourceFileError.unavailable }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var info = stat(), path = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        guard fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
              fcntl(descriptor, F_GETPATH, &path) == 0 else { throw SourceFileError.unavailable }
        let actual = DocumentPath.canonical(URL(fileURLWithPath: String(cString: path)))
        guard actual == DocumentPath.canonical(url), folder?.canOpen(url) != false else { throw SourceFileError.unavailable }
        let data = try handle.readToEnd() ?? Data()
        let identity = Identity(device: info.st_dev, inode: info.st_ino)
        guard try identityAt(url) == identity else { throw SourceFileError.changed }
        return Self(url: actual, data: data, identity: identity)
    }
    static func identityAt(_ url: URL) throws -> Identity {
        var info = stat()
        guard lstat(url.path, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { throw SourceFileError.unavailable }
        return Identity(device: info.st_dev, inode: info.st_ino)
    }
}

enum SourceFileWriter {
    // The final validation hook permits deterministic tests of a writer changing the file during staging.
    static func save(_ data: Data, replacing original: SourceFileSnapshot, within folder: FolderTree?, beforeReplace: (() throws -> Void)? = nil, beforeStageWrite: ((URL) throws -> Void)? = nil) throws -> SourceFileSnapshot {
        var coordinationError: NSError?, outcome: Result<SourceFileSnapshot, Error>?
        NSFileCoordinator().coordinate(writingItemAt: original.url, options: .forReplacing, error: &coordinationError) { url in
            outcome = Result {
                guard url.standardizedFileURL == original.url.standardizedFileURL else { throw SourceFileError.changed }
                func validate() throws -> SourceFileSnapshot {
                    let current = try SourceFileSnapshot.read(url, within: folder)
                    guard current.identity == original.identity, current.data == original.data else { throw SourceFileError.changed }
                    return current
                }
                func validateWritable() throws {
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    guard let mode = attributes[.posixPermissions] as? NSNumber, mode.intValue & 0o222 != 0,
                          FileManager.default.isWritableFile(atPath: url.path) else { throw SourceFileError.readOnly }
                }
                let current = try validate()
                if data == original.data { return current }
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                try validateWritable()
                let temporary = url.deletingLastPathComponent().appendingPathComponent(".leaflit-\(UUID().uuidString).tmp")
                let temporaryIdentity = try create(data, at: temporary, beforeWrite: beforeStageWrite)
                defer { remove(temporary, ifMatching: temporaryIdentity) }
                try FileManager.default.setAttributes([.posixPermissions: attributes[.posixPermissions]!], ofItemAtPath: temporary.path)
                try beforeReplace?()
                _ = try validate()
                try validateWritable()
                _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary)
                let saved = try SourceFileSnapshot.read(url, within: folder)
                guard saved.data == data else { throw SourceFileError.changed }
                return saved
            }
        }
        if let coordinationError { throw coordinationError }
        guard let outcome else { throw SourceFileError.coordination }
        return try outcome.get()
    }
    static func copy(_ data: Data, to url: URL, excluding original: URL? = nil) throws {
        if let original, sameLocation(url, original) { throw SourceFileError.changed }
        _ = try create(data, at: url)
    }
    private static func sameLocation(_ first: URL, _ second: URL) -> Bool {
        var a = stat(), b = stat()
        let parent = first.deletingLastPathComponent(), other = second.deletingLastPathComponent()
        guard fstatat(AT_FDCWD, parent.path, &a, 0) == 0, fstatat(AT_FDCWD, other.path, &b, 0) == 0,
              a.st_dev == b.st_dev, a.st_ino == b.st_ino else { return false }
        let sensitive = (try? parent.resourceValues(forKeys: [.volumeSupportsCaseSensitiveNamesKey]))?.volumeSupportsCaseSensitiveNames == true
        return sensitive ? first.lastPathComponent == second.lastPathComponent : first.lastPathComponent.caseInsensitiveCompare(second.lastPathComponent) == .orderedSame
    }
    private static func remove(_ url: URL, ifMatching identity: SourceFileSnapshot.Identity) {
        if (try? SourceFileSnapshot.identityAt(url)) == identity { try? FileManager.default.removeItem(at: url) }
    }
    private static func create(_ data: Data, at url: URL, beforeWrite: ((URL) throws -> Void)? = nil) throws -> SourceFileSnapshot.Identity {
        let descriptor = Darwin.open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var info = stat(); guard fstat(descriptor, &info) == 0 else { throw SourceFileError.unavailable }
        let identity = SourceFileSnapshot.Identity(device: info.st_dev, inode: info.st_ino)
        do { try beforeWrite?(url); try handle.write(contentsOf: data); try handle.synchronize() }
        catch {
            remove(url, ifMatching: identity)
            throw error
        }
        return identity
    }
}
