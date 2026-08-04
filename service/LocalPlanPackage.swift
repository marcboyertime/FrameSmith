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
    case inputsStale(LocalMediaPlanStaleness)
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
        case .inputsStale(let staleness): return staleness.reason
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

    /// Packages a plan only while it still describes the operator's current
    /// request. Re-hashing the sources catches a source edited on disk, but a
    /// retyped command, a moved target point, or a newly filled role slot
    /// leaves every hash intact — so the inputs are compared directly, here,
    /// rather than being left to whichever caller remembers to check.
    public func build(_ result: LocalMediaPlanningResult, currentInputs: LocalMediaPlanInputs) throws -> LocalPlanPackage {
        if let staleness = result.staleness(against: currentInputs) {
            throw LocalPlanPackageError.inputsStale(staleness)
        }
        return try build(result)
    }

    public func build(plan: EffectPlan, admission: EffectPlanAdmissionResult, selection: LocalMediaSelection) throws -> LocalPlanPackage {
        try Task.checkCancellation()
        guard case .current(let admittedPlan) = admission, admittedPlan == plan, plan.schemaVersion == SchemaVersion.v2_0.rawValue else {
            throw LocalPlanPackageError.invalidAdmission
        }
        try capabilityGate.require(admission, capability: .inertPayloadNeutralPackage)
        try validate(selection: selection, matches: plan)
        let (root, rootHandle) = try validatedOutputRoot()
        defer { rootHandle.closeHandle() }
        let targetName = plan.operationID.uuidString
        let target = root.appendingPathComponent(targetName, isDirectory: true)
        guard !rootHandle.entryExists(targetName) else { throw LocalPlanPackageError.targetExists(target) }

        let stagingName = ".\(targetName).staging.\(UUID().uuidString)"
        let staging = root.appendingPathComponent(stagingName, isDirectory: true)
        var published = false
        defer {
            if !published { rootHandle.removeChildRecursively(stagingName) }
        }
        do {
            let stagingHandle = try rootHandle.createDirectory(stagingName)
            defer { stagingHandle.closeHandle() }
            let mediaHandle = try stagingHandle.createDirectory("Media")
            defer { mediaHandle.closeHandle() }
            try stagingHandle.writeNewFile("EffectPlan.json", data: try encoded(plan))

            var mediaEntries: [LocalPlanPackageMedia] = []
            var fileEntries = [try fileEntry(in: stagingHandle, component: "EffectPlan.json", relativePath: "EffectPlan.json", kind: "effect_plan")]
            for slot in selection.slots {
                try Task.checkCancellation()
                let source = try currentSource(for: slot)
                let sourceHandle = try openedSource(source)
                defer { sourceHandle.closeHandle() }
                let before = try sourceHandle.sha256()
                guard before == slot.media.sha256 else { throw LocalPlanPackageError.sourceStale(source) }
                let component = "\(slot.role.rawValue)-\(sanitizedBasename(source.lastPathComponent))"
                let relativePath = "Media/\(component)"
                let destination = staging.appendingPathComponent(relativePath)
                let copiedHash = try mediaHandle.copyNewFile(component, from: sourceHandle)
                guard copiedHash == before else { throw LocalPlanPackageError.copiedMediaHashMismatch(destination) }
                try Task.checkCancellation()
                let after = try sourceHandle.sha256()
                guard after == before else { throw LocalPlanPackageError.sourceChangedDuringCopy(source) }
                let bytes = try mediaHandle.regularFileByteCount(component)
                mediaEntries.append(LocalPlanPackageMedia(role: slot.role, kind: slot.media.kind, relativePath: relativePath, sourceSHA256: before, byteCount: bytes))
                fileEntries.append(try fileEntry(in: mediaHandle, component: component, relativePath: relativePath, kind: "media"))
            }

            let provenance = LocalPlanPackageProvenance(
                operationID: plan.operationID,
                selectionTokenID: plan.selectionToken.tokenID,
                selectionRevision: plan.selectionToken.revision,
                originalRequest: plan.originalRequest,
                parameters: plan.parameters,
                sources: selection.slots.map { LocalPlanPackageSourceProvenance(role: $0.role, canonicalPath: $0.media.canonicalPath, sha256: $0.media.sha256, kind: $0.media.kind) }
            )
            try stagingHandle.writeNewFile("Provenance.json", data: try encoded(provenance))
            fileEntries.append(try fileEntry(in: stagingHandle, component: "Provenance.json", relativePath: "Provenance.json", kind: "provenance"))

            let readme = """
            FCPCommandConsole local plan package

            This is an inert local plan and source-media package. It is not an importable Final Cut package, does not contain FCPXML, and does not contain an effect render. Final Cut compatibility and editability are unverified.
            """
            try stagingHandle.writeNewFile("README.txt", data: Data(readme.utf8))
            fileEntries.append(try fileEntry(in: stagingHandle, component: "README.txt", relativePath: "README.txt", kind: "readme"))

            let manifest = LocalPlanPackageManifest(
                schemaVersion: plan.schemaVersion,
                operationID: plan.operationID,
                effectID: plan.effectID,
                representation: plan.representation,
                files: fileEntries.sorted { $0.relativePath < $1.relativePath },
                media: mediaEntries.sorted { $0.relativePath < $1.relativePath }
            )
            try stagingHandle.writeNewFile("Manifest.json", data: try encoded(manifest))

            // Commit point. This is the last moment a cancellation can discard
            // the work: the rename either publishes the whole staged package
            // under the operation ID or leaves nothing behind, and past it the
            // package is a durable on-disk fact that the caller must be told
            // about even if the operation was cancelled a moment later.
            try Task.checkCancellation()
            do {
                try rootHandle.renameChildExclusively(stagingName, toChild: targetName, of: rootHandle)
            } catch DirectoryDescriptorError.entryExists {
                throw LocalPlanPackageError.targetExists(target)
            }
            published = true
            return LocalPlanPackage(operationID: plan.operationID, url: target, manifest: manifest)
        } catch let error as LocalPlanPackageError {
            throw error
        } catch is CancellationError {
            // Cancellation must stay distinguishable from an I/O failure: it is
            // the one outcome that guarantees nothing was published.
            throw CancellationError()
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

    /// Validates the output root by path and then pins it to a descriptor.
    ///
    /// The path checks stay because they express policy (no `/`, no home root,
    /// no Final Cut library, no symlinked component). The descriptor is what
    /// makes them hold: every later create, copy, and publish is issued
    /// relative to this handle, so an ancestor that is renamed or replaced with
    /// a symlink after validation cannot move the writes somewhere else.
    private func validatedOutputRoot() throws -> (URL, DirectoryHandle) {
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
        do {
            return (canonical, try DirectoryHandle.open(vettedDirectory: canonical))
        } catch DirectoryDescriptorError.notADirectory {
            throw LocalPlanPackageError.outputRootUnsafe(canonical)
        } catch DirectoryDescriptorError.identityChanged {
            throw LocalPlanPackageError.outputRootSymlink(canonical)
        } catch let error as DirectoryDescriptorError {
            // `O_NOFOLLOW` on a symlinked root reports ELOOP rather than a
            // distinct error, so a failed open of a vetted directory is
            // reported as the symlink case it almost always is.
            if case .openFailed(_, let code) = error, code == ELOOP || code == ENOTDIR {
                throw LocalPlanPackageError.outputRootSymlink(canonical)
            }
            throw LocalPlanPackageError.ioFailure(error.localizedDescription)
        }
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

    /// Holds the source open for the whole copy so the hash-before, the copied
    /// bytes, and the hash-after all provably describe one inode.
    private func openedSource(_ url: URL) throws -> SourceFileHandle {
        do {
            return try SourceFileHandle.open(vettedRegularFile: url)
        } catch {
            throw LocalPlanPackageError.sourceNotRegular(url)
        }
    }

    private func fileEntry(in handle: DirectoryHandle, component: String, relativePath: String, kind: String) throws -> LocalPlanPackageFile {
        LocalPlanPackageFile(
            relativePath: relativePath,
            sha256: try handle.hashRegularFile(component),
            byteCount: try handle.regularFileByteCount(component),
            kind: kind
        )
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
