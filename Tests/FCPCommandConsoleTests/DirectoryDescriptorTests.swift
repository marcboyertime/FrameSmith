import XCTest
@testable import FCPCommandConsoleCore

final class DirectoryDescriptorTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = FileManager.default.temporaryDirectory.appendingPathComponent("fcpcc-descriptor-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let root { try? FileManager.default.removeItem(at: root) }
        root = nil
        try super.tearDownWithError()
    }

    func testOpenRefusesASymlinkedDirectory() throws {
        let real = try makeDirectory("real")
        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
        XCTAssertThrowsError(try DirectoryHandle.open(vettedDirectory: link))
        XCTAssertThrowsError(try DirectoryHandle.open(vettedDirectory: root.appendingPathComponent("missing")))
        let file = root.appendingPathComponent("file.txt")
        try Data("x".utf8).write(to: file)
        XCTAssertThrowsError(try DirectoryHandle.open(vettedDirectory: file)) { error in
            XCTAssertEqual(error as? DirectoryDescriptorError, .notADirectory(file.path))
        }
    }

    /// The property the whole descriptor design exists for: once a directory is
    /// vetted and opened, swapping its path for a symlink cannot move a later
    /// write. Path-based I/O would land the payload in the decoy.
    func testWritesStayInTheVettedDirectoryAfterItsPathIsSwappedForASymlink() throws {
        let vetted = try makeDirectory("vetted")
        let handle = try DirectoryHandle.open(vettedDirectory: vetted)
        defer { handle.closeHandle() }

        let moved = root.appendingPathComponent("moved", isDirectory: true)
        let decoy = try makeDirectory("decoy")
        try FileManager.default.moveItem(at: vetted, to: moved)
        try FileManager.default.createSymbolicLink(at: vetted, withDestinationURL: decoy)

        try handle.writeNewFile("payload.txt", data: Data("anchored".utf8))
        let child = try handle.createDirectory("Media")
        defer { child.closeHandle() }
        try child.writeNewFile("inner.txt", data: Data("inner".utf8))

        XCTAssertEqual(try Data(contentsOf: moved.appendingPathComponent("payload.txt")), Data("anchored".utf8))
        XCTAssertEqual(try Data(contentsOf: moved.appendingPathComponent("Media/inner.txt")), Data("inner".utf8))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: decoy.path), [])
    }

    func testWriteNewFileNeitherFollowsNorOverwritesAPlantedEntry() throws {
        let directory = try makeDirectory("staging")
        let outside = root.appendingPathComponent("outside.txt")
        try Data("original".utf8).write(to: outside)
        let handle = try DirectoryHandle.open(vettedDirectory: directory)
        defer { handle.closeHandle() }

        try FileManager.default.createSymbolicLink(at: directory.appendingPathComponent("planted.txt"), withDestinationURL: outside)
        XCTAssertThrowsError(try handle.writeNewFile("planted.txt", data: Data("overwritten".utf8))) { error in
            XCTAssertEqual(error as? DirectoryDescriptorError, .entryExists("\(directory.path)/planted.txt"))
        }
        XCTAssertEqual(try Data(contentsOf: outside), Data("original".utf8))

        try handle.writeNewFile("real.txt", data: Data("first".utf8))
        XCTAssertThrowsError(try handle.writeNewFile("real.txt", data: Data("second".utf8)))
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("real.txt")), Data("first".utf8))
    }

    func testUnsafeComponentsAreRejectedBeforeAnySyscall() throws {
        let directory = try makeDirectory("staging")
        let handle = try DirectoryHandle.open(vettedDirectory: directory)
        defer { handle.closeHandle() }
        for name in ["", ".", "..", "a/b", "../escape"] {
            XCTAssertThrowsError(try handle.writeNewFile(name, data: Data())) { error in
                XCTAssertEqual(error as? DirectoryDescriptorError, .unsafeComponent(name))
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("escape").path))
    }

    /// `RENAME_EXCL` has to reject a dangling symlink too: `fileExists` reports
    /// nothing there, but publishing over it would write through the link.
    func testExclusiveRenameRefusesAnExistingOrDanglingDestination() throws {
        let directory = try makeDirectory("root")
        let handle = try DirectoryHandle.open(vettedDirectory: directory)
        defer { handle.closeHandle() }
        let staging = try handle.createDirectory("staging")
        staging.closeHandle()
        _ = try handle.createDirectory("occupied")

        XCTAssertThrowsError(try handle.renameChildExclusively("staging", toChild: "occupied", of: handle)) { error in
            XCTAssertEqual(error as? DirectoryDescriptorError, .entryExists("\(directory.path)/occupied"))
        }

        try FileManager.default.createSymbolicLink(
            at: directory.appendingPathComponent("dangling"),
            withDestinationURL: root.appendingPathComponent("does-not-exist")
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("dangling").path))
        XCTAssertThrowsError(try handle.renameChildExclusively("staging", toChild: "dangling", of: handle))

        try handle.renameChildExclusively("staging", toChild: "published", of: handle)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("published").path))
    }

    func testRecursiveRemovalUnlinksSymlinksInsteadOfDescendingThroughThem() throws {
        let directory = try makeDirectory("root")
        let handle = try DirectoryHandle.open(vettedDirectory: directory)
        defer { handle.closeHandle() }
        let staging = try handle.createDirectory("staging")
        try staging.writeNewFile("kept.txt", data: Data("kept".utf8))
        _ = try staging.createDirectory("nested")
        staging.closeHandle()

        let precious = try makeDirectory("precious")
        try Data("keep me".utf8).write(to: precious.appendingPathComponent("value.txt"))
        try FileManager.default.createSymbolicLink(
            at: directory.appendingPathComponent("staging/escape"),
            withDestinationURL: precious
        )

        handle.removeChildRecursively("staging")
        XCTAssertFalse(handle.entryExists("staging"))
        XCTAssertEqual(try Data(contentsOf: precious.appendingPathComponent("value.txt")), Data("keep me".utf8))
    }

    func testCopyReproducesBytesAndReportsTheHashOfWhatWasWritten() throws {
        let directory = try makeDirectory("out")
        let handle = try DirectoryHandle.open(vettedDirectory: directory)
        defer { handle.closeHandle() }
        let payload = Data((0..<(1_048_576 + 4321)).map { UInt8($0 % 251) })
        let source = root.appendingPathComponent("source.bin")
        try payload.write(to: source)

        let sourceHandle = try SourceFileHandle.open(vettedRegularFile: source)
        defer { sourceHandle.closeHandle() }
        XCTAssertEqual(sourceHandle.byteCount, UInt64(payload.count))
        let sourceHash = try sourceHandle.sha256()
        XCTAssertEqual(sourceHash, ContentHasher.sha256(payload))

        let copiedHash = try handle.copyNewFile("copy.bin", from: sourceHandle)
        XCTAssertEqual(copiedHash, sourceHash)
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("copy.bin")), payload)
        XCTAssertEqual(try handle.regularFileByteCount("copy.bin"), UInt64(payload.count))
        // Re-reading the same handle must not depend on a consumed file offset.
        XCTAssertEqual(try sourceHandle.sha256(), sourceHash)
    }

    func testSourceHandleRefusesSymlinksAndDirectories() throws {
        let file = root.appendingPathComponent("file.txt")
        try Data("x".utf8).write(to: file)
        let link = root.appendingPathComponent("link.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        XCTAssertThrowsError(try SourceFileHandle.open(vettedRegularFile: link)) { error in
            XCTAssertEqual(error as? DirectoryDescriptorError, .notRegularFile(link.path))
        }
        let directory = try makeDirectory("dir")
        XCTAssertThrowsError(try SourceFileHandle.open(vettedRegularFile: directory)) { error in
            XCTAssertEqual(error as? DirectoryDescriptorError, .notRegularFile(directory.path))
        }
    }

    private func makeDirectory(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
