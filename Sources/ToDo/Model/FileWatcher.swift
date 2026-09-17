import Foundation

/// Watches a file and its parent directory. Editors usually save atomically (new inode),
/// so the directory watcher catches replacements and the file source is re-armed afterwards.
final class FileWatcher {
    private let url: URL
    private let onChange: () -> Void
    private var dirSource: DispatchSourceFileSystemObject?
    private var fileSource: DispatchSourceFileSystemObject?
    private var debounce: DispatchWorkItem?

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
        dirSource = makeSource(path: url.deletingLastPathComponent().path)
        armFile()
    }

    deinit {
        dirSource?.cancel()
        fileSource?.cancel()
    }

    private func armFile() {
        fileSource?.cancel()
        fileSource = makeSource(path: url.path)
    }

    private func makeSource(path: String) -> DispatchSourceFileSystemObject? {
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .rename, .delete, .attrib],
            queue: .main
        )
        source.setEventHandler { [weak self] in self?.fire() }
        source.setCancelHandler { close(fd) }
        source.resume()
        return source
    }

    private func fire() {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.armFile()
            self.onChange()
        }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }
}
