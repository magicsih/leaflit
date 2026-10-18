import Foundation

final class FileWatcher {
    private var sources: [DispatchSourceFileSystemObject] = []
    private var pending: DispatchWorkItem?
    private let url: URL
    private let change: () -> Void
    init(url: URL, change: @escaping () -> Void) {
        self.url = url; self.change = change; arm()
    }
    private func arm() {
        sources.forEach { $0.cancel() }; sources.removeAll()
        for path in [url.path, url.deletingLastPathComponent().path] {
            let fd = open(path, O_EVTONLY)
            guard fd >= 0 else { continue }
            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .delete, .rename, .attrib, .extend], queue: .main)
            source.setEventHandler { [weak self] in self?.schedule() }
            source.setCancelHandler { close(fd) }
            source.resume(); sources.append(source)
        }
    }
    private func schedule() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.arm(); self.change()
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10, execute: work)
    }
    deinit { pending?.cancel(); sources.forEach { $0.cancel() } }
}
