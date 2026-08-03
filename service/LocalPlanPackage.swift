import Darwin
import Foundation

public struct LocalPlanPackage: Codable, Equatable, Sendable {
    public let operationID: UUID
    public let url: URL
    public let manifest: LocalPlanPackageManifest

    public init(operationID: UUID, url: URL, manifest: LocalPlanPackageManifest) {
        self.operationID = operationID
        self.url = url
        self.manifest = manifest
    }
}

public struct LocalPlanPackageManifest: Codable, Equatable, Sendable {
    public let formatVersion: String
    public let schemaVersion: String
    public let operationID: UUID
    public let effectID: EffectID
    public let representation: RepresentationClass
    public let containsFCPXML: Bool
    public let containsEffectRender: Bool
    public let finalCutCompatibility: String
    public let files: [LocalPlanPackageFile]
    public let media: [LocalPlanPackageMedia]

    public init(formatVersion: String = "1.0", schemaVersion: String, operationID: UUID, effectID: EffectID, representation: RepresentationClass, containsFCPXML: Bool = false, containsEffectRender: Bool = false, finalCutCompatibility: String = "unverified", files: [LocalPlanPackageFile], media: [LocalPlanPackageMedia]) {
        self.formatVersion = formatVersion
        self.schemaVersion = schemaVersion
        self.operationID = operationID
        self.effectID = effectID
        self.representation = representation
        self.containsFCPXML = containsFCPXML
        self.containsEffectRender = containsEffectRender
        self.finalCutCompatibility = finalCutCompatibility
        self.files = files
        self.media = media
    }
}

public struct LocalPlanPackageFile: Codable, Equatable, Sendable {
    public let relativePath: String
    public let sha256: String
    public let byteCount: UInt64
    public let kind: String

    public init(relativePath: String, sha256: String, byteCount: UInt64, kind: String) {
        self.relativePath = relativePath
        self.sha256 = sha256
        self.byteCount = byteCount
        self.kind = kind
    }
}

public struct LocalPlanPackageMedia: Codable, Equatable, Sendable {
    public let role: LocalMediaRole
    public let kind: LocalMediaKind
    public let relativePath: String
    public let sourceSHA256: String
    public let byteCount: UInt64

    public init(role: LocalMediaRole, kind: LocalMediaKind, relativePath: String, sourceSHA256: String, byteCount: UInt64) {
        self.role = role
        self.kind = kind
        self.relativePath = relativePath
        self.sourceSHA256 = sourceSHA256
        self.byteCount = byteCount
    }
}

public struct LocalPlanPackageProvenance: Codable, Equatable, Sendable {
    public let createdAt: Date
    public let operationID: UUID
    public let selectionTokenID: String
    public let selectionRevision: String
    public let originalRequest: String
    public let parameters: [String: ParameterValue]
    public let sources: [LocalPlanPackageSourceProvenance]

    public init(createdAt: Date = Date(), operationID: UUID, selectionTokenID: String, selectionRevision: String, originalRequest: String, parameters: [String: ParameterValue], sources: [LocalPlanPackageSourceProvenance]) {
        self.createdAt = createdAt
        self.operationID = operationID
        self.selectionTokenID = selectionTokenID
        self.selectionRevision = selectionRevision
        self.originalRequest = originalRequest
        self.parameters = parameters
        self.sources = sources
    }
}

public struct LocalPlanPackageSourceProvenance: Codable, Equatable, Sendable {
    public let role: LocalMediaRole
    public let canonicalPath: String
    public let sha256: String
    public let kind: LocalMediaKind

    public init(role: LocalMediaRole, canonicalPath: String, sha256: String, kind: LocalMediaKind) {
        self.role = role
        self.canonicalPath = canonicalPath
        self.sha256 = sha256
        self.kind = kind
    }
}

public enum LocalPlanPackageError: Error, LocalizedError, Equatable, Sendable {
    case outputRootUnsafe(URL)
    case outputRootSymlink(URL)
    case outputRootForbidden(URL)
    case targetExists(URL)
    case invalidAdmission
    case selectionDoesNotMatchPlan
    case sourceStale(URL)
    case sourceNotRegular(URL)
    case copiedMediaHashMismatch(URL)
    case sourceChangedDuringCopy(URL)
    case ioFailure(String)

    public var errorDescription: String? {
        switch self {
        case .outputRootUnsafe(let url): return "Local package output root is unsafe or broad: \(url.path)"
        case .outputRootSymlink(let url): return "Local package output root cannot be a symlink: \(url.path)"
        case .outputRootForbidden(let url): return "Local package output root cannot be a Final Cut path: \(url.path)"
        case .targetExists(let url): return "Local package operation target already exists: \(url.path)"
        case .invalidAdmission: return "Only a current schema 2.0 plan can be packaged"
        case .selectionDoesNotMatchPlan: return "Admitted local-media slots do not exactly match the plan identities"
        case .sourceStale(let url): return "Source no longer matches its admitted hash: \(url.path)"
        case .sourceNotRegular(let url): return "Source is no longer a canonical regular local file: \(url.path)"
        case .copiedMediaHashMismatch(let url): return "Copied media hash does not match source: \(url.path)"
        case .sourceChangedDuringCopy(let url): return "Source changed while package was built: \(url.path)"
        case .ioFailure(let reason): return "Unable to build local plan package: \(reason)"
        }
    }
}

/// Builds a payload-neutral archival package. The only media mutation is a
/// byte-for-byte copy into an owned staged package; source media is never
/// rendered, edited, renamed, or deleted.
public struct LocalPlanPackageBuilder: Sendable {
    public let outputRoot: URL
    public let capabilityGate: CapabilityGate

    public init(outputRoot: URL = LocalPlanPackageBuilder.defaultOutputRoot, capabilityGate: CapabilityGate = CapabilityGate()) {
        self.outputRoot = outputRoot
        self.capabilityGate = capabilityGate
    }

    public static var defaultOutputRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies/FCPCommandConsole/exports/local-plan-packages", isDirectory: true)
    }

    public func build(_ result: LocalMediaPlanningResult) throws -> LocalPlanPackage {
        try build(plan: result.plan, admission: result.admission, selection: result.selection)
    }

    public func build(plan: EffectPlan, admission: EffectPlanAdmissionResult, selection: LocalMediaSelection) throws -> LocalPlanPackage {
        try Task.checkCancellation()
        guard case .current(let admittedPlan) = admission, admittedPlan == plan, plan.schemaVersion == SchemaVersion.v2_0.rawValue else {
            throw LocalPlanPackageError.invalidAdmission
        }
        try capabilityGate.require(admission, capability: .inertPayloadNeutralPackage)
        try validate(selection: selection, matches: plan)
        let root = try validatedOutputRoot()
        let target = root.appendingPathComponent(plan.operationID.uuidString, isDirectory: true)
        guard !FileManager.default.fileExists(atPath: target.path) else { throw LocalPlanPackageError.targetExists(target) }

        let staging = root.appendingPathComponent(".\(plan.operationID.uuidString).staging.\(UUID().uuidString)", isDirectory: true)
        var published = false
        defer {
            if !published { try? FileManager.default.removeItem(at: staging) }
        }
        do {
            try FileManager.default.createDirectory(at: staging.appendingPathComponent("Media", isDirectory: true), withIntermediateDirectories: true)
            let effectData = try encoded(plan)
            try effectData.write(to: staging.appendingPathComponent("EffectPlan.json"), options: .atomic)

            var mediaEntries: [LocalPlanPackageMedia] = []
            var fileEntries = [try fileEntry(root: staging, relativePath: "EffectPlan.json", kind: "effect_plan")]
            for slot in selection.slots {
                try Task.checkCancellation()
                let source = try currentSource(for: slot)
                let before = try ContentHasher.sha256File(source)
                guard before == slot.media.sha256 else { throw LocalPlanPackageError.sourceStale(source) }
                let relativePath = "Media/\(slot.role.rawValue)-\(sanitizedBasename(source.lastPathComponent))"
                let destination = staging.appendingPathComponent(relativePath)
                try FileManager.default.copyItem(at: source, to: destination)
                let copiedHash = try ContentHasher.sha256File(destination)
                guard copiedHash == before else { throw LocalPlanPackageError.copiedMediaHashMismatch(destination) }
                try Task.checkCancellation()
                let after = try ContentHasher.sha256File(source)
                guard after == before else { throw LocalPlanPackageError.sourceChangedDuringCopy(source) }
                let bytes = try byteCount(destination)
                mediaEntries.append(LocalPlanPackageMedia(role: slot.role, kind: slot.media.kind, relativePath: relativePath, sourceSHA256: before, byteCount: bytes))
                fileEntries.append(try fileEntry(root: staging, relativePath: relativePath, kind: "media"))
            }

            let provenance = LocalPlanPackageProvenance(
                operationID: plan.operationID,
                selectionTokenID: plan.selectionToken.tokenID,
                selectionRevision: plan.selectionToken.revision,
                originalRequest: plan.originalRequest,
                parameters: plan.parameters,
                sources: selection.slots.map { LocalPlanPackageSourceProvenance(role: $0.role, canonicalPath: $0.media.canonicalPath, sha256: $0.media.sha256, kind: $0.media.kind) }
            )
            try encoded(provenance).write(to: staging.appendingPathComponent("Provenance.json"), options: .atomic)
            fileEntries.append(try fileEntry(root: staging, relativePath: "Provenance.json", kind: "provenance"))

            let readme = """
            FCPCommandConsole local plan package

            This is an inert local plan and source-media package. It is not an importable Final Cut package, does not contain FCPXML, and does not contain an effect render. Final Cut compatibility and editability are unverified.
            """
            try Data(readme.utf8).write(to: staging.appendingPathComponent("README.txt"), options: .atomic)
            fileEntries.append(try fileEntry(root: staging, relativePath: "README.txt", kind: "readme"))

            let manifest = LocalPlanPackageManifest(
                schemaVersion: plan.schemaVersion,
                operationID: plan.operationID,
                effectID: plan.effectID,
                representation: plan.representation,
                files: fileEntries.sorted { $0.relativePath < $1.relativePath },
                media: mediaEntries.sorted { $0.relativePath < $1.relativePath }
            )
            try encoded(manifest).write(to: staging.appendingPathComponent("Manifest.json"), options: .atomic)
            try Task.checkCancellation()
            try FileManager.default.moveItem(at: staging, to: target)
            published = true
            return LocalPlanPackage(operationID: plan.operationID, url: target, manifest: manifest)
        } catch let error as LocalPlanPackageError {
            throw error
        } catch {
            throw LocalPlanPackageError.ioFailure(error.localizedDescription)
        }
    }

    private func validate(selection: LocalMediaSelection, matches plan: EffectPlan) throws {
        guard selection.token == plan.selectionToken,
              selection.slots.map(\.media.sourceIdentity) == plan.selectionToken.sourceIdentities,
              selection.slots.map(\.media.itemID) == plan.selectionToken.clipIDs else {
            throw LocalPlanPackageError.selectionDoesNotMatchPlan
        }
    }

    private func validatedOutputRoot() throws -> URL {
        let lexical = outputRoot.standardizedFileURL
        guard outputRoot.isFileURL, outputRoot.path.hasPrefix("/"), lexical.path == outputRoot.path,
              lexical.path != "/", lexical.path != FileManager.default.homeDirectoryForCurrentUser.path,
              !lexical.path.hasPrefix("/dev/"), !lexical.path.hasPrefix("/System/"),
              !lexical.path.split(separator: "/").contains("..") else {
            throw LocalPlanPackageError.outputRootUnsafe(outputRoot)
        }
        guard !LocalMediaAdmission.isForbiddenFinalCutPath(lexical) else { throw LocalPlanPackageError.outputRootForbidden(lexical) }
        if FileManager.default.fileExists(atPath: lexical.path) {
            let values = try lexical.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
            if values.isSymbolicLink == true { throw LocalPlanPackageError.outputRootSymlink(lexical) }
            guard values.isDirectory == true else { throw LocalPlanPackageError.outputRootUnsafe(lexical) }
        } else {
            try FileManager.default.createDirectory(at: lexical, withIntermediateDirectories: true)
        }
        let canonical = lexical.resolvingSymlinksInPath().standardizedFileURL
        guard canonical.path == lexical.path else { throw LocalPlanPackageError.outputRootSymlink(lexical) }
        return canonical
    }

    private func currentSource(for slot: LocalMediaSlot) throws -> URL {
        let url = URL(fileURLWithPath: slot.media.canonicalPath)
        do {
            let canonical = try LocalMediaAdmission.canonicalRegularFile(from: url)
            guard canonical.path == slot.media.canonicalPath else { throw LocalPlanPackageError.sourceNotRegular(url) }
            return canonical
        } catch {
            throw LocalPlanPackageError.sourceNotRegular(url)
        }
    }

    private func fileEntry(root: URL, relativePath: String, kind: String) throws -> LocalPlanPackageFile {
        let url = root.appendingPathComponent(relativePath)
        return LocalPlanPackageFile(relativePath: relativePath, sha256: try ContentHasher.sha256File(url), byteCount: try byteCount(url), kind: kind)
    }

    private func byteCount(_ url: URL) throws -> UInt64 {
        guard let number = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, number >= 0 else {
            throw LocalPlanPackageError.ioFailure("missing file size for \(url.lastPathComponent)")
        }
        return UInt64(number)
    }

    private func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }

    private func sanitizedBasename(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let sanitized = String(value.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "_" })
        let nonEmpty = sanitized.isEmpty ? "media" : sanitized
        return nonEmpty == "." || nonEmpty == ".." ? "media" : nonEmpty
    }
}
