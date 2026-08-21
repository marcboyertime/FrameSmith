import AVFoundation
import CoreImage
import CoreML
import CoreVideo
import Darwin
import Foundation
import ImageIO

/// How a source still is placed in the model's fixed 518 x 392 input.
///
/// Depth Anything V2's prose metadata describes a flexible shape, but this
/// particular Apple package is not flexible: Core ML rejects every input other
/// than 518 x 392. Keeping the placement policy in the recipe prevents a quiet
/// preprocessing change from reusing an incompatible render.
public enum LivingStillDepthAspectPolicy: String, Codable, CaseIterable, Sendable {
    /// Preserve source geometry, center it in the fixed model input, and fill
    /// the unused bands by extending the edge pixels. The inferred depth is
    /// cropped back to the content rectangle before it is mapped to the frame.
    case aspectFitEdgeExtended

    /// Map the complete source rect to the complete model rect. This keeps all
    /// pixels but changes their aspect while inference runs.
    case stretchToFixedModelInput
}

public struct LivingStillDepthRenderRequest: Codable, Equatable, Sendable {
    /// Bumped when the output codec changed from ProRes 422 Standard (`apcn`)
    /// to the admitted ProRes 422 HQ (`apch`). The renderer version participates
    /// in the recipe digest, so obsolete Standard cache entries cannot collide
    /// with or permanently block the HQ replacement render.
    public static let currentDeterministicVersion = "living-still-depth-warp-v2-hq"

    public let sourceURL: URL
    public let sourceSHA256: String
    public let targetWidth: Int
    public let targetHeight: Int
    public let durationSeconds: Double
    public let fps: Int
    /// 0...1. Scales only the bounded depth-dependent displacement.
    public let motionStrength: Double
    /// 0...0.15. Final camera push as a fraction of the initial scale.
    public let pushIn: Double
    /// -0.08...0.08. Final camera pan as a fraction of frame width.
    public let panX: Double
    /// -0.08...0.08. Final camera pan as a fraction of frame height.
    public let panY: Double
    /// 0...1. Controls a deterministic, edge-preserving depth smooth.
    public let depthSmoothing: Double
    /// Selects the deterministic fallback parallax direction when pan is zero.
    public let seed: UInt64
    public let deterministicVersion: String
    public let aspectPolicy: LivingStillDepthAspectPolicy

    public init(
        sourceURL: URL,
        sourceSHA256: String,
        targetWidth: Int,
        targetHeight: Int,
        durationSeconds: Double,
        fps: Int,
        motionStrength: Double = 0.90,
        pushIn: Double = 0.03,
        panX: Double = 0.015,
        panY: Double = 0,
        depthSmoothing: Double = 0.55,
        seed: UInt64 = 0,
        deterministicVersion: String = LivingStillDepthRenderRequest.currentDeterministicVersion,
        aspectPolicy: LivingStillDepthAspectPolicy = .aspectFitEdgeExtended
    ) {
        self.sourceURL = sourceURL
        self.sourceSHA256 = sourceSHA256
        self.targetWidth = targetWidth
        self.targetHeight = targetHeight
        self.durationSeconds = durationSeconds
        self.fps = fps
        self.motionStrength = motionStrength
        self.pushIn = pushIn
        self.panX = panX
        self.panY = panY
        self.depthSmoothing = depthSmoothing
        self.seed = seed
        self.deterministicVersion = deterministicVersion
        self.aspectPolicy = aspectPolicy
    }
}

public struct LivingStillDepthSourceFileHash: Codable, Equatable, Sendable {
    public let relativePath: String
    public let sha256: String

    public init(relativePath: String, sha256: String) {
        self.relativePath = relativePath
        self.sha256 = sha256
    }
}

public struct LivingStillDepthModelIdentity: Codable, Equatable, Sendable {
    public let identifier: String
    public let sourceRevision: String
    public let sourceURL: URL
    public let sourceFileHashes: [LivingStillDepthSourceFileHash]
    /// Digest of the deterministic, execution-bearing portion of the private
    /// Core ML compilation. The compiler's root `coremldata.bin` serializes an
    /// unordered metadata map and is deliberately not a recipe identity.
    public let compiledArtifactDigest: String
    /// Digest of every byte in the exact private compiled tree loaded by Core
    /// ML. This may vary when Core ML reorders semantically unordered metadata,
    /// but it is verified before load and again after prediction.
    public let compiledSnapshotDigest: String
    /// Digest of the three exact source-package files copied into the private
    /// compiler input. This binds compilation to the pinned Apple revision.
    public let compilerInputDigest: String
    public let compiledMetadataSHA256: String
    public let compilationMode: String
    public let specificationVersion: Int
    public let inputWidth: Int
    public let inputHeight: Int
    public let outputWidth: Int
    public let outputHeight: Int

    public init(
        identifier: String,
        sourceRevision: String,
        sourceURL: URL,
        sourceFileHashes: [LivingStillDepthSourceFileHash],
        compiledArtifactDigest: String,
        compiledSnapshotDigest: String,
        compilerInputDigest: String,
        compiledMetadataSHA256: String,
        compilationMode: String,
        specificationVersion: Int,
        inputWidth: Int,
        inputHeight: Int,
        outputWidth: Int,
        outputHeight: Int
    ) {
        self.identifier = identifier
        self.sourceRevision = sourceRevision
        self.sourceURL = sourceURL
        self.sourceFileHashes = sourceFileHashes
        self.compiledArtifactDigest = compiledArtifactDigest
        self.compiledSnapshotDigest = compiledSnapshotDigest
        self.compilerInputDigest = compilerInputDigest
        self.compiledMetadataSHA256 = compiledMetadataSHA256
        self.compilationMode = compilationMode
        self.specificationVersion = specificationVersion
        self.inputWidth = inputWidth
        self.inputHeight = inputHeight
        self.outputWidth = outputWidth
        self.outputHeight = outputHeight
    }
}

public struct LivingStillDepthRuntimeIdentity: Codable, Equatable, Sendable {
    public let operatingSystem: String
    public let architecture: String
    public let coreMLComputeUnits: String
    public let compilerCacheIdentity: String

    public init(
        operatingSystem: String,
        architecture: String,
        coreMLComputeUnits: String,
        compilerCacheIdentity: String
    ) {
        self.operatingSystem = operatingSystem
        self.architecture = architecture
        self.coreMLComputeUnits = coreMLComputeUnits
        self.compilerCacheIdentity = compilerCacheIdentity
    }
}

public struct LivingStillDepthRenderArtifact: Codable, Equatable, Sendable {
    public let movieURL: URL
    public let movieSHA256: String
    public let recipeDigest: String
    public let sourceSHA256: String
    public let model: LivingStillDepthModelIdentity
    public let runtime: LivingStillDepthRuntimeIdentity
    /// Digest of the canonical, normalized and smoothed 16-bit depth field.
    public let depthFieldDigest: String
    /// Digest of the model's returned FP16 samples before normalization.
    public let rawDepthFieldDigest: String
    public let codec: String
    public let codecProfile: String
    public let codecFourCC: String
    public let pixelFormat: String
    public let width: Int
    public let height: Int
    public let fps: Int
    public let frameCount: Int
    public let durationSeconds: Double
    public let videoOnly: Bool
    public let aspectPolicy: LivingStillDepthAspectPolicy
    public let overscanScale: Double
    public let maximumDepthDisplacementPixels: Double

    public init(
        movieURL: URL,
        movieSHA256: String,
        recipeDigest: String,
        sourceSHA256: String,
        model: LivingStillDepthModelIdentity,
        runtime: LivingStillDepthRuntimeIdentity,
        depthFieldDigest: String,
        rawDepthFieldDigest: String,
        codec: String,
        codecProfile: String,
        codecFourCC: String,
        pixelFormat: String,
        width: Int,
        height: Int,
        fps: Int,
        frameCount: Int,
        durationSeconds: Double,
        videoOnly: Bool,
        aspectPolicy: LivingStillDepthAspectPolicy,
        overscanScale: Double,
        maximumDepthDisplacementPixels: Double
    ) {
        self.movieURL = movieURL
        self.movieSHA256 = movieSHA256
        self.recipeDigest = recipeDigest
        self.sourceSHA256 = sourceSHA256
        self.model = model
        self.runtime = runtime
        self.depthFieldDigest = depthFieldDigest
        self.rawDepthFieldDigest = rawDepthFieldDigest
        self.codec = codec
        self.codecProfile = codecProfile
        self.codecFourCC = codecFourCC
        self.pixelFormat = pixelFormat
        self.width = width
        self.height = height
        self.fps = fps
        self.frameCount = frameCount
        self.durationSeconds = durationSeconds
        self.videoOnly = videoOnly
        self.aspectPolicy = aspectPolicy
        self.overscanScale = overscanScale
        self.maximumDepthDisplacementPixels = maximumDepthDisplacementPixels
    }
}

public enum LivingStillDepthRenderError: Error, LocalizedError, Equatable, Sendable {
    case invalidRequest(String)
    case sourceUnreadable(URL)
    case sourceHashMismatch(expected: String, actual: String)
    case modelArtifactMissing(URL)
    case modelArtifactUnsafe(URL)
    case modelSourceHashMismatch(path: String, expected: String, actual: String)
    case modelCompilationFailed(String)
    case modelSnapshotChanged(String)
    case modelMetadataInvalid(String)
    case modelLoadFailed(String)
    case modelPredictionFailed(String)
    case depthOutputInvalid(String)
    case kernelUnavailable
    case outputDirectoryUnsafe(URL)
    case writerFailed(String)
    case movieVerificationFailed(String)
    case destinationCollision(URL)

    public var errorDescription: String? {
        switch self {
        case .invalidRequest(let detail): return "Invalid Living Still depth request: \(detail)"
        case .sourceUnreadable(let url): return "Could not read the source still at \(url.path)"
        case .sourceHashMismatch(let expected, let actual): return "Source SHA-256 mismatch (expected \(expected), got \(actual))"
        case .modelArtifactMissing(let url): return "Pinned depth model artifact is missing at \(url.path)"
        case .modelArtifactUnsafe(let url): return "Pinned depth model artifact contains an unsafe entry at \(url.path)"
        case .modelSourceHashMismatch(let path, let expected, let actual): return "Pinned model source hash mismatch for \(path) (expected \(expected), got \(actual))"
        case .modelCompilationFailed(let detail): return "Could not privately compile the pinned Core ML depth model: \(detail)"
        case .modelSnapshotChanged(let detail): return "The private compiled depth-model snapshot changed: \(detail)"
        case .modelMetadataInvalid(let detail): return "Pinned depth model metadata is invalid: \(detail)"
        case .modelLoadFailed(let detail): return "Could not load the pinned Core ML depth model: \(detail)"
        case .modelPredictionFailed(let detail): return "Core ML depth inference failed: \(detail)"
        case .depthOutputInvalid(let detail): return "Core ML returned an invalid depth field: \(detail)"
        case .kernelUnavailable: return "The fixed Living Still depth-warp kernel could not be compiled"
        case .outputDirectoryUnsafe(let url): return "Unsafe Living Still output directory: \(url.path)"
        case .writerFailed(let detail): return "Could not encode the Living Still movie: \(detail)"
        case .movieVerificationFailed(let detail): return "The encoded Living Still movie failed verification: \(detail)"
        case .destinationCollision(let url): return "A different artifact already occupies \(url.path); it was not overwritten"
        }
    }
}

/// A private, sealed Core ML compilation admitted for one render.
///
/// The installed `.mlmodelc` cache is intentionally not represented here. The
/// executable model is compiled from a descriptor-copied snapshot of the exact
/// pinned source package, then copied again into this unique private root. The
/// retained descriptors let every later verification detect pathname swaps.
public final class LivingStillDepthModelAdmission: @unchecked Sendable {
    public let identity: LivingStillDepthModelIdentity
    let compiledModelURL: URL
    let snapshotRootURL: URL

    private let snapshotRoot: DirectoryHandle
    private let compiledRoot: DirectoryHandle
    private let expectedTree: LivingStillDepthModelLocator.CompiledTreeIdentity
    private let snapshotRootIdentity: LivingStillDepthModelLocator.FileSystemIdentity
    private let compiledRootIdentity: LivingStillDepthModelLocator.FileSystemIdentity
    private var isClosed = false

    fileprivate init(
        identity: LivingStillDepthModelIdentity,
        compiledModelURL: URL,
        snapshotRootURL: URL,
        snapshotRoot: DirectoryHandle,
        compiledRoot: DirectoryHandle,
        expectedTree: LivingStillDepthModelLocator.CompiledTreeIdentity,
        snapshotRootIdentity: LivingStillDepthModelLocator.FileSystemIdentity,
        compiledRootIdentity: LivingStillDepthModelLocator.FileSystemIdentity
    ) {
        self.identity = identity
        self.compiledModelURL = compiledModelURL
        self.snapshotRootURL = snapshotRootURL
        self.snapshotRoot = snapshotRoot
        self.compiledRoot = compiledRoot
        self.expectedTree = expectedTree
        self.snapshotRootIdentity = snapshotRootIdentity
        self.compiledRootIdentity = compiledRootIdentity
    }

    deinit { close() }

    func verifySnapshot() throws {
        guard !isClosed else {
            throw LivingStillDepthRenderError.modelSnapshotChanged("admission was already closed")
        }
        try LivingStillDepthModelLocator.verifySealedAdmission(
            snapshotRootURL: snapshotRootURL,
            snapshotRoot: snapshotRoot,
            snapshotRootIdentity: snapshotRootIdentity,
            compiledModelURL: compiledModelURL,
            compiledRoot: compiledRoot,
            compiledRootIdentity: compiledRootIdentity,
            expectedTree: expectedTree
        )
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        LivingStillDepthModelLocator.destroyPrivateAdmission(
            snapshotRootURL: snapshotRootURL,
            snapshotRoot: snapshotRoot,
            expectedIdentity: snapshotRootIdentity
        )
        compiledRoot.closeHandle()
        snapshotRoot.closeHandle()
    }
}

/// Locates and admits exactly the pinned Apple DA-V2 Small FP16 artifact.
///
/// An override points at a complete version root containing the source
/// `.mlpackage`. The adjacent installed `.mlmodelc` is only an acquisition-time
/// readiness cache: inference never trusts or opens it. Production compilation
/// always starts from an immutable private snapshot of the three pinned source
/// files, closing the independent-cache provenance and path-swap gaps.
public struct LivingStillDepthModelLocator: Sendable {
    public static let modelIdentifier = "apple.coreml.depth-anything-v2-small-f16"
    public static let sourceRevision = "cfef6f6f2a70783dedc0bfae40cecbc2052285d3"
    public static let packageName = "DepthAnythingV2SmallF16.mlpackage"
    public static let compiledModelName = "DepthAnythingV2SmallF16.mlmodelc"
    public static let modelWidth = 518
    public static let modelHeight = 392
    public static let compilationMode = "coreml-private-compile-from-pinned-source-v1"

    public static let expectedSourceFileHashes: [LivingStillDepthSourceFileHash] = [
        .init(relativePath: "DepthAnythingV2SmallF16.mlpackage/Manifest.json", sha256: "2883ae290c48fe916dc5ececac03a7d847fa277165a49ef5652fa1d2b9cb55f7"),
        .init(relativePath: "DepthAnythingV2SmallF16.mlpackage/Data/com.apple.CoreML/model.mlmodel", sha256: "44ac97a3efcfd52113183fb2862ff59cd0368e9ec2e30a90a54980dd11407042"),
        .init(relativePath: "DepthAnythingV2SmallF16.mlpackage/Data/com.apple.CoreML/weights/weight.bin", sha256: "fa60d9b6a155734f59029ebb882fd54e549bfaee3539c1a9cbd2cbbab64a0fed")
    ]

    public let explicitModelRoot: URL?

    public init(explicitModelRoot: URL? = nil) {
        self.explicitModelRoot = explicitModelRoot
    }

    public var resolvedModelRoot: URL {
        if let explicitModelRoot { return explicitModelRoot.standardizedFileURL }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Movies/FCPCommandConsole/models/apple-coreml-depth-anything-v2-small", isDirectory: true)
            .appendingPathComponent(Self.sourceRevision, isDirectory: true)
    }

    public var compiledModelURL: URL {
        resolvedModelRoot.appendingPathComponent(Self.compiledModelName, isDirectory: true)
    }

    /// A cheap presence check for integration-test skipping. Only the package
    /// is required because inference never opens the adjacent compiled cache.
    public var runtimeArtifactIsPresent: Bool {
        Self.expectedSourceFileHashes.allSatisfy {
            var status = stat()
            let url = resolvedModelRoot.appendingPathComponent($0.relativePath)
            return lstat(url.path, &status) == 0 && (status.st_mode & S_IFMT) == S_IFREG
        }
    }

    public func locate() throws -> LivingStillDepthModelAdmission {
        let root = resolvedModelRoot
        try Self.requireDirectory(root)

        let privateRootURL = try Self.makePrivateTemporaryRoot()
        let privateRoot: DirectoryHandle
        do { privateRoot = try DirectoryHandle.open(vettedDirectory: privateRootURL) }
        catch {
            try? FileManager.default.removeItem(at: privateRootURL)
            throw LivingStillDepthRenderError.modelCompilationFailed(error.localizedDescription)
        }

        do {
            let package = try Self.snapshotPinnedPackage(
                sourceRoot: root,
                destinationRoot: privateRoot,
                privateRootURL: privateRootURL
            )
            let compilerInputDigest = Self.canonicalManifestDigest(Self.expectedSourceFileHashes)

            // Core ML receives a read-only package under a mode-0700 unique
            // parent. The compiler can read it but no ordinary pathname writer
            // can change the already hash-matched input mid-compilation.
            try Self.sealDirectoryTree(package.handle)

            let compilerOutput: URL
            do { compilerOutput = try MLModel.compileModel(at: package.url) }
            catch { throw LivingStillDepthRenderError.modelCompilationFailed(error.localizedDescription) }
            defer { try? FileManager.default.removeItem(at: compilerOutput) }

            let compiledURL = privateRootURL.appendingPathComponent(Self.compiledModelName, isDirectory: true)
            let compiledRoot = try privateRoot.createDirectory(Self.compiledModelName, permissions: 0o700)
            let tree: CompiledTreeIdentity
            do {
                let sourceCompiled = try DirectoryHandle.open(vettedDirectory: compilerOutput)
                defer { sourceCompiled.closeHandle() }
                tree = try Self.copyCompiledTree(from: sourceCompiled, to: compiledRoot)
            } catch let error as LivingStillDepthRenderError {
                compiledRoot.closeHandle()
                throw error
            } catch {
                compiledRoot.closeHandle()
                throw LivingStillDepthRenderError.modelCompilationFailed(error.localizedDescription)
            }

            guard let metadataDigest = tree.fileHashes["coremldata.bin"] else {
                compiledRoot.closeHandle()
                throw LivingStillDepthRenderError.modelArtifactMissing(compiledURL.appendingPathComponent("coremldata.bin"))
            }
            let executableDigest = try Self.compiledExecutionDigest(
                tree: tree,
                compilerInputDigest: compilerInputDigest
            )

            // Remove write permission from every package/compiled directory and
            // finally from the unique root itself. Files were created 0400.
            try Self.sealDirectoryTree(compiledRoot)
            guard fchmod(privateRoot.descriptor, 0o500) == 0 else {
                compiledRoot.closeHandle()
                throw LivingStillDepthRenderError.modelCompilationFailed("could not seal private model root: \(String(cString: strerror(errno)))")
            }

            let rootIdentity = try Self.fileSystemIdentity(privateRoot.descriptor, label: privateRootURL.path)
            let compiledIdentity = try Self.fileSystemIdentity(compiledRoot.descriptor, label: compiledURL.path)
            package.handle.closeHandle()

            let identity = LivingStillDepthModelIdentity(
                identifier: Self.modelIdentifier,
                sourceRevision: Self.sourceRevision,
                sourceURL: URL(string: "https://huggingface.co/apple/coreml-depth-anything-v2-small")!,
                sourceFileHashes: Self.expectedSourceFileHashes,
                compiledArtifactDigest: executableDigest,
                compiledSnapshotDigest: tree.digest,
                compilerInputDigest: compilerInputDigest,
                compiledMetadataSHA256: metadataDigest,
                compilationMode: Self.compilationMode,
                specificationVersion: 8,
                inputWidth: Self.modelWidth,
                inputHeight: Self.modelHeight,
                outputWidth: Self.modelWidth,
                outputHeight: Self.modelHeight
            )
            let admission = LivingStillDepthModelAdmission(
                identity: identity,
                compiledModelURL: compiledURL,
                snapshotRootURL: privateRootURL,
                snapshotRoot: privateRoot,
                compiledRoot: compiledRoot,
                expectedTree: tree,
                snapshotRootIdentity: rootIdentity,
                compiledRootIdentity: compiledIdentity
            )
            try admission.verifySnapshot()
            return admission
        } catch {
            Self.destroyPrivateAdmission(
                snapshotRootURL: privateRootURL,
                snapshotRoot: privateRoot,
                expectedIdentity: try? Self.fileSystemIdentity(privateRoot.descriptor, label: privateRootURL.path)
            )
            privateRoot.closeHandle()
            throw error
        }
    }

    private static func requireDirectory(_ url: URL) throws {
        var status = stat()
        guard lstat(url.path, &status) == 0 else { throw LivingStillDepthRenderError.modelArtifactMissing(url) }
        guard (status.st_mode & S_IFMT) == S_IFDIR else { throw LivingStillDepthRenderError.modelArtifactUnsafe(url) }
    }

    struct FileSystemIdentity: Equatable, Sendable {
        let device: dev_t
        let inode: ino_t
    }

    struct CompiledTreeIdentity: Equatable, Sendable {
        let digest: String
        let fileHashes: [String: String]
    }

    private struct PackageSnapshot {
        let url: URL
        let handle: DirectoryHandle
    }

    private static let executionBearingCompiledPaths = [
        "analytics/coremldata.bin",
        "model.mil",
        "weights/weight.bin"
    ]

    private static func makePrivateTemporaryRoot() throws -> URL {
        let parent = FileManager.default.temporaryDirectory.standardizedFileURL
        var template = Array(parent.appendingPathComponent("framesmith-depth-model.XXXXXX").path.utf8CString)
        let created = template.withUnsafeMutableBufferPointer { buffer -> String? in
            guard let base = buffer.baseAddress, let path = mkdtemp(base) else { return nil }
            return String(cString: path)
        }
        guard let created else {
            throw LivingStillDepthRenderError.modelCompilationFailed("could not create private model root: \(String(cString: strerror(errno)))")
        }
        guard chmod(created, 0o700) == 0 else {
            let code = errno
            try? FileManager.default.removeItem(atPath: created)
            throw LivingStillDepthRenderError.modelCompilationFailed("could not protect private model root: \(String(cString: strerror(code)))")
        }
        return URL(fileURLWithPath: created, isDirectory: true)
    }

    private static func snapshotPinnedPackage(
        sourceRoot: URL,
        destinationRoot: DirectoryHandle,
        privateRootURL: URL
    ) throws -> PackageSnapshot {
        let package = try destinationRoot.createDirectory(packageName, permissions: 0o700)
        do {
            let data = try package.createDirectory("Data", permissions: 0o700)
            defer { data.closeHandle() }
            let coreML = try data.createDirectory("com.apple.CoreML", permissions: 0o700)
            defer { coreML.closeHandle() }
            let weights = try coreML.createDirectory("weights", permissions: 0o700)
            defer { weights.closeHandle() }

            let destinations: [String: (DirectoryHandle, String)] = [
                "DepthAnythingV2SmallF16.mlpackage/Manifest.json": (package, "Manifest.json"),
                "DepthAnythingV2SmallF16.mlpackage/Data/com.apple.CoreML/model.mlmodel": (coreML, "model.mlmodel"),
                "DepthAnythingV2SmallF16.mlpackage/Data/com.apple.CoreML/weights/weight.bin": (weights, "weight.bin")
            ]
            for expected in expectedSourceFileHashes {
                let sourceURL = sourceRoot.appendingPathComponent(expected.relativePath)
                let source: SourceFileHandle
                do { source = try SourceFileHandle.open(vettedRegularFile: sourceURL) }
                catch { throw LivingStillDepthRenderError.modelArtifactMissing(sourceURL) }
                defer { source.closeHandle() }
                let observed = try source.sha256(cancellationCheck: {})
                guard observed == expected.sha256 else {
                    throw LivingStillDepthRenderError.modelSourceHashMismatch(
                        path: expected.relativePath,
                        expected: expected.sha256,
                        actual: observed
                    )
                }
                guard let destination = destinations[expected.relativePath] else {
                    throw LivingStillDepthRenderError.modelMetadataInvalid("no private-snapshot destination for \(expected.relativePath)")
                }
                let copied = try destination.0.copyNewFile(
                    destination.1,
                    from: source,
                    permissions: 0o400,
                    cancellationCheck: {}
                )
                guard copied == expected.sha256 else {
                    throw LivingStillDepthRenderError.modelSourceHashMismatch(
                        path: expected.relativePath,
                        expected: expected.sha256,
                        actual: copied
                    )
                }
            }
            _ = fsync(weights.descriptor)
            _ = fsync(coreML.descriptor)
            _ = fsync(data.descriptor)
            _ = fsync(package.descriptor)
            return PackageSnapshot(
                url: privateRootURL.appendingPathComponent(packageName, isDirectory: true),
                handle: package
            )
        } catch {
            package.closeHandle()
            throw error
        }
    }

    private static func copyCompiledTree(
        from source: DirectoryHandle,
        to destination: DirectoryHandle
    ) throws -> CompiledTreeIdentity {
        var hashes: [String: String] = [:]
        try copyDirectoryContents(from: source, to: destination, prefix: "", hashes: &hashes)
        guard !hashes.isEmpty else {
            throw LivingStillDepthRenderError.modelCompilationFailed("Core ML produced an empty compiled model")
        }
        return .init(digest: canonicalHashManifest(hashes), fileHashes: hashes)
    }

    private static func copyDirectoryContents(
        from source: DirectoryHandle,
        to destination: DirectoryHandle,
        prefix: String,
        hashes: inout [String: String]
    ) throws {
        for name in try childNames(source) {
            var status = stat()
            guard fstatat(source.descriptor, name, &status, AT_SYMLINK_NOFOLLOW) == 0 else {
                throw LivingStillDepthRenderError.modelArtifactUnsafe(URL(fileURLWithPath: prefix + name))
            }
            let relativePath = prefix + name
            switch status.st_mode & S_IFMT {
            case S_IFDIR:
                let sourceChild = try source.openChildDirectory(name)
                defer { sourceChild.closeHandle() }
                let destinationChild = try destination.createDirectory(name, permissions: 0o700)
                defer { destinationChild.closeHandle() }
                try copyDirectoryContents(
                    from: sourceChild,
                    to: destinationChild,
                    prefix: relativePath + "/",
                    hashes: &hashes
                )
                _ = fsync(destinationChild.descriptor)
            case S_IFREG:
                let sourceFile = try SourceFileHandle.open(child: name, of: source)
                defer { sourceFile.closeHandle() }
                let hash = try destination.copyNewFile(
                    name,
                    from: sourceFile,
                    permissions: 0o400,
                    cancellationCheck: {}
                )
                guard hashes.updateValue(hash, forKey: relativePath) == nil else {
                    throw LivingStillDepthRenderError.modelCompilationFailed("duplicate compiled path \(relativePath)")
                }
            default:
                throw LivingStillDepthRenderError.modelArtifactUnsafe(URL(fileURLWithPath: relativePath))
            }
        }
        _ = fsync(destination.descriptor)
    }

    private static func compiledExecutionDigest(
        tree: CompiledTreeIdentity,
        compilerInputDigest: String
    ) throws -> String {
        var hashes: [String: String] = [:]
        for path in executionBearingCompiledPaths {
            guard let hash = tree.fileHashes[path] else {
                throw LivingStillDepthRenderError.modelCompilationFailed("compiled model is missing execution-bearing file \(path)")
            }
            hashes[path] = hash
        }
        var manifest = Data()
        manifest.append(contentsOf: compilationMode.utf8)
        manifest.append(10)
        manifest.append(contentsOf: compilerInputDigest.utf8)
        manifest.append(10)
        manifest.append(contentsOf: canonicalHashManifest(hashes).utf8)
        manifest.append(10)
        return ContentHasher.sha256(manifest)
    }

    private static func canonicalManifestDigest(_ files: [LivingStillDepthSourceFileHash]) -> String {
        canonicalHashManifest(Dictionary(uniqueKeysWithValues: files.map { ($0.relativePath, $0.sha256) }))
    }

    private static func canonicalHashManifest(_ hashes: [String: String]) -> String {
        var manifest = Data()
        for path in hashes.keys.sorted() {
            manifest.append(contentsOf: path.utf8)
            manifest.append(0)
            manifest.append(contentsOf: hashes[path]!.utf8)
            manifest.append(10)
        }
        return ContentHasher.sha256(manifest)
    }

    private static func childNames(_ directory: DirectoryHandle) throws -> [String] {
        // `dup` would share the directory stream offset with the retained
        // descriptor, making a second integrity pass falsely observe an empty
        // tree. Re-open `.` relative to the anchored descriptor to obtain an
        // independent open-file description for every enumeration.
        let independent = openat(
            directory.descriptor,
            ".",
            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        )
        guard independent >= 0 else {
            throw LivingStillDepthRenderError.modelCompilationFailed("could not reopen compiled directory descriptor")
        }
        guard let stream = fdopendir(independent) else {
            let code = errno
            close(independent)
            throw LivingStillDepthRenderError.modelCompilationFailed("could not enumerate compiled directory: \(String(cString: strerror(code)))")
        }
        defer { closedir(stream) }
        var names: [String] = []
        while let entry = readdir(stream) {
            let name = withUnsafeBytes(of: entry.pointee.d_name) { raw in
                String(cString: raw.baseAddress!.assumingMemoryBound(to: CChar.self))
            }
            if name != "." && name != ".." { names.append(name) }
        }
        return names.sorted()
    }

    private static func sealDirectoryTree(_ directory: DirectoryHandle) throws {
        for name in try childNames(directory) {
            var status = stat()
            guard fstatat(directory.descriptor, name, &status, AT_SYMLINK_NOFOLLOW) == 0 else {
                throw LivingStillDepthRenderError.modelSnapshotChanged("could not inspect \(name) while sealing")
            }
            if (status.st_mode & S_IFMT) == S_IFDIR {
                let child = try directory.openChildDirectory(name)
                try sealDirectoryTree(child)
                child.closeHandle()
            } else if (status.st_mode & S_IFMT) != S_IFREG {
                throw LivingStillDepthRenderError.modelArtifactUnsafe(URL(fileURLWithPath: name))
            }
        }
        guard fchmod(directory.descriptor, 0o500) == 0 else {
            throw LivingStillDepthRenderError.modelSnapshotChanged("could not seal a private model directory")
        }
    }

    private static func fileSystemIdentity(_ descriptor: Int32, label: String) throws -> FileSystemIdentity {
        var status = stat()
        guard fstat(descriptor, &status) == 0, (status.st_mode & S_IFMT) == S_IFDIR else {
            throw LivingStillDepthRenderError.modelSnapshotChanged("could not identify \(label)")
        }
        return .init(device: status.st_dev, inode: status.st_ino)
    }

    private static func pathIdentity(_ url: URL) throws -> FileSystemIdentity {
        var status = stat()
        guard lstat(url.path, &status) == 0, (status.st_mode & S_IFMT) == S_IFDIR else {
            throw LivingStillDepthRenderError.modelSnapshotChanged("private path is missing or no longer a directory: \(url.path)")
        }
        return .init(device: status.st_dev, inode: status.st_ino)
    }

    static func verifySealedAdmission(
        snapshotRootURL: URL,
        snapshotRoot: DirectoryHandle,
        snapshotRootIdentity: FileSystemIdentity,
        compiledModelURL: URL,
        compiledRoot: DirectoryHandle,
        compiledRootIdentity: FileSystemIdentity,
        expectedTree: CompiledTreeIdentity
    ) throws {
        guard try fileSystemIdentity(snapshotRoot.descriptor, label: snapshotRootURL.path) == snapshotRootIdentity,
              try pathIdentity(snapshotRootURL) == snapshotRootIdentity,
              try fileSystemIdentity(compiledRoot.descriptor, label: compiledModelURL.path) == compiledRootIdentity,
              try pathIdentity(compiledModelURL) == compiledRootIdentity else {
            throw LivingStillDepthRenderError.modelSnapshotChanged("private model pathname was replaced")
        }
        var rootStatus = stat()
        var compiledStatus = stat()
        guard fstat(snapshotRoot.descriptor, &rootStatus) == 0,
              fstat(compiledRoot.descriptor, &compiledStatus) == 0,
              (rootStatus.st_mode & 0o222) == 0,
              (compiledStatus.st_mode & 0o222) == 0 else {
            throw LivingStillDepthRenderError.modelSnapshotChanged("private model directories regained write permission")
        }
        let observed = try compiledTreeIdentity(compiledRoot, requireSealed: true)
        guard observed == expectedTree else {
            throw LivingStillDepthRenderError.modelSnapshotChanged("compiled tree digest or membership no longer matches")
        }
    }

    private static func compiledTreeIdentity(
        _ root: DirectoryHandle,
        requireSealed: Bool
    ) throws -> CompiledTreeIdentity {
        var hashes: [String: String] = [:]
        try collectTreeIdentity(root, prefix: "", requireSealed: requireSealed, hashes: &hashes)
        guard !hashes.isEmpty else {
            throw LivingStillDepthRenderError.modelSnapshotChanged("compiled model tree is empty")
        }
        return .init(digest: canonicalHashManifest(hashes), fileHashes: hashes)
    }

    private static func collectTreeIdentity(
        _ directory: DirectoryHandle,
        prefix: String,
        requireSealed: Bool,
        hashes: inout [String: String]
    ) throws {
        var directoryStatus = stat()
        guard fstat(directory.descriptor, &directoryStatus) == 0,
              !requireSealed || (directoryStatus.st_mode & 0o222) == 0 else {
            throw LivingStillDepthRenderError.modelSnapshotChanged("compiled directory is writable")
        }
        for name in try childNames(directory) {
            var status = stat()
            guard fstatat(directory.descriptor, name, &status, AT_SYMLINK_NOFOLLOW) == 0 else {
                throw LivingStillDepthRenderError.modelSnapshotChanged("compiled entry disappeared: \(prefix + name)")
            }
            let path = prefix + name
            switch status.st_mode & S_IFMT {
            case S_IFDIR:
                let child = try directory.openChildDirectory(name)
                defer { child.closeHandle() }
                try collectTreeIdentity(child, prefix: path + "/", requireSealed: requireSealed, hashes: &hashes)
            case S_IFREG:
                guard !requireSealed || (status.st_mode & 0o222) == 0 else {
                    throw LivingStillDepthRenderError.modelSnapshotChanged("compiled file is writable: \(path)")
                }
                let file = try SourceFileHandle.open(child: name, of: directory)
                defer { file.closeHandle() }
                hashes[path] = try file.sha256(cancellationCheck: {})
            default:
                throw LivingStillDepthRenderError.modelSnapshotChanged("unsafe compiled entry: \(path)")
            }
        }
    }

    static func destroyPrivateAdmission(
        snapshotRootURL: URL,
        snapshotRoot: DirectoryHandle,
        expectedIdentity: FileSystemIdentity?
    ) {
        unsealDirectories(snapshotRoot)
        for name in (try? childNames(snapshotRoot)) ?? [] { snapshotRoot.removeChildRecursively(name) }
        guard let expectedIdentity,
              (try? pathIdentity(snapshotRootURL)) == expectedIdentity else { return }
        _ = rmdir(snapshotRootURL.path)
    }

    private static func unsealDirectories(_ directory: DirectoryHandle) {
        _ = fchmod(directory.descriptor, 0o700)
        for name in (try? childNames(directory)) ?? [] {
            var status = stat()
            guard fstatat(directory.descriptor, name, &status, AT_SYMLINK_NOFOLLOW) == 0,
                  (status.st_mode & S_IFMT) == S_IFDIR,
                  let child = try? directory.openChildDirectory(name) else { continue }
            unsealDirectories(child)
            child.closeHandle()
        }
    }
}

struct LivingStillDepthAspectMapping: Equatable, Sendable {
    let contentRect: CGRect
    let scaleX: CGFloat
    let scaleY: CGFloat

    static func make(
        sourceWidth: Int,
        sourceHeight: Int,
        policy: LivingStillDepthAspectPolicy,
        modelWidth: Int = LivingStillDepthModelLocator.modelWidth,
        modelHeight: Int = LivingStillDepthModelLocator.modelHeight
    ) throws -> LivingStillDepthAspectMapping {
        guard sourceWidth > 0, sourceHeight > 0, modelWidth > 0, modelHeight > 0 else {
            throw LivingStillDepthRenderError.invalidRequest("aspect mapping dimensions must be positive")
        }
        let sx = CGFloat(modelWidth) / CGFloat(sourceWidth)
        let sy = CGFloat(modelHeight) / CGFloat(sourceHeight)
        switch policy {
        case .stretchToFixedModelInput:
            return .init(contentRect: CGRect(x: 0, y: 0, width: modelWidth, height: modelHeight), scaleX: sx, scaleY: sy)
        case .aspectFitEdgeExtended:
            let scale = min(sx, sy)
            let width = CGFloat(sourceWidth) * scale
            let height = CGFloat(sourceHeight) * scale
            return .init(
                contentRect: CGRect(
                    x: (CGFloat(modelWidth) - width) / 2,
                    y: (CGFloat(modelHeight) - height) / 2,
                    width: width,
                    height: height
                ),
                scaleX: scale,
                scaleY: scale
            )
        }
    }
}

struct LivingStillDepthMotionSample: Equatable, Sendable {
    let easedProgress: Double
    let scale: Double
    let panX: Double
    let panY: Double
}

enum LivingStillDepthMotionCurve {
    static func smootherstep(_ progress: Double) -> Double {
        let x = min(1, max(0, progress))
        return x * x * x * (x * (x * 6 - 15) + 10)
    }

    static func sample(progress: Double, request: LivingStillDepthRenderRequest) -> LivingStillDepthMotionSample {
        let eased = smootherstep(progress)
        return .init(
            easedProgress: eased,
            scale: 1 + request.pushIn * eased,
            panX: request.panX * eased,
            panY: request.panY * eased
        )
    }
}

struct LivingStillProcessedDepthField: Equatable, Sendable {
    let width: Int
    let height: Int
    let values: [Float]
    let mean: Float
    let digest: String
}

enum LivingStillDepthFieldProcessor {
    static func process(bits: [UInt16], width: Int, height: Int, smoothing: Double) throws -> LivingStillProcessedDepthField {
        guard width > 0, height > 0, bits.count == width * height else {
            throw LivingStillDepthRenderError.depthOutputInvalid("sample count does not match dimensions")
        }
        guard smoothing.isFinite, (0...1).contains(smoothing) else {
            throw LivingStillDepthRenderError.invalidRequest("depthSmoothing must be between 0 and 1")
        }

        let floating = bits.map { Float(Float16(bitPattern: $0)) }
        let finite = floating.filter(\.isFinite).sorted()
        guard !finite.isEmpty else { throw LivingStillDepthRenderError.depthOutputInvalid("all FP16 samples are non-finite") }
        let low = finite[percentileIndex(count: finite.count, quantile: 0.02)]
        let high = finite[percentileIndex(count: finite.count, quantile: 0.98)]
        let range = high - low

        var normalized = floating.map { value -> Float in
            guard value.isFinite else { return 0.5 }
            guard range > Float.ulpOfOne else { return 0.5 }
            return min(1, max(0, (value - low) / range))
        }

        if smoothing > 0 {
            let radius = max(1, Int((smoothing * 8).rounded(.toNearestOrAwayFromZero)))
            let blurred = boxBlur(normalized, width: width, height: height, radius: radius)
            let blend = Float(smoothing)
            for index in normalized.indices {
                // Preserve strong depth discontinuities while damping texture
                // noise. That avoids turning facial detail and straight lines
                // into a high-frequency displacement map.
                let limitedBlur = min(normalized[index] + 0.18, max(normalized[index] - 0.18, blurred[index]))
                normalized[index] += (limitedBlur - normalized[index]) * blend
            }
        }

        let mean = normalized.reduce(0, +) / Float(normalized.count)
        return .init(
            width: width,
            height: height,
            values: normalized,
            mean: mean,
            digest: canonicalDigest(values: normalized, width: width, height: height)
        )
    }

    static func boxBlur(_ input: [Float], width: Int, height: Int, radius: Int) -> [Float] {
        guard radius > 0, width > 0, height > 0, input.count == width * height else { return input }
        var horizontal = [Float](repeating: 0, count: input.count)
        var output = [Float](repeating: 0, count: input.count)

        for y in 0..<height {
            var prefix = [Double](repeating: 0, count: width + 1)
            for x in 0..<width { prefix[x + 1] = prefix[x] + Double(input[y * width + x]) }
            for x in 0..<width {
                let lower = max(0, x - radius)
                let upper = min(width - 1, x + radius)
                horizontal[y * width + x] = Float((prefix[upper + 1] - prefix[lower]) / Double(upper - lower + 1))
            }
        }

        for x in 0..<width {
            var prefix = [Double](repeating: 0, count: height + 1)
            for y in 0..<height { prefix[y + 1] = prefix[y] + Double(horizontal[y * width + x]) }
            for y in 0..<height {
                let lower = max(0, y - radius)
                let upper = min(height - 1, y + radius)
                output[y * width + x] = Float((prefix[upper + 1] - prefix[lower]) / Double(upper - lower + 1))
            }
        }
        return output
    }

    static func canonicalDigest(values: [Float], width: Int, height: Int) -> String {
        var bytes = Data()
        bytes.reserveCapacity(8 + values.count * 2)
        appendLittleEndian(UInt32(width), to: &bytes)
        appendLittleEndian(UInt32(height), to: &bytes)
        for value in values {
            let quantized = UInt16((Double(min(1, max(0, value))) * 65_535).rounded(.toNearestOrAwayFromZero))
            appendLittleEndian(quantized, to: &bytes)
        }
        return ContentHasher.sha256(bytes)
    }

    static func rawFP16Digest(bits: [UInt16], width: Int, height: Int) -> String {
        var bytes = Data()
        bytes.reserveCapacity(8 + bits.count * 2)
        appendLittleEndian(UInt32(width), to: &bytes)
        appendLittleEndian(UInt32(height), to: &bytes)
        for bitPattern in bits { appendLittleEndian(bitPattern, to: &bytes) }
        return ContentHasher.sha256(bytes)
    }

    static func mean(_ field: LivingStillProcessedDepthField, in contentRect: CGRect) -> Float {
        let lowerX = max(0, Int(contentRect.minX.rounded(.down)))
        let upperX = min(field.width, Int(contentRect.maxX.rounded(.up)))
        let lowerY = max(0, Int(contentRect.minY.rounded(.down)))
        let upperY = min(field.height, Int(contentRect.maxY.rounded(.up)))
        guard lowerX < upperX, lowerY < upperY else { return field.mean }
        var sum: Double = 0
        var count = 0
        for y in lowerY..<upperY {
            for x in lowerX..<upperX {
                sum += Double(field.values[y * field.width + x])
                count += 1
            }
        }
        return count > 0 ? Float(sum / Double(count)) : field.mean
    }

    private static func percentileIndex(count: Int, quantile: Double) -> Int {
        min(count - 1, max(0, Int((Double(count - 1) * quantile).rounded())))
    }

    private static func appendLittleEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }
}

public struct LivingStillDepthRenderer: Sendable {
    public static let defaultOutputDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Movies/FCPCommandConsole/renders/living-still-depth", isDirectory: true)

    private static let warpKernelSource = """
    kernel vec4 livingStillDepthWarp(
        sampler source,
        sampler depth,
        float centerX,
        float centerY,
        float inverseScale,
        float panSampleX,
        float panSampleY,
        float depthSampleX,
        float depthSampleY,
        float depthMean
    ) {
        vec2 outputPoint = destCoord();
        vec2 center = vec2(centerX, centerY);
        vec2 sourcePoint = center + (outputPoint - center) * inverseScale;
        sourcePoint += vec2(panSampleX, panSampleY);
        float relativeDepth = sample(depth, samplerTransform(depth, sourcePoint)).r - depthMean;
        relativeDepth = clamp(relativeDepth, -0.45, 0.45);
        sourcePoint += vec2(depthSampleX, depthSampleY) * relativeDepth;
        return sample(source, samplerTransform(source, sourcePoint));
    }
    """

    public let modelLocator: LivingStillDepthModelLocator

    public init(modelLocator: LivingStillDepthModelLocator = .init()) {
        self.modelLocator = modelLocator
    }

    /// Infer once, then reuse the admitted FP16 depth field for every frame.
    public func render(
        _ request: LivingStillDepthRenderRequest,
        in outputDirectory: URL = LivingStillDepthRenderer.defaultOutputDirectory
    ) throws -> LivingStillDepthRenderArtifact {
        try Task.checkCancellation()
        let frameCount = try Self.validate(request)
        try Task.checkCancellation()
        let source = try Self.readNormalizedSource(request)
        try Task.checkCancellation()
        let modelAdmission = try modelLocator.locate()
        defer { modelAdmission.close() }
        try Task.checkCancellation()
        let modelIdentity = modelAdmission.identity
        let model = try Self.loadModel(admission: modelAdmission)
        try Task.checkCancellation()
        let context = Self.makeContext()
        let mapping = try LivingStillDepthAspectMapping.make(
            sourceWidth: source.width,
            sourceHeight: source.height,
            policy: request.aspectPolicy
        )
        let inputBuffer = try Self.makeModelInput(source.image, mapping: mapping, context: context)
        try Task.checkCancellation()

        // This is intentionally the renderer's sole `prediction` call. The
        // returned 16-bit half field stays alive while normalization, digesting
        // and frame construction are completed; it is never quantized to 8-bit.
        let rawDepth = try Self.predictDepth(model: model, input: inputBuffer)
        try Task.checkCancellation()
        // Core ML may defer reading compiled payloads until prediction. A
        // second full descriptor-anchored verification therefore runs only
        // after the sole inference call has consumed the sealed snapshot.
        try modelAdmission.verifySnapshot()
        try Task.checkCancellation()
        defer { withExtendedLifetime(rawDepth) {} }
        let processedDepth = try LivingStillDepthFieldProcessor.process(
            bits: rawDepth.bits,
            width: rawDepth.width,
            height: rawDepth.height,
            smoothing: request.depthSmoothing
        )
        let rawDepthDigest = LivingStillDepthFieldProcessor.rawFP16Digest(
            bits: rawDepth.bits,
            width: rawDepth.width,
            height: rawDepth.height
        )
        let renderDepthMean = LivingStillDepthFieldProcessor.mean(processedDepth, in: mapping.contentRect)
        try Task.checkCancellation()

        let recipeDigest = try Self.recipeDigest(
            request: request,
            model: modelIdentity,
            depthFieldDigest: processedDepth.digest,
            rawDepthFieldDigest: rawDepthDigest
        )
        try Task.checkCancellation()
        let output = try Self.prepareOutputDirectory(outputDirectory)
        defer { output.handle.closeHandle() }
        let finalName = "living-still-depth-\(recipeDigest.prefix(32)).mov"
        let finalURL = output.url.appendingPathComponent(finalName)
        let runtime = Self.runtimeIdentity(model: modelIdentity)
        let maximumDepthDisplacement = Double(min(request.targetWidth, request.targetHeight)) * 0.016 * request.motionStrength
        let overscanScale = Self.overscanScale(request: request, maximumDepthDisplacement: maximumDepthDisplacement)

        if output.handle.entryExists(finalName) {
            try Task.checkCancellation()
            return try Self.reuseExisting(
                url: finalURL,
                childName: finalName,
                root: output.handle,
                recipeDigest: recipeDigest,
                request: request,
                frameCount: frameCount,
                sourceSHA256: source.sha256,
                model: modelIdentity,
                runtime: runtime,
                processedDepthDigest: processedDepth.digest,
                rawDepthDigest: rawDepthDigest,
                overscanScale: overscanScale,
                maximumDepthDisplacement: maximumDepthDisplacement
            )
        }

        guard let warpKernel = CIKernel(source: Self.warpKernelSource) else {
            throw LivingStillDepthRenderError.kernelUnavailable
        }
        let depthImage = try Self.makeDepthImage(
            processedDepth,
            mapping: mapping,
            sourceWidth: source.width,
            sourceHeight: source.height,
            targetWidth: request.targetWidth,
            targetHeight: request.targetHeight,
            overscanScale: overscanScale
        )
        let overscannedSource = Self.makeOverscannedSource(
            source.image,
            targetWidth: request.targetWidth,
            targetHeight: request.targetHeight,
            overscanScale: overscanScale
        )

        let temporaryName = ".living-still-depth-\(recipeDigest.prefix(16))-\(UUID().uuidString).mov"
        let temporaryURL = output.url.appendingPathComponent(temporaryName)
        defer { output.handle.removeChildRecursively(temporaryName) }
        try Task.checkCancellation()
        try Self.writeMovie(
            to: temporaryURL,
            request: request,
            frameCount: frameCount,
            recipeDigest: recipeDigest,
            source: overscannedSource,
            depth: depthImage,
            depthMean: renderDepthMean,
            maximumDepthDisplacement: maximumDepthDisplacement,
            kernel: warpKernel,
            context: context
        )
        try Task.checkCancellation()
        _ = try Self.verifyMovie(
            at: temporaryURL,
            request: request,
            frameCount: frameCount,
            recipeDigest: recipeDigest,
            observeCancellation: true
        )
        try Task.checkCancellation()

        let staged = try SourceFileHandle.open(vettedRegularFile: temporaryURL)
        defer { staged.closeHandle() }
        guard fsync(staged.descriptor) == 0 else {
            throw LivingStillDepthRenderError.writerFailed("could not sync the staged movie: \(String(cString: strerror(errno)))")
        }
        // Last cancellable point. Once the exclusive rename succeeds, the
        // content-addressed movie is durable and must be returned so its owner
        // can classify it as current or stale honestly.
        try Task.checkCancellation()
        do {
            try output.handle.renameChildExclusively(temporaryName, toChild: finalName, of: output.handle)
            _ = fsync(output.handle.descriptor)
        } catch DirectoryDescriptorError.entryExists {
            return try Self.reuseExisting(
                url: finalURL,
                childName: finalName,
                root: output.handle,
                recipeDigest: recipeDigest,
                request: request,
                frameCount: frameCount,
                sourceSHA256: source.sha256,
                model: modelIdentity,
                runtime: runtime,
                processedDepthDigest: processedDepth.digest,
                rawDepthDigest: rawDepthDigest,
                overscanScale: overscanScale,
                maximumDepthDisplacement: maximumDepthDisplacement
            )
        }

        _ = try Self.verifyMovie(
            at: finalURL,
            request: request,
            frameCount: frameCount,
            recipeDigest: recipeDigest,
            observeCancellation: false
        )
        let movieHash = try output.handle.hashRegularFile(finalName, cancellationCheck: {})
        return Self.artifact(
            url: finalURL,
            movieHash: movieHash,
            recipeDigest: recipeDigest,
            request: request,
            frameCount: frameCount,
            sourceSHA256: source.sha256,
            model: modelIdentity,
            runtime: runtime,
            processedDepthDigest: processedDepth.digest,
            rawDepthDigest: rawDepthDigest,
            overscanScale: overscanScale,
            maximumDepthDisplacement: maximumDepthDisplacement
        )
    }

    static func validate(_ request: LivingStillDepthRenderRequest) throws -> Int {
        guard request.sourceURL.isFileURL, request.sourceURL.path.hasPrefix("/") else {
            throw LivingStillDepthRenderError.invalidRequest("sourceURL must be an absolute file URL")
        }
        guard request.sourceSHA256.count == 64,
              request.sourceSHA256.unicodeScalars.allSatisfy({ (48...57).contains($0.value) || (97...102).contains($0.value) }) else {
            throw LivingStillDepthRenderError.invalidRequest("sourceSHA256 must be 64 lowercase hexadecimal characters")
        }
        guard (64...4096).contains(request.targetWidth), (64...4096).contains(request.targetHeight),
              request.targetWidth.isMultiple(of: 2), request.targetHeight.isMultiple(of: 2),
              request.targetWidth * request.targetHeight <= 8_847_360 else {
            throw LivingStillDepthRenderError.invalidRequest("target dimensions must be even, 64...4096, and no larger than a 4096 x 2160 pixel budget")
        }
        guard (1...60).contains(request.fps), request.durationSeconds.isFinite, request.durationSeconds > 0, request.durationSeconds <= 30 else {
            throw LivingStillDepthRenderError.invalidRequest("fps must be 1...60 and duration must be in (0, 30] seconds")
        }
        let exactFrames = request.durationSeconds * Double(request.fps)
        let roundedFrames = exactFrames.rounded()
        guard abs(exactFrames - roundedFrames) <= 1e-9, roundedFrames >= 1, roundedFrames <= 1_800 else {
            throw LivingStillDepthRenderError.invalidRequest("duration x fps must be an exact whole frame count between 1 and 1800")
        }
        guard request.motionStrength.isFinite, (0...1).contains(request.motionStrength),
              request.pushIn.isFinite, (0...0.15).contains(request.pushIn),
              request.panX.isFinite, (-0.08...0.08).contains(request.panX),
              request.panY.isFinite, (-0.08...0.08).contains(request.panY),
              request.depthSmoothing.isFinite, (0...1).contains(request.depthSmoothing) else {
            throw LivingStillDepthRenderError.invalidRequest("motion parameters exceed their documented bounds")
        }
        guard request.deterministicVersion == LivingStillDepthRenderRequest.currentDeterministicVersion else {
            throw LivingStillDepthRenderError.invalidRequest("unsupported deterministicVersion \(request.deterministicVersion)")
        }
        return Int(roundedFrames)
    }

    private struct NormalizedSource {
        let image: CIImage
        let width: Int
        let height: Int
        let appliedOrientation: UInt32
        let sha256: String
    }

    private struct RawDepthField {
        let width: Int
        let height: Int
        let bits: [UInt16]
    }

    private struct MovieProbe {
        let codecFourCC: String
        let width: Int
        let height: Int
        let frameCount: Int
        let durationSeconds: Double
        let nominalFrameRate: Double
    }

    private struct Recipe: Codable {
        let rendererVersion: String
        let request: LivingStillDepthRenderRequest
        let modelIdentifier: String
        let modelSourceRevision: String
        let modelSourceFileHashes: [LivingStillDepthSourceFileHash]
        let compiledArtifactDigest: String
        let depthFieldDigest: String
        let rawDepthFieldDigest: String
        let codecFourCC: String
        let pixelFormat: String
    }

    private static func readNormalizedSource(_ request: LivingStillDepthRenderRequest) throws -> NormalizedSource {
        let handle: SourceFileHandle
        do { handle = try SourceFileHandle.open(vettedRegularFile: request.sourceURL.standardizedFileURL) }
        catch { throw LivingStillDepthRenderError.sourceUnreadable(request.sourceURL) }
        defer { handle.closeHandle() }
        guard handle.byteCount <= UInt64(Int.max) else { throw LivingStillDepthRenderError.sourceUnreadable(request.sourceURL) }
        var data = Data()
        data.reserveCapacity(Int(handle.byteCount))
        do {
            try handle.stream { buffer in data.append(contentsOf: buffer) }
        } catch {
            throw LivingStillDepthRenderError.sourceUnreadable(request.sourceURL)
        }
        let actualHash = ContentHasher.sha256(data)
        guard actualHash == request.sourceSHA256 else {
            throw LivingStillDepthRenderError.sourceHashMismatch(expected: request.sourceSHA256, actual: actualHash)
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw LivingStillDepthRenderError.sourceUnreadable(request.sourceURL)
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let orientationRaw = (properties?[kCGImagePropertyOrientation] as? UInt32) ?? 1
        let orientation = CGImagePropertyOrientation(rawValue: orientationRaw) ?? .up

        // The only orientation application in the pipeline. Model input and
        // movie frames both derive from this same normalized CIImage.
        let normalized = CIImage(cgImage: cgImage).oriented(orientation)
        let translated = normalized.transformed(by: CGAffineTransform(translationX: -normalized.extent.minX, y: -normalized.extent.minY))
        let width = Int(translated.extent.width.rounded())
        let height = Int(translated.extent.height.rounded())
        guard width > 0, height > 0 else { throw LivingStillDepthRenderError.sourceUnreadable(request.sourceURL) }
        return .init(image: translated, width: width, height: height, appliedOrientation: orientationRaw, sha256: actualHash)
    }

    private static func loadModel(admission: LivingStillDepthModelAdmission) throws -> MLModel {
        try admission.verifySnapshot()
        let identity = admission.identity
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuAndGPU
        let model: MLModel
        do { model = try MLModel(contentsOf: admission.compiledModelURL, configuration: configuration) }
        catch { throw LivingStillDepthRenderError.modelLoadFailed(error.localizedDescription) }
        try admission.verifySnapshot()
        guard let input = model.modelDescription.inputDescriptionsByName["image"]?.imageConstraint,
              input.pixelsWide == identity.inputWidth, input.pixelsHigh == identity.inputHeight,
              let output = model.modelDescription.outputDescriptionsByName["depth"]?.imageConstraint,
              output.pixelsWide == identity.outputWidth, output.pixelsHigh == identity.outputHeight else {
            throw LivingStillDepthRenderError.modelMetadataInvalid("runtime constraints are not fixed 518 x 392 image -> FP16 depth")
        }
        return model
    }

    private static func makeContext() -> CIContext {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        return CIContext(options: [
            .workingColorSpace: colorSpace,
            .outputColorSpace: colorSpace,
            .highQualityDownsample: true,
            .cacheIntermediates: true
        ])
    }

    private static func makeModelInput(_ image: CIImage, mapping: LivingStillDepthAspectMapping, context: CIContext) throws -> CVPixelBuffer {
        let modelRect = CGRect(x: 0, y: 0, width: LivingStillDepthModelLocator.modelWidth, height: LivingStillDepthModelLocator.modelHeight)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: mapping.scaleX, y: mapping.scaleY))
            .transformed(by: CGAffineTransform(translationX: mapping.contentRect.minX, y: mapping.contentRect.minY))
        let placed: CIImage
        if mapping.contentRect.equalTo(modelRect) {
            placed = scaled.cropped(to: modelRect)
        } else {
            placed = scaled.clampedToExtent().cropped(to: modelRect)
        }
        let buffer = try makePixelBuffer(
            width: LivingStillDepthModelLocator.modelWidth,
            height: LivingStillDepthModelLocator.modelHeight,
            pixelFormat: kCVPixelFormatType_32ARGB
        )
        context.render(placed, to: buffer, bounds: modelRect, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        return buffer
    }

    private static func predictDepth(model: MLModel, input: CVPixelBuffer) throws -> RawDepthField {
        try Task.checkCancellation()
        let provider: MLDictionaryFeatureProvider
        do { provider = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: input)]) }
        catch { throw LivingStillDepthRenderError.modelPredictionFailed(error.localizedDescription) }
        let output: MLFeatureProvider
        do { output = try model.prediction(from: provider) }
        catch { throw LivingStillDepthRenderError.modelPredictionFailed(error.localizedDescription) }
        try Task.checkCancellation()
        guard let buffer = output.featureValue(for: "depth")?.imageBufferValue else {
            throw LivingStillDepthRenderError.depthOutputInvalid("missing `depth` pixel buffer")
        }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        guard width == LivingStillDepthModelLocator.modelWidth, height == LivingStillDepthModelLocator.modelHeight,
              CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_OneComponent16Half else {
            throw LivingStillDepthRenderError.depthOutputInvalid("expected 518 x 392 OneComponent16Half output")
        }
        guard CVPixelBufferLockBaseAddress(buffer, .readOnly) == kCVReturnSuccess,
              let base = CVPixelBufferGetBaseAddress(buffer) else {
            throw LivingStillDepthRenderError.depthOutputInvalid("could not lock FP16 output")
        }
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        var bits = [UInt16](repeating: 0, count: width * height)
        for y in 0..<height {
            try Task.checkCancellation()
            let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: UInt16.self)
            for x in 0..<width { bits[y * width + x] = row[x] }
        }
        return .init(width: width, height: height, bits: bits)
    }

    private static func makeDepthImage(
        _ field: LivingStillProcessedDepthField,
        mapping: LivingStillDepthAspectMapping,
        sourceWidth: Int,
        sourceHeight: Int,
        targetWidth: Int,
        targetHeight: Int,
        overscanScale: Double
    ) throws -> CIImage {
        let buffer = try makePixelBuffer(width: field.width, height: field.height, pixelFormat: kCVPixelFormatType_OneComponent32Float)
        guard CVPixelBufferLockBaseAddress(buffer, []) == kCVReturnSuccess,
              let base = CVPixelBufferGetBaseAddress(buffer) else {
            throw LivingStillDepthRenderError.depthOutputInvalid("could not allocate the smoothed float depth field")
        }
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        for y in 0..<field.height {
            let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: Float.self)
            for x in 0..<field.width { row[x] = field.values[y * field.width + x] }
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])

        var image = CIImage(cvPixelBuffer: buffer)
        if mapping.contentRect.width != CGFloat(field.width) || mapping.contentRect.height != CGFloat(field.height) {
            image = image.cropped(to: mapping.contentRect)
                .transformed(by: CGAffineTransform(translationX: -mapping.contentRect.minX, y: -mapping.contentRect.minY))
        }
        // Undo model placement into normalized-source coordinates first, then
        // apply the exact same aspect-fill and overscan transform as the source
        // pixels. This keeps depth attached to geometry when source and target
        // aspect ratios differ.
        let scaleX = CGFloat(sourceWidth) / image.extent.width
        let scaleY = CGFloat(sourceHeight) / image.extent.height
        image = image.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        return makeOverscannedSource(
            image,
            targetWidth: targetWidth,
            targetHeight: targetHeight,
            overscanScale: overscanScale
        )
    }

    private static func makeOverscannedSource(_ image: CIImage, targetWidth: Int, targetHeight: Int, overscanScale: Double) -> CIImage {
        let scale = max(CGFloat(targetWidth) / image.extent.width, CGFloat(targetHeight) / image.extent.height) * CGFloat(overscanScale)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return scaled.transformed(by: CGAffineTransform(
            translationX: (CGFloat(targetWidth) - scaled.extent.width) / 2 - scaled.extent.minX,
            y: (CGFloat(targetHeight) - scaled.extent.height) / 2 - scaled.extent.minY
        ))
    }

    private static func writeMovie(
        to url: URL,
        request: LivingStillDepthRenderRequest,
        frameCount: Int,
        recipeDigest: String,
        source: CIImage,
        depth: CIImage,
        depthMean: Float,
        maximumDepthDisplacement: Double,
        kernel: CIKernel,
        context: CIContext
    ) throws {
        let writer: AVAssetWriter
        do { writer = try AVAssetWriter(outputURL: url, fileType: .mov) }
        catch { throw LivingStillDepthRenderError.writerFailed(error.localizedDescription) }

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.proRes422HQ,
            AVVideoWidthKey: request.targetWidth,
            AVVideoHeightKey: request.targetHeight,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
            ],
            AVVideoCompressionPropertiesKey: [
                AVVideoExpectedSourceFrameRateKey: request.fps
            ]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        guard writer.canAdd(input) else { throw LivingStillDepthRenderError.writerFailed("AVAssetWriter rejected ProRes 422 HQ settings") }
        writer.add(input)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: request.targetWidth,
                kCVPixelBufferHeightKey as String: request.targetHeight,
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ]
        )
        let metadata = AVMutableMetadataItem()
        metadata.identifier = .quickTimeMetadataComment
        metadata.value = "FrameSmith living-still-depth recipe \(recipeDigest)" as NSString
        metadata.dataType = kCMMetadataBaseDataType_UTF8 as String
        writer.metadata = [metadata]

        guard writer.startWriting() else { throw LivingStillDepthRenderError.writerFailed(writer.error?.localizedDescription ?? "startWriting failed") }
        defer {
            if writer.status == .writing { writer.cancelWriting() }
        }
        writer.startSession(atSourceTime: .zero)
        guard let pool = adaptor.pixelBufferPool else {
            writer.cancelWriting()
            throw LivingStillDepthRenderError.writerFailed("pixel buffer pool was not created")
        }

        let targetRect = CGRect(x: 0, y: 0, width: request.targetWidth, height: request.targetHeight)
        let fallbackAngle = Double(request.seed % 3_600) / 3_600 * 2 * Double.pi
        let panLength = hypot(request.panX, request.panY)
        let directionX = panLength > 1e-9 ? request.panX / panLength : cos(fallbackAngle)
        let directionY = panLength > 1e-9 ? request.panY / panLength : sin(fallbackAngle)
        let colorSpace = CGColorSpace(name: CGColorSpace.itur_709) ?? CGColorSpace(name: CGColorSpace.sRGB)!

        for frameIndex in 0..<frameCount {
            try Task.checkCancellation()
            let progress = frameCount == 1 ? 0 : Double(frameIndex) / Double(frameCount - 1)
            let motion = LivingStillDepthMotionCurve.sample(progress: progress, request: request)
            let roi: CIKernelROICallback = { inputIndex, _ in inputIndex == 0 ? source.extent : depth.extent }
            guard let warped = kernel.apply(
                extent: targetRect,
                roiCallback: roi,
                arguments: [
                    source,
                    depth,
                    NSNumber(value: Double(request.targetWidth) / 2),
                    NSNumber(value: Double(request.targetHeight) / 2),
                    NSNumber(value: 1 / motion.scale),
                    NSNumber(value: -motion.panX * Double(request.targetWidth)),
                    NSNumber(value: -motion.panY * Double(request.targetHeight)),
                    NSNumber(value: -directionX * maximumDepthDisplacement * motion.easedProgress),
                    NSNumber(value: -directionY * maximumDepthDisplacement * motion.easedProgress),
                    NSNumber(value: depthMean)
                ]
            ) else {
                writer.cancelWriting()
                throw LivingStillDepthRenderError.kernelUnavailable
            }
            // ProRes 422 has no alpha channel. Compositing here also makes the
            // contract explicit for transparent source stills.
            let opaque = warped.composited(over: CIImage(color: .black).cropped(to: targetRect)).cropped(to: targetRect)

            let deadline = Date().addingTimeInterval(30)
            while !input.isReadyForMoreMediaData {
                try Task.checkCancellation()
                if writer.status == .failed {
                    throw LivingStillDepthRenderError.writerFailed(writer.error?.localizedDescription ?? "writer failed while waiting for input")
                }
                guard Date() < deadline else {
                    writer.cancelWriting()
                    throw LivingStillDepthRenderError.writerFailed("timed out waiting for the ProRes encoder")
                }
                Thread.sleep(forTimeInterval: 0.001)
            }

            var pixelBuffer: CVPixelBuffer?
            let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
            guard status == kCVReturnSuccess, let pixelBuffer else {
                writer.cancelWriting()
                throw LivingStillDepthRenderError.writerFailed("could not allocate output frame (CoreVideo \(status))")
            }
            context.render(opaque, to: pixelBuffer, bounds: targetRect, colorSpace: colorSpace)
            try Task.checkCancellation()
            let presentationTime = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(request.fps))
            guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
                writer.cancelWriting()
                throw LivingStillDepthRenderError.writerFailed(writer.error?.localizedDescription ?? "could not append frame \(frameIndex)")
            }
        }

        let endTime = CMTime(value: CMTimeValue(frameCount), timescale: CMTimeScale(request.fps))
        input.markAsFinished()
        writer.endSession(atSourceTime: endTime)
        let finished = DispatchSemaphore(value: 0)
        writer.finishWriting { finished.signal() }
        let deadline = Date().addingTimeInterval(60)
        while finished.wait(timeout: .now() + 0.1) != .success {
            do { try Task.checkCancellation() }
            catch {
                writer.cancelWriting()
                throw error
            }
            guard Date() < deadline else {
                writer.cancelWriting()
                throw LivingStillDepthRenderError.writerFailed("timed out finalizing the ProRes movie")
            }
        }
        guard writer.status == .completed else {
            throw LivingStillDepthRenderError.writerFailed(writer.error?.localizedDescription ?? "finishWriting did not complete")
        }
    }

    private static func verifyMovie(
        at url: URL,
        request: LivingStillDepthRenderRequest,
        frameCount: Int,
        recipeDigest: String,
        observeCancellation: Bool
    ) throws -> MovieProbe {
        if observeCancellation { try Task.checkCancellation() }
        let asset = AVURLAsset(url: url)
        let videoTracks = asset.tracks(withMediaType: .video)
        let audioTracks = asset.tracks(withMediaType: .audio)
        guard videoTracks.count == 1, audioTracks.isEmpty, let track = videoTracks.first else {
            throw LivingStillDepthRenderError.movieVerificationFailed("artifact must contain exactly one video track and no audio")
        }
        let metadataComments = AVMetadataItem.metadataItems(from: asset.metadata, filteredByIdentifier: .quickTimeMetadataComment)
            .compactMap(\.stringValue)
        guard metadataComments.contains("FrameSmith living-still-depth recipe \(recipeDigest)") else {
            throw LivingStillDepthRenderError.movieVerificationFailed("recipe metadata is missing or does not match")
        }
        guard let rawFormat = track.formatDescriptions.first else {
            throw LivingStillDepthRenderError.movieVerificationFailed("video format description is missing")
        }
        let format = rawFormat as! CMFormatDescription
        let subtype = CMFormatDescriptionGetMediaSubType(format)
        let codecFourCC = fourCC(subtype)
        guard subtype == kCMVideoCodecType_AppleProRes422HQ else {
            throw LivingStillDepthRenderError.movieVerificationFailed("codec is \(codecFourCC), expected ProRes 422 HQ apch")
        }
        let size = track.naturalSize
        let width = Int(abs(size.width).rounded())
        let height = Int(abs(size.height).rounded())
        guard width == request.targetWidth, height == request.targetHeight else {
            throw LivingStillDepthRenderError.movieVerificationFailed("dimensions are \(width)x\(height), expected \(request.targetWidth)x\(request.targetHeight)")
        }

        let reader: AVAssetReader
        do { reader = try AVAssetReader(asset: asset) }
        catch { throw LivingStillDepthRenderError.movieVerificationFailed(error.localizedDescription) }
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw LivingStillDepthRenderError.movieVerificationFailed("reader rejected the video track") }
        reader.add(output)
        guard reader.startReading() else {
            throw LivingStillDepthRenderError.movieVerificationFailed(reader.error?.localizedDescription ?? "reader did not start")
        }
        var countedFrames = 0
        while let sample = output.copyNextSampleBuffer() {
            if observeCancellation { try Task.checkCancellation() }
            countedFrames += CMSampleBufferGetNumSamples(sample)
        }
        guard reader.status == .completed else {
            throw LivingStillDepthRenderError.movieVerificationFailed(reader.error?.localizedDescription ?? "reader did not finish")
        }
        guard countedFrames == frameCount else {
            throw LivingStillDepthRenderError.movieVerificationFailed("frame count is \(countedFrames), expected \(frameCount)")
        }
        let duration = asset.duration.seconds
        let expectedDuration = Double(frameCount) / Double(request.fps)
        guard duration.isFinite, abs(duration - expectedDuration) <= 0.000_001 else {
            throw LivingStillDepthRenderError.movieVerificationFailed("duration is \(duration), expected \(expectedDuration)")
        }
        let nominalFrameRate = Double(track.nominalFrameRate)
        guard nominalFrameRate.isFinite, abs(nominalFrameRate - Double(request.fps)) <= 0.000_001 else {
            throw LivingStillDepthRenderError.movieVerificationFailed("frame rate is \(nominalFrameRate), expected \(request.fps)")
        }
        return .init(
            codecFourCC: codecFourCC,
            width: width,
            height: height,
            frameCount: countedFrames,
            durationSeconds: duration,
            nominalFrameRate: nominalFrameRate
        )
    }

    private static func reuseExisting(
        url: URL,
        childName: String,
        root: DirectoryHandle,
        recipeDigest: String,
        request: LivingStillDepthRenderRequest,
        frameCount: Int,
        sourceSHA256: String,
        model: LivingStillDepthModelIdentity,
        runtime: LivingStillDepthRuntimeIdentity,
        processedDepthDigest: String,
        rawDepthDigest: String,
        overscanScale: Double,
        maximumDepthDisplacement: Double
    ) throws -> LivingStillDepthRenderArtifact {
        do {
            _ = try root.regularFileByteCount(childName)
            _ = try verifyMovie(
                at: url,
                request: request,
                frameCount: frameCount,
                recipeDigest: recipeDigest,
                observeCancellation: false
            )
            let hash = try root.hashRegularFile(childName, cancellationCheck: {})
            return artifact(
                url: url,
                movieHash: hash,
                recipeDigest: recipeDigest,
                request: request,
                frameCount: frameCount,
                sourceSHA256: sourceSHA256,
                model: model,
                runtime: runtime,
                processedDepthDigest: processedDepthDigest,
                rawDepthDigest: rawDepthDigest,
                overscanScale: overscanScale,
                maximumDepthDisplacement: maximumDepthDisplacement
            )
        } catch {
            throw LivingStillDepthRenderError.destinationCollision(url)
        }
    }

    private static func artifact(
        url: URL,
        movieHash: String,
        recipeDigest: String,
        request: LivingStillDepthRenderRequest,
        frameCount: Int,
        sourceSHA256: String,
        model: LivingStillDepthModelIdentity,
        runtime: LivingStillDepthRuntimeIdentity,
        processedDepthDigest: String,
        rawDepthDigest: String,
        overscanScale: Double,
        maximumDepthDisplacement: Double
    ) -> LivingStillDepthRenderArtifact {
        .init(
            movieURL: url,
            movieSHA256: movieHash,
            recipeDigest: recipeDigest,
            sourceSHA256: sourceSHA256,
            model: model,
            runtime: runtime,
            depthFieldDigest: processedDepthDigest,
            rawDepthFieldDigest: rawDepthDigest,
            codec: "prores",
            codecProfile: "HQ",
            codecFourCC: "apch",
            pixelFormat: "yuv422p10le",
            width: request.targetWidth,
            height: request.targetHeight,
            fps: request.fps,
            frameCount: frameCount,
            durationSeconds: Double(frameCount) / Double(request.fps),
            videoOnly: true,
            aspectPolicy: request.aspectPolicy,
            overscanScale: overscanScale,
            maximumDepthDisplacementPixels: maximumDepthDisplacement
        )
    }

    private static func recipeDigest(
        request: LivingStillDepthRenderRequest,
        model: LivingStillDepthModelIdentity,
        depthFieldDigest: String,
        rawDepthFieldDigest: String
    ) throws -> String {
        try StablePlanHasher.hashJSON(Recipe(
            rendererVersion: LivingStillDepthRenderRequest.currentDeterministicVersion,
            request: request,
            modelIdentifier: model.identifier,
            modelSourceRevision: model.sourceRevision,
            modelSourceFileHashes: model.sourceFileHashes,
            compiledArtifactDigest: model.compiledArtifactDigest,
            depthFieldDigest: depthFieldDigest,
            rawDepthFieldDigest: rawDepthFieldDigest,
            codecFourCC: "apch",
            pixelFormat: "yuv422p10le"
        ))
    }

    private static func prepareOutputDirectory(_ requested: URL) throws -> (url: URL, handle: DirectoryHandle) {
        guard requested.isFileURL, requested.path.hasPrefix("/") else {
            throw LivingStillDepthRenderError.outputDirectoryUnsafe(requested)
        }
        let standardized = requested.standardizedFileURL
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        guard standardized.path != "/", standardized.path != home, standardized.path.count > 4 else {
            throw LivingStillDepthRenderError.outputDirectoryUnsafe(requested)
        }
        do { try FileManager.default.createDirectory(at: standardized, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]) }
        catch { throw LivingStillDepthRenderError.outputDirectoryUnsafe(requested) }
        var status = stat()
        guard lstat(standardized.path, &status) == 0, (status.st_mode & S_IFMT) == S_IFDIR else {
            throw LivingStillDepthRenderError.outputDirectoryUnsafe(requested)
        }
        do { return (standardized, try DirectoryHandle.open(vettedDirectory: standardized)) }
        catch { throw LivingStillDepthRenderError.outputDirectoryUnsafe(requested) }
    }

    private static func makePixelBuffer(width: Int, height: Int, pixelFormat: OSType) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, pixelFormat, attributes as CFDictionary, &buffer)
        guard status == kCVReturnSuccess, let buffer else {
            throw LivingStillDepthRenderError.depthOutputInvalid("could not allocate pixel buffer (CoreVideo \(status))")
        }
        return buffer
    }

    private static func overscanScale(request: LivingStillDepthRenderRequest, maximumDepthDisplacement: Double) -> Double {
        let horizontalMargin = abs(request.panX) * Double(request.targetWidth) + maximumDepthDisplacement + 2
        let verticalMargin = abs(request.panY) * Double(request.targetHeight) + maximumDepthDisplacement + 2
        let horizontalScale = 1 + 2 * horizontalMargin / Double(request.targetWidth)
        let verticalScale = 1 + 2 * verticalMargin / Double(request.targetHeight)
        return max(1.08, max(horizontalScale, verticalScale) + 0.02)
    }

    private static func runtimeIdentity(model: LivingStillDepthModelIdentity) -> LivingStillDepthRuntimeIdentity {
        #if arch(arm64)
        let architecture = "arm64"
        #elseif arch(x86_64)
        let architecture = "x86_64"
        #else
        let architecture = "unknown"
        #endif
        return .init(
            operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
            architecture: architecture,
            coreMLComputeUnits: "cpuAndGPU",
            compilerCacheIdentity: "coremlcompiler-tree-sha256:\(model.compiledArtifactDigest)"
        )
    }

    private static func fourCC(_ value: FourCharCode) -> String {
        let bytes: [UInt8] = [
            UInt8((value >> 24) & 0xff), UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff), UInt8(value & 0xff)
        ]
        return String(bytes: bytes, encoding: .macOSRoman) ?? String(format: "0x%08x", value)
    }
}
