import AVFoundation
import CryptoKit
import Darwin
import Foundation
import ImageIO

public enum LocalMediaKind: String, Codable, CaseIterable, Sendable {
    case movie
    case still
}

public struct LocalMediaDimensions: Codable, Equatable, Sendable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

/// Read-only metadata captured from a locally admitted source. The source is
/// never copied, rendered, or altered by admission.
public struct LocalMediaAsset: Codable, Equatable, Sendable {
    public let itemID: String
    public let url: URL
    public let kind: LocalMediaKind
    public let dimensions: LocalMediaDimensions
    public let durationSeconds: Double?
    public let frameRate: Double?
    public let hasAudio: Bool
    public let canonicalPath: String
    public let sha256: String

    public init(itemID: String, url: URL, kind: LocalMediaKind, dimensions: LocalMediaDimensions, durationSeconds: Double?, frameRate: Double?, hasAudio: Bool, canonicalPath: String, sha256: String) {
        self.itemID = itemID
        self.url = url
        self.kind = kind
        self.dimensions = dimensions
        self.durationSeconds = durationSeconds
        self.frameRate = frameRate
        self.hasAudio = hasAudio
        self.canonicalPath = canonicalPath
        self.sha256 = sha256
    }

    public var sourceIdentity: SourceIdentity {
        SourceIdentity(itemID: itemID, canonicalPath: canonicalPath, sha256: sha256)
    }
}

public enum LocalMediaAdmissionError: Error, LocalizedError, Equatable, Sendable {
    case notAbsoluteLocalFile(URL)
    case unsafePath(URL)
    case symlink(URL)
    case notRegularFile(URL)
    case unreadable(URL)
    case forbiddenFinalCutPath(URL)
    case unsupportedMedia(URL)
    case invalidDimensions(URL)
    case invalidDuration(URL)

    public var errorDescription: String? {
        switch self {
        case .notAbsoluteLocalFile(let url): return "Local media must be an absolute file URL: \(url.path)"
        case .unsafePath(let url): return "Unsafe or broad local-media path: \(url.path)"
        case .symlink(let url): return "Symlinked media is not admitted: \(url.path)"
        case .notRegularFile(let url): return "Local media must be a regular file: \(url.path)"
        case .unreadable(let url): return "Local media is not readable: \(url.path)"
        case .forbiddenFinalCutPath(let url): return "Final Cut application/library paths are not admitted: \(url.path)"
        case .unsupportedMedia(let url): return "Only decodable local movie or still files are admitted: \(url.path)"
        case .invalidDimensions(let url): return "Local media dimensions are invalid: \(url.path)"
        case .invalidDuration(let url): return "Movie duration is invalid: \(url.path)"
        }
    }
}

/// Performs local, read-only source admission. `lstat` is deliberately used
/// before decoding or hashing so symlinks, FIFOs, devices, and directories are
/// rejected without opening their payloads.
public struct LocalMediaAdmission: Sendable {
    public init() {}

    public func admit(_ input: URL) async throws -> LocalMediaAsset {
        let url = try Self.canonicalRegularFile(from: input)
        let sha256 = try hashCancellable(url)
        try Task.checkCancellation()

        if let still = stillMetadata(url) {
            return LocalMediaAsset(
                itemID: itemID(path: url.path, sha256: sha256),
                url: url,
                kind: .still,
                dimensions: still,
                durationSeconds: nil,
                frameRate: nil,
                hasAudio: false,
                canonicalPath: url.path,
                sha256: sha256
            )
        }

        let asset = AVURLAsset(url: url)
        do {
            let playable = try await asset.load(.isPlayable)
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            guard playable, let track = videoTracks.first else { throw LocalMediaAdmissionError.unsupportedMedia(url) }
            let naturalSize = try await track.load(.naturalSize)
            let dimensions = LocalMediaDimensions(width: Int(abs(naturalSize.width).rounded()), height: Int(abs(naturalSize.height).rounded()))
            guard dimensions.width > 0, dimensions.height > 0 else { throw LocalMediaAdmissionError.invalidDimensions(url) }
            let duration = try await asset.load(.duration).seconds
            guard duration.isFinite, duration > 0 else { throw LocalMediaAdmissionError.invalidDuration(url) }
            let nominalFrameRate = Double(try await track.load(.nominalFrameRate))
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            return LocalMediaAsset(
                itemID: itemID(path: url.path, sha256: sha256),
                url: url,
                kind: .movie,
                dimensions: dimensions,
                durationSeconds: duration,
                frameRate: nominalFrameRate.isFinite && nominalFrameRate > 0 ? nominalFrameRate : nil,
                hasAudio: !audioTracks.isEmpty,
                canonicalPath: url.path,
                sha256: sha256
            )
        } catch let error as LocalMediaAdmissionError {
            throw error
        } catch {
            throw LocalMediaAdmissionError.unsupportedMedia(url)
        }
    }

    static func canonicalRegularFile(from input: URL) throws -> URL {
        guard input.isFileURL, input.path.hasPrefix("/") else { throw LocalMediaAdmissionError.notAbsoluteLocalFile(input) }
        let lexical = input.standardizedFileURL
        guard lexical.path == input.path, !lexical.path.isEmpty, lexical.path != "/",
              !lexical.path.hasPrefix("/dev/"), !lexical.path.hasPrefix("/System/"),
              !lexical.path.hasPrefix("/private/var/db/") else {
            throw LocalMediaAdmissionError.unsafePath(input)
        }
        guard !lexical.path.split(separator: "/").contains(".."),
              !lexical.path.unicodeScalars.contains(where: { "\n\r".unicodeScalars.contains($0) }) else {
            throw LocalMediaAdmissionError.unsafePath(input)
        }
        var status = stat()
        guard lstat(lexical.path, &status) == 0 else { throw LocalMediaAdmissionError.unreadable(lexical) }
        guard (status.st_mode & S_IFMT) != S_IFLNK else { throw LocalMediaAdmissionError.symlink(lexical) }
        guard (status.st_mode & S_IFMT) == S_IFREG else { throw LocalMediaAdmissionError.notRegularFile(lexical) }
        let canonical = lexical.resolvingSymlinksInPath().standardizedFileURL
        guard canonical.path == lexical.path else { throw LocalMediaAdmissionError.symlink(lexical) }
        guard !isForbiddenFinalCutPath(canonical) else { throw LocalMediaAdmissionError.forbiddenFinalCutPath(canonical) }
        guard FileManager.default.isReadableFile(atPath: canonical.path) else { throw LocalMediaAdmissionError.unreadable(canonical) }
        return canonical
    }

    private func hashCancellable(_ url: URL) throws -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { throw LocalMediaAdmissionError.unreadable(url) }
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            try Task.checkCancellation()
            let chunk = try handle.read(upToCount: 1_048_576) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func stillMetadata(_ url: URL) -> LocalMediaDimensions? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0 else {
            return nil
        }
        return LocalMediaDimensions(width: width, height: height)
    }

    private func itemID(path: String, sha256: String) -> String {
        let pathHash = ContentHasher.sha256(Data(path.utf8))
        return "local-\(sha256.prefix(16))-\(pathHash.prefix(12))"
    }

    static func isForbiddenFinalCutPath(_ url: URL) -> Bool {
        let path = url.path
        return path == "/Applications/Final Cut Pro.app" || path.hasPrefix("/Applications/Final Cut Pro.app/") || path.contains(".fcpbundle") || path.contains("/Final Cut Pro Libraries/")
    }
}
