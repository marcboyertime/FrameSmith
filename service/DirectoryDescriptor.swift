import CryptoKit
import Darwin
import Foundation

public enum DirectoryDescriptorError: Error, LocalizedError, Equatable, Sendable {
    case unsafeComponent(String)
    case notADirectory(String)
    case identityChanged(String)
    case openFailed(String, Int32)
    case createFailed(String, Int32)
    case ioFailed(String, Int32)
    case entryExists(String)
    case notRegularFile(String)

    public var errorDescription: String? {
        switch self {
        case .unsafeComponent(let name): return "Unsafe path component: \(name)"
        case .notADirectory(let name): return "Not a directory: \(name)"
        case .identityChanged(let name): return "Directory identity changed while it was being opened: \(name)"
        case .openFailed(let name, let code): return "Unable to open \(name): \(String(cString: strerror(code)))"
        case .createFailed(let name, let code): return "Unable to create \(name): \(String(cString: strerror(code)))"
        case .ioFailed(let name, let code): return "I/O failure on \(name): \(String(cString: strerror(code)))"
        case .entryExists(let name): return "Entry already exists: \(name)"
        case .notRegularFile(let name): return "Not a regular file: \(name)"
        }
    }
}

/// A directory anchored to an open file descriptor.
///
/// Every operation is an `*at` syscall relative to that descriptor, so the
/// only path resolution that ever happens by name is a single leaf component
/// opened with `O_NOFOLLOW`. Once a handle exists, renaming an ancestor
/// directory or swapping one for a symlink cannot redirect a later create,
/// write, or publish outside the directory that was vetted — the classic
/// check-then-write race that a path-based `FileManager` sequence leaves open.
public final class DirectoryHandle {
    public let descriptor: Int32
    private let label: String
    private var isClosed = false

    private init(descriptor: Int32, label: String) {
        self.descriptor = descriptor
        self.label = label
    }

    deinit { if !isClosed { close(descriptor) } }

    public func closeHandle() {
        guard !isClosed else { return }
        isClosed = true
        close(descriptor)
    }

    /// Opens a directory that the caller has already vetted by path, and proves
    /// the opened inode is the same object that was vetted. `lstat` before the
    /// open and `fstat` after it must agree on device and inode; a swap in that
    /// window is rejected instead of being written into.
    public static func open(vettedDirectory url: URL) throws -> DirectoryHandle {
        let path = url.path
        var before = stat()
        guard lstat(path, &before) == 0 else { throw DirectoryDescriptorError.openFailed(path, errno) }
        guard (before.st_mode & S_IFMT) == S_IFDIR else { throw DirectoryDescriptorError.notADirectory(path) }
        let descriptor = Darwin.open(path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { throw DirectoryDescriptorError.openFailed(path, errno) }
        var after = stat()
        guard fstat(descriptor, &after) == 0 else {
            let code = errno
            close(descriptor)
            throw DirectoryDescriptorError.openFailed(path, code)
        }
        guard (after.st_mode & S_IFMT) == S_IFDIR else {
            close(descriptor)
            throw DirectoryDescriptorError.notADirectory(path)
        }
        guard after.st_dev == before.st_dev, after.st_ino == before.st_ino else {
            close(descriptor)
            throw DirectoryDescriptorError.identityChanged(path)
        }
        return DirectoryHandle(descriptor: descriptor, label: path)
    }

    /// Creates a child directory and returns a handle anchored to it.
    @discardableResult
    public func createDirectory(_ name: String, permissions: mode_t = 0o700) throws -> DirectoryHandle {
        let component = try Self.safeComponent(name)
        guard mkdirat(descriptor, component, permissions) == 0 else {
            let code = errno
            throw code == EEXIST ? DirectoryDescriptorError.entryExists(child(component)) : DirectoryDescriptorError.createFailed(child(component), code)
        }
        return try openChildDirectory(component)
    }

    public func openChildDirectory(_ name: String) throws -> DirectoryHandle {
        let component = try Self.safeComponent(name)
        let childDescriptor = openat(descriptor, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard childDescriptor >= 0 else { throw DirectoryDescriptorError.openFailed(child(component), errno) }
        return DirectoryHandle(descriptor: childDescriptor, label: child(component))
    }

    /// Creates a new regular file and writes `data` to it. `O_EXCL` plus
    /// `O_NOFOLLOW` means an entry planted at that name — regular file or
    /// symlink — fails the create instead of being followed or truncated.
    public func writeNewFile(_ name: String, data: Data, permissions: mode_t = 0o600) throws {
        let component = try Self.safeComponent(name)
        let fileDescriptor = openat(descriptor, component, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, permissions)
        guard fileDescriptor >= 0 else {
            let code = errno
            throw code == EEXIST ? DirectoryDescriptorError.entryExists(child(component)) : DirectoryDescriptorError.createFailed(child(component), code)
        }
        defer { close(fileDescriptor) }
        try Self.writeAll(fileDescriptor, data, label: child(component))
    }

    /// Copies every byte of `source` into a new child file, returning the
    /// SHA-256 of what was actually written.
    public func copyNewFile(_ name: String, from source: SourceFileHandle, permissions: mode_t = 0o600, cancellationCheck: () throws -> Void = Task.checkCancellation) throws -> String {
        let component = try Self.safeComponent(name)
        let fileDescriptor = openat(descriptor, component, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, permissions)
        guard fileDescriptor >= 0 else {
            let code = errno
            throw code == EEXIST ? DirectoryDescriptorError.entryExists(child(component)) : DirectoryDescriptorError.createFailed(child(component), code)
        }
        defer { close(fileDescriptor) }
        var hasher = SHA256()
        try source.stream(cancellationCheck: cancellationCheck) { buffer in
            hasher.update(bufferPointer: UnsafeRawBufferPointer(buffer))
            try Self.writeAll(fileDescriptor, buffer, label: self.child(component))
        }
        return Self.hexadecimal(hasher.finalize())
    }

    /// SHA-256 of a child regular file, read through the anchored descriptor.
    public func hashRegularFile(_ name: String, cancellationCheck: () throws -> Void = Task.checkCancellation) throws -> String {
        let component = try Self.safeComponent(name)
        let handle = try SourceFileHandle.open(child: component, of: self)
        defer { handle.closeHandle() }
        var hasher = SHA256()
        try handle.stream(cancellationCheck: cancellationCheck) { buffer in
            hasher.update(bufferPointer: UnsafeRawBufferPointer(buffer))
        }
        return Self.hexadecimal(hasher.finalize())
    }

    public func regularFileByteCount(_ name: String) throws -> UInt64 {
        let component = try Self.safeComponent(name)
        var status = stat()
        guard fstatat(descriptor, component, &status, AT_SYMLINK_NOFOLLOW) == 0 else {
            throw DirectoryDescriptorError.ioFailed(child(component), errno)
        }
        guard (status.st_mode & S_IFMT) == S_IFREG else { throw DirectoryDescriptorError.notRegularFile(child(component)) }
        return UInt64(max(0, status.st_size))
    }

    public func entryExists(_ name: String) -> Bool {
        guard let component = try? Self.safeComponent(name) else { return false }
        var status = stat()
        return fstatat(descriptor, component, &status, AT_SYMLINK_NOFOLLOW) == 0
    }

    /// Renames a child of this directory to a child of `destination`, failing
    /// if the destination name already exists. `RENAME_EXCL` makes the
    /// "must not overwrite" rule part of the rename itself, so there is no
    /// window between an existence check and the publish.
    public func renameChildExclusively(_ name: String, toChild newName: String, of destination: DirectoryHandle) throws {
        let from = try Self.safeComponent(name)
        let to = try Self.safeComponent(newName)
        guard renameatx_np(descriptor, from, destination.descriptor, to, UInt32(RENAME_EXCL)) == 0 else {
            let code = errno
            throw code == EEXIST || code == ENOTEMPTY ? DirectoryDescriptorError.entryExists(destination.child(to)) : DirectoryDescriptorError.ioFailed(destination.child(to), code)
        }
    }

    /// Best-effort recursive removal of a child, used to discard staging that
    /// was never published. Descends through descriptors so a symlink planted
    /// mid-tree cannot make the walk delete anything outside this directory.
    public func removeChildRecursively(_ name: String) {
        guard let component = try? Self.safeComponent(name) else { return }
        var status = stat()
        guard fstatat(descriptor, component, &status, AT_SYMLINK_NOFOLLOW) == 0 else { return }
        if (status.st_mode & S_IFMT) == S_IFDIR {
            if let child = try? openChildDirectory(component) {
                for entry in child.childNames() { child.removeChildRecursively(entry) }
                child.closeHandle()
            }
            _ = unlinkat(descriptor, component, AT_REMOVEDIR)
        } else {
            _ = unlinkat(descriptor, component, 0)
        }
    }

    private func childNames() -> [String] {
        let duplicated = dup(descriptor)
        guard duplicated >= 0, let stream = fdopendir(duplicated) else {
            if duplicated >= 0 { close(duplicated) }
            return []
        }
        defer { closedir(stream) }
        var names: [String] = []
        while let entry = readdir(stream) {
            let name = withUnsafeBytes(of: entry.pointee.d_name) { raw in
                String(cString: raw.baseAddress!.assumingMemoryBound(to: CChar.self))
            }
            if name != "." && name != ".." { names.append(name) }
        }
        return names
    }

    private func child(_ component: String) -> String { "\(label)/\(component)" }

    static func safeComponent(_ name: String) throws -> String {
        guard !name.isEmpty, name != ".", name != "..",
              !name.contains("/"), !name.unicodeScalars.contains("\0") else {
            throw DirectoryDescriptorError.unsafeComponent(name)
        }
        return name
    }

    static func writeAll(_ fileDescriptor: Int32, _ bytes: Data, label: String) throws {
        try bytes.withUnsafeBytes { try writeAll(fileDescriptor, $0, label: label) }
    }

    static func writeAll(_ fileDescriptor: Int32, _ bytes: UnsafeRawBufferPointer, label: String) throws {
        guard var cursor = bytes.baseAddress else { return }
        var remaining = bytes.count
        while remaining > 0 {
            let written = write(fileDescriptor, cursor, remaining)
            if written < 0 {
                if errno == EINTR { continue }
                throw DirectoryDescriptorError.ioFailed(label, errno)
            }
            guard written > 0 else { throw DirectoryDescriptorError.ioFailed(label, EIO) }
            cursor = cursor.advanced(by: written)
            remaining -= written
        }
    }

    static func hexadecimal(_ digest: SHA256.Digest) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}

/// A regular file held open by descriptor.
///
/// Hashing and copying both read from this one descriptor, so the bytes that
/// are hashed and the bytes that are copied are provably the same inode: the
/// source cannot be swapped underneath the operation, only rewritten in place,
/// which the caller's re-hash still detects.
public final class SourceFileHandle {
    public let descriptor: Int32
    public let deviceID: dev_t
    public let inode: ino_t
    public let byteCount: UInt64
    private let label: String
    private var isClosed = false

    private init(descriptor: Int32, deviceID: dev_t, inode: ino_t, byteCount: UInt64, label: String) {
        self.descriptor = descriptor
        self.deviceID = deviceID
        self.inode = inode
        self.byteCount = byteCount
        self.label = label
    }

    deinit { if !isClosed { close(descriptor) } }

    public func closeHandle() {
        guard !isClosed else { return }
        isClosed = true
        close(descriptor)
    }

    /// Opens an absolute path without following a final symlink and proves the
    /// opened inode is the object that `lstat` described.
    public static func open(vettedRegularFile url: URL) throws -> SourceFileHandle {
        let path = url.path
        var before = stat()
        guard lstat(path, &before) == 0 else { throw DirectoryDescriptorError.openFailed(path, errno) }
        guard (before.st_mode & S_IFMT) == S_IFREG else { throw DirectoryDescriptorError.notRegularFile(path) }
        let descriptor = Darwin.open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { throw DirectoryDescriptorError.openFailed(path, errno) }
        return try finish(descriptor: descriptor, label: path, expecting: before)
    }

    static func open(child name: String, of directory: DirectoryHandle) throws -> SourceFileHandle {
        let component = try DirectoryHandle.safeComponent(name)
        let descriptor = openat(directory.descriptor, component, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { throw DirectoryDescriptorError.openFailed(component, errno) }
        return try finish(descriptor: descriptor, label: component, expecting: nil)
    }

    private static func finish(descriptor: Int32, label: String, expecting: stat?) throws -> SourceFileHandle {
        var opened = stat()
        guard fstat(descriptor, &opened) == 0 else {
            let code = errno
            close(descriptor)
            throw DirectoryDescriptorError.openFailed(label, code)
        }
        guard (opened.st_mode & S_IFMT) == S_IFREG else {
            close(descriptor)
            throw DirectoryDescriptorError.notRegularFile(label)
        }
        if let expecting, expecting.st_dev != opened.st_dev || expecting.st_ino != opened.st_ino {
            close(descriptor)
            throw DirectoryDescriptorError.identityChanged(label)
        }
        return SourceFileHandle(descriptor: descriptor, deviceID: opened.st_dev, inode: opened.st_ino, byteCount: UInt64(max(0, opened.st_size)), label: label)
    }

    public func sha256(cancellationCheck: () throws -> Void = Task.checkCancellation) throws -> String {
        var hasher = SHA256()
        try stream(cancellationCheck: cancellationCheck) { hasher.update(bufferPointer: UnsafeRawBufferPointer($0)) }
        return DirectoryHandle.hexadecimal(hasher.finalize())
    }

    /// Reads the whole file from offset zero with `pread`, so repeated passes
    /// over the same handle never depend on a shared file offset.
    func stream(chunkSize: Int = 1_048_576, cancellationCheck: () throws -> Void = Task.checkCancellation, _ body: (UnsafeRawBufferPointer) throws -> Void) throws {
        var buffer = [UInt8](repeating: 0, count: chunkSize)
        var offset: off_t = 0
        while true {
            try cancellationCheck()
            let read = buffer.withUnsafeMutableBytes { pread(descriptor, $0.baseAddress, chunkSize, offset) }
            if read < 0 {
                if errno == EINTR { continue }
                throw DirectoryDescriptorError.ioFailed(label, errno)
            }
            if read == 0 { break }
            try buffer.withUnsafeBytes { try body(UnsafeRawBufferPointer(rebasing: $0[0..<read])) }
            offset += off_t(read)
        }
    }
}
