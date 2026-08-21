import AVFoundation
import CoreAudio
import CoreMedia
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

/// ImageIO orientation captured from the admitted still bytes. Raw pixel
/// dimensions alone are not sufficient: a 1920x1080 image tagged `.right`
/// decodes to a 1080x1920 presentation image.
public enum LocalMediaStillOrientation: UInt32, Codable, Equatable, Sendable {
    case up = 1
    case upMirrored = 2
    case down = 3
    case downMirrored = 4
    case leftMirrored = 5
    case right = 6
    case rightMirrored = 7
    case left = 8
}

/// Stable, Codable form of an AVFoundation preferred transform.
public struct LocalMediaAffineTransform: Codable, Equatable, Sendable {
    public let a: Double
    public let b: Double
    public let c: Double
    public let d: Double
    public let tx: Double
    public let ty: Double

    public init(a: Double, b: Double, c: Double, d: Double, tx: Double, ty: Double) {
        self.a = a
        self.b = b
        self.c = c
        self.d = d
        self.tx = tx
        self.ty = ty
    }

    public init(_ transform: CGAffineTransform) {
        self.init(
            a: transform.a,
            b: transform.b,
            c: transform.c,
            d: transform.d,
            tx: transform.tx,
            ty: transform.ty
        )
    }

    public static let identity = LocalMediaAffineTransform(
        a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0
    )
}

public enum LocalMediaVideoScanMode: String, Codable, Equatable, Sendable {
    case progressive
    case interlaced
    case unknown
}

public enum LocalMediaFrameCadenceClassification: String, Codable, Equatable, Sendable {
    case constant
    case variable
    case indeterminate
}

/// Decoded presentation-timestamp evidence, not just a container's nominal
/// frame-rate label.
public struct LocalMediaVideoCadence: Codable, Equatable, Sendable {
    public let classification: LocalMediaFrameCadenceClassification
    public let decodedFrameCount: Int
    public let minimumFrameDurationSeconds: Double?
    public let maximumFrameDurationSeconds: Double?

    public init(
        classification: LocalMediaFrameCadenceClassification,
        decodedFrameCount: Int,
        minimumFrameDurationSeconds: Double?,
        maximumFrameDurationSeconds: Double?
    ) {
        self.classification = classification
        self.decodedFrameCount = decodedFrameCount
        self.minimumFrameDurationSeconds = minimumFrameDurationSeconds
        self.maximumFrameDurationSeconds = maximumFrameDurationSeconds
    }

    public static func assumedConstant(frameRate: Double?, durationSeconds: Double?) -> Self? {
        guard let frameRate, frameRate.isFinite, frameRate > 0,
              let durationSeconds, durationSeconds.isFinite, durationSeconds > 0 else {
            return nil
        }
        let frameDuration = 1 / frameRate
        return .init(
            classification: .constant,
            decodedFrameCount: Int((durationSeconds * frameRate).rounded()),
            minimumFrameDurationSeconds: frameDuration,
            maximumFrameDurationSeconds: frameDuration
        )
    }
}

public enum LocalMediaAudioChannelLayout: String, Codable, Equatable, Sendable {
    case mono
    case stereo
    case multichannel
    case unknown
}

public struct LocalMediaAudioStream: Codable, Equatable, Sendable {
    public let sampleRate: Double?
    public let channelCount: Int
    public let channelLayout: LocalMediaAudioChannelLayout
    /// Core Audio layout tag observed in the format description. `nil` means
    /// the container supplied no layout evidence; two channels alone are not
    /// promoted to stereo.
    public let channelLayoutTag: UInt32?

    public init(
        sampleRate: Double?,
        channelCount: Int,
        channelLayout: LocalMediaAudioChannelLayout,
        channelLayoutTag: UInt32? = nil
    ) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.channelLayout = channelLayout
        self.channelLayoutTag = channelLayoutTag
    }

    public static let stereo48k = LocalMediaAudioStream(
        sampleRate: 48_000,
        channelCount: 2,
        channelLayout: .stereo,
        channelLayoutTag: UInt32(kAudioChannelLayoutTag_Stereo)
    )

    /// The exact raw AVFoundation tuple observed on the empirically returned
    /// eight-second movie parent. It is intentionally not called stereo:
    /// Core Media supplied two channels but no channel-layout tag.
    public static let observedUntaggedTwoChannel48k = LocalMediaAudioStream(
        sampleRate: 48_000,
        channelCount: 2,
        channelLayout: .unknown,
        channelLayoutTag: nil
    )
}

/// Pixel-, timing-, transform-, and audio-affecting facts derived from one
/// admitted byte identity. This value is used by planning staleness and render
/// construction identity so metadata drift cannot hide behind a stable path.
public struct LocalMediaContextFacts: Codable, Equatable, Sendable {
    public let kind: LocalMediaKind
    public let dimensions: LocalMediaDimensions
    public let durationSeconds: Double?
    public let frameRate: Double?
    public let hasAudio: Bool
    public let stillOrientation: LocalMediaStillOrientation?
    public let moviePreferredTransform: LocalMediaAffineTransform?
    public let videoTrackCount: Int?
    public let videoScanMode: LocalMediaVideoScanMode?
    public let videoCadence: LocalMediaVideoCadence?
    public let audioStreams: [LocalMediaAudioStream]?
}

/// In-memory capability marker. It is deliberately excluded from Codable and
/// cannot be set by either public `LocalMediaAsset` initializer, so a decoded
/// or hand-built asset never becomes proof that admission ran.
fileprivate struct LocalMediaAdmissionSeal: Equatable, Sendable {}

/// Read-only metadata captured from a locally admitted source. Admission never
/// alters or publishes the source; movies are inspected through a private,
/// short-lived immutable snapshot so metadata stays bound to one byte digest.
public struct LocalMediaAsset: Codable, Equatable, Sendable {
    public let itemID: String
    public let url: URL
    public let kind: LocalMediaKind
    public let dimensions: LocalMediaDimensions
    public let durationSeconds: Double?
    public let frameRate: Double?
    public let hasAudio: Bool
    public let stillOrientation: LocalMediaStillOrientation?
    public let moviePreferredTransform: LocalMediaAffineTransform?
    public let videoTrackCount: Int?
    public let videoScanMode: LocalMediaVideoScanMode?
    public let videoCadence: LocalMediaVideoCadence?
    public let audioStreams: [LocalMediaAudioStream]?
    public let canonicalPath: String
    public let sha256: String
    fileprivate var admissionSeal: LocalMediaAdmissionSeal? = nil

    private enum CodingKeys: String, CodingKey {
        case itemID, url, kind, dimensions, durationSeconds, frameRate, hasAudio
        case stillOrientation, moviePreferredTransform, videoTrackCount
        case videoScanMode, videoCadence, audioStreams, canonicalPath, sha256
    }

    /// Source-compatible convenience for callers that predate typed media
    /// context. Real admission uses the complete initializer below. The
    /// compatibility assumptions preserve existing non-admission fixtures;
    /// adversarial and production paths should always pass explicit facts.
    public init(itemID: String, url: URL, kind: LocalMediaKind, dimensions: LocalMediaDimensions, durationSeconds: Double?, frameRate: Double?, hasAudio: Bool, canonicalPath: String, sha256: String) {
        self.init(
            itemID: itemID,
            url: url,
            kind: kind,
            dimensions: dimensions,
            durationSeconds: durationSeconds,
            frameRate: frameRate,
            hasAudio: hasAudio,
            stillOrientation: kind == .still ? .up : nil,
            moviePreferredTransform: kind == .movie ? .identity : nil,
            videoTrackCount: kind == .movie ? 1 : nil,
            videoScanMode: kind == .movie ? .progressive : nil,
            videoCadence: kind == .movie
                ? .assumedConstant(frameRate: frameRate, durationSeconds: durationSeconds)
                : nil,
            audioStreams: kind == .movie ? (hasAudio ? [.observedUntaggedTwoChannel48k] : []) : nil,
            canonicalPath: canonicalPath,
            sha256: sha256
        )
    }

    public init(
        itemID: String,
        url: URL,
        kind: LocalMediaKind,
        dimensions: LocalMediaDimensions,
        durationSeconds: Double?,
        frameRate: Double?,
        hasAudio: Bool,
        stillOrientation: LocalMediaStillOrientation?,
        moviePreferredTransform: LocalMediaAffineTransform?,
        videoTrackCount: Int?,
        videoScanMode: LocalMediaVideoScanMode?,
        videoCadence: LocalMediaVideoCadence?,
        audioStreams: [LocalMediaAudioStream]?,
        canonicalPath: String,
        sha256: String
    ) {
        self.itemID = itemID
        self.url = url
        self.kind = kind
        self.dimensions = dimensions
        self.durationSeconds = durationSeconds
        self.frameRate = frameRate
        self.hasAudio = hasAudio
        self.stillOrientation = stillOrientation
        self.moviePreferredTransform = moviePreferredTransform
        self.videoTrackCount = videoTrackCount
        self.videoScanMode = videoScanMode
        self.videoCadence = videoCadence
        self.audioStreams = audioStreams
        self.canonicalPath = canonicalPath
        self.sha256 = sha256
    }

    public var sourceIdentity: SourceIdentity {
        SourceIdentity(itemID: itemID, canonicalPath: canonicalPath, sha256: sha256)
    }

    public var contextFacts: LocalMediaContextFacts {
        LocalMediaContextFacts(
            kind: kind,
            dimensions: dimensions,
            durationSeconds: durationSeconds,
            frameRate: frameRate,
            hasAudio: hasAudio,
            stillOrientation: stillOrientation,
            moviePreferredTransform: moviePreferredTransform,
            videoTrackCount: videoTrackCount,
            videoScanMode: videoScanMode,
            videoCadence: videoCadence,
            audioStreams: audioStreams
        )
    }

    /// Internal readiness proof used only to decide whether planning may show
    /// standalone export as available. Export still requires the separate
    /// opaque evidence token and its exact-context match.
    internal var hasTrustedAdmissionSeal: Bool { admissionSeal != nil }

    public static func == (lhs: LocalMediaAsset, rhs: LocalMediaAsset) -> Bool {
        lhs.itemID == rhs.itemID
            && lhs.url == rhs.url
            && lhs.canonicalPath == rhs.canonicalPath
            && lhs.sha256 == rhs.sha256
            && lhs.contextFacts == rhs.contextFacts
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
    case changedDuringAdmission(URL)

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
        case .changedDuringAdmission(let url): return "Local media changed while it was being admitted: \(url.path)"
        }
    }
}

/// Performs local, read-only source admission. `lstat` is deliberately used
/// before decoding or hashing so symlinks, FIFOs, devices, and directories are
/// rejected without opening their payloads.
public struct LocalMediaAdmission: Sendable {
    public init() {}

    /// Admit media and mint the capability evidence in one step.
    ///
    /// This is the **only** public way to obtain `AdmittedLocalMediaEvidence`.
    /// Its memberwise initializer stays internal so a decoded, hand-built, or
    /// downloaded value can never become evidence — but the admission path
    /// itself is exactly what evidence is supposed to attest to, so it must be
    /// reachable from outside the module or the standalone route cannot be
    /// driven at all.
    ///
    /// The invariant is unchanged: evidence exists only where media actually
    /// went through admission, was hashed, and was canonicalised.
    public func admitAll(_ inputs: [URL]) async throws -> (assets: [LocalMediaAsset], evidence: AdmittedLocalMediaEvidence) {
        var assets: [LocalMediaAsset] = []
        for input in inputs {
            assets.append(try await admit(input))
        }
        guard let evidence = AdmittedLocalMediaEvidence(admittedAssets: assets) else {
            throw LocalMediaAdmissionError.unreadable(inputs.first ?? URL(fileURLWithPath: "/"))
        }
        return (assets, evidence)
    }

    public func admit(_ input: URL) async throws -> LocalMediaAsset {
        let url = try Self.canonicalRegularFile(from: input)
        let snapshot = try snapshotCancellable(url)
        defer { try? FileManager.default.removeItem(at: snapshot.root) }

        if let still = try stillMetadata(
            snapshot.url,
            sourceURL: url,
            expectedSHA256: snapshot.sha256
        ) {
            try verifyCurrentSource(url, matches: snapshot.sha256)
            var admitted = LocalMediaAsset(
                itemID: itemID(path: url.path, sha256: snapshot.sha256),
                url: url,
                kind: .still,
                dimensions: still.dimensions,
                durationSeconds: nil,
                frameRate: nil,
                hasAudio: false,
                stillOrientation: still.orientation,
                moviePreferredTransform: nil,
                videoTrackCount: nil,
                videoScanMode: nil,
                videoCadence: nil,
                audioStreams: nil,
                canonicalPath: url.path,
                sha256: snapshot.sha256
            )
            admitted.admissionSeal = LocalMediaAdmissionSeal()
            return admitted
        }

        let asset = AVURLAsset(url: snapshot.url)
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
            let preferredTransform = LocalMediaAffineTransform(try await track.load(.preferredTransform))
            let formatDescriptions = try await track.load(.formatDescriptions)
            let scanMode = videoScanMode(formatDescriptions)
            let cadence = try videoCadence(asset: asset, track: track)
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            var audioStreams: [LocalMediaAudioStream] = []
            for audioTrack in audioTracks {
                audioStreams.append(try await audioStream(audioTrack))
            }
            try verifyCurrentSource(url, matches: snapshot.sha256)
            var admitted = LocalMediaAsset(
                itemID: itemID(path: url.path, sha256: snapshot.sha256),
                url: url,
                kind: .movie,
                dimensions: dimensions,
                durationSeconds: duration,
                frameRate: nominalFrameRate.isFinite && nominalFrameRate > 0 ? nominalFrameRate : nil,
                hasAudio: !audioStreams.isEmpty,
                stillOrientation: nil,
                moviePreferredTransform: preferredTransform,
                videoTrackCount: videoTracks.count,
                videoScanMode: scanMode,
                videoCadence: cadence,
                audioStreams: audioStreams,
                canonicalPath: url.path,
                sha256: snapshot.sha256
            )
            admitted.admissionSeal = LocalMediaAdmissionSeal()
            return admitted
        } catch let error as LocalMediaAdmissionError {
            throw error
        } catch let error as CancellationError {
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

    private func verifyCurrentSource(_ url: URL, matches expectedSHA256: String) throws {
        let canonical = try Self.canonicalRegularFile(from: url)
        guard canonical == url, try hashCancellable(canonical) == expectedSHA256 else {
            throw LocalMediaAdmissionError.changedDuringAdmission(url)
        }
    }

    private struct Snapshot {
        let root: URL
        let url: URL
        let sha256: String
    }

    /// Copies from one stable source descriptor into a private immutable
    /// snapshot while hashing the exact copied bytes. Movie metadata and sample
    /// cadence are read only from this snapshot, so a pathname replacement or
    /// change-and-restore cannot mix metadata from different content.
    private func snapshotCancellable(_ sourceURL: URL) throws -> Snapshot {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "framesmith-media-admission-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        do {
            let suffix = sourceURL.pathExtension.isEmpty ? "media" : sourceURL.pathExtension
            let snapshotURL = root.appendingPathComponent("snapshot.\(suffix)")
            guard FileManager.default.createFile(
                atPath: snapshotURL.path,
                contents: nil,
                attributes: [.posixPermissions: 0o600]
            ) else {
                throw LocalMediaAdmissionError.unreadable(sourceURL)
            }
            let descriptor = open(
                sourceURL.path,
                O_RDONLY | O_CLOEXEC | O_NOFOLLOW
            )
            guard descriptor >= 0 else {
                throw LocalMediaAdmissionError.changedDuringAdmission(sourceURL)
            }
            var descriptorStatus = stat()
            guard fstat(descriptor, &descriptorStatus) == 0,
                  (descriptorStatus.st_mode & S_IFMT) == S_IFREG else {
                close(descriptor)
                throw LocalMediaAdmissionError.changedDuringAdmission(sourceURL)
            }
            let source = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            let destination = try FileHandle(forWritingTo: snapshotURL)
            defer {
                try? source.close()
                try? destination.close()
            }
            var hasher = SHA256()
            while true {
                try Task.checkCancellation()
                let chunk = try source.read(upToCount: 1_048_576) ?? Data()
                if chunk.isEmpty { break }
                hasher.update(data: chunk)
                try destination.write(contentsOf: chunk)
            }
            try destination.synchronize()
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o400],
                ofItemAtPath: snapshotURL.path
            )
            let sha256 = hasher.finalize().map { String(format: "%02x", $0) }.joined()
            return Snapshot(root: root, url: snapshotURL, sha256: sha256)
        } catch {
            try? FileManager.default.removeItem(at: root)
            throw error
        }
    }

    private struct StillMetadata {
        let dimensions: LocalMediaDimensions
        let orientation: LocalMediaStillOrientation
    }

    /// Hashes and decodes one immutable in-memory value. The URL is used only
    /// to load the private snapshot bytes, never as the ImageIO decode source.
    private func stillMetadata(
        _ snapshotURL: URL,
        sourceURL: URL,
        expectedSHA256: String
    ) throws -> StillMetadata? {
        // A lightweight type check against the already immutable snapshot keeps
        // ordinary movies out of the in-memory still path. Actual still
        // properties are then decoded from the Data value hashed below.
        guard CGImageSourceCreateWithURL(snapshotURL as CFURL, nil) != nil else { return nil }
        let data = try Data(contentsOf: snapshotURL)
        guard ContentHasher.sha256(data) == expectedSHA256 else {
            throw LocalMediaAdmissionError.changedDuringAdmission(snapshotURL)
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0 else {
            return nil
        }
        guard CGImageSourceGetCount(source) == 1 else {
            throw LocalMediaAdmissionError.unsupportedMedia(sourceURL)
        }
        let rawOrientation: UInt32
        if let number = properties[kCGImagePropertyOrientation] as? NSNumber {
            rawOrientation = number.uint32Value
        } else if let value = properties[kCGImagePropertyOrientation] as? UInt32 {
            rawOrientation = value
        } else {
            rawOrientation = LocalMediaStillOrientation.up.rawValue
        }
        guard let orientation = LocalMediaStillOrientation(rawValue: rawOrientation) else {
            throw LocalMediaAdmissionError.unsupportedMedia(snapshotURL)
        }
        return StillMetadata(
            dimensions: LocalMediaDimensions(width: width, height: height),
            orientation: orientation
        )
    }

    private func videoScanMode(_ descriptions: [CMFormatDescription]) -> LocalMediaVideoScanMode {
        guard !descriptions.isEmpty else { return .unknown }
        let fieldCounts = descriptions.map { description -> Int? in
            guard let extensions = CMFormatDescriptionGetExtensions(description) as NSDictionary? else {
                return nil
            }
            return (extensions[kCMFormatDescriptionExtension_FieldCount] as? NSNumber)?.intValue
        }
        if fieldCounts.contains(where: { ($0 ?? 0) >= 2 }) { return .interlaced }
        if fieldCounts.allSatisfy({ $0 == 1 }) { return .progressive }
        return .unknown
    }

    private func videoCadence(asset: AVAsset, track: AVAssetTrack) throws -> LocalMediaVideoCadence {
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else {
            return .init(
                classification: .indeterminate,
                decodedFrameCount: 0,
                minimumFrameDurationSeconds: nil,
                maximumFrameDurationSeconds: nil
            )
        }
        reader.add(output)
        guard reader.startReading() else {
            return .init(
                classification: .indeterminate,
                decodedFrameCount: 0,
                minimumFrameDurationSeconds: nil,
                maximumFrameDurationSeconds: nil
            )
        }
        var timestamps: [Double] = []
        while let sample = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            guard CMSampleBufferGetNumSamples(sample) > 0 else { continue }
            let seconds = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample))
            if seconds.isFinite { timestamps.append(seconds) }
        }
        guard reader.status == .completed, timestamps.count >= 2 else {
            return .init(
                classification: .indeterminate,
                decodedFrameCount: timestamps.count,
                minimumFrameDurationSeconds: nil,
                maximumFrameDurationSeconds: nil
            )
        }
        let deltas = zip(timestamps.dropFirst(), timestamps).map(-)
        guard let minimum = deltas.min(), let maximum = deltas.max(), minimum > 0 else {
            return .init(
                classification: .variable,
                decodedFrameCount: timestamps.count,
                minimumFrameDurationSeconds: deltas.min(),
                maximumFrameDurationSeconds: deltas.max()
            )
        }
        let tolerance = max(1e-9, maximum * 1e-6)
        return .init(
            classification: maximum - minimum <= tolerance ? .constant : .variable,
            decodedFrameCount: timestamps.count,
            minimumFrameDurationSeconds: minimum,
            maximumFrameDurationSeconds: maximum
        )
    }

    private func audioStream(_ track: AVAssetTrack) async throws -> LocalMediaAudioStream {
        let descriptions = try await track.load(.formatDescriptions)
        for description in descriptions {
            guard let basic = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee else {
                continue
            }
            let channelCount = Int(basic.mChannelsPerFrame)
            var layoutSize = 0
            let observedLayout = CMAudioFormatDescriptionGetChannelLayout(
                description,
                sizeOut: &layoutSize
            )
            let layoutTag = observedLayout.map { UInt32($0.pointee.mChannelLayoutTag) }
            let layout: LocalMediaAudioChannelLayout
            switch layoutTag {
            case UInt32(kAudioChannelLayoutTag_Mono): layout = .mono
            case UInt32(kAudioChannelLayoutTag_Stereo): layout = .stereo
            case .some: layout = channelCount > 2 ? .multichannel : .unknown
            case .none: layout = .unknown
            }
            let sampleRate = basic.mSampleRate.isFinite && basic.mSampleRate > 0
                ? basic.mSampleRate
                : nil
            return LocalMediaAudioStream(
                sampleRate: sampleRate,
                channelCount: channelCount,
                channelLayout: layout,
                channelLayoutTag: layoutTag
            )
        }
        return LocalMediaAudioStream(
            sampleRate: nil,
            channelCount: 0,
            channelLayout: .unknown,
            channelLayoutTag: nil
        )
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
