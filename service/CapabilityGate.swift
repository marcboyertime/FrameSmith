import Foundation

/// Domain-level capability classes. These decisions are intentionally separate
/// from UI state and from syntax validation: a DTD-valid plan is not evidence
/// that Final Cut has accepted its semantics.
public enum FCPCommandConsoleCapability: String, Codable, CaseIterable, Sendable {
    case localOnlyPreview = "local_only_preview"
    case inertPayloadNeutralPackage = "inert_payload_neutral_package"
    case fcpxmlPreview = "fcpxml_preview"
    case fcpxmlExport = "fcpxml_export"

    /// Generate a **new** FCPXML project from admitted local media and import it
    /// by hand. This is not a weaker `fcpxmlExport`; it is a different and
    /// smaller claim.
    ///
    /// `fcpxmlExport` asserts that a specific existing timeline may be modified,
    /// which is why it demands `VerifiedFinalCutSelectionEvidence` and can never
    /// be satisfied by local media. Standalone export asserts only that a new
    /// project was written to disk. Nothing is opened, nothing is mutated, and
    /// no existing timeline is named — so no selection evidence is required, and
    /// offering one is a category error.
    ///
    /// The semantic contracts still apply in full. Writing a file Final Cut will
    /// silently rewrite is exactly as wrong here as anywhere else.
    case standaloneFCPXMLExport = "standalone_fcpxml_export"
}

/// Each contract is admitted only after manual evidence establishes that Final
/// Cut accepts that specific semantic construct.  A successful reduced
/// dissolve probe is therefore not evidence for transform, color, or overlay
/// semantics.
public enum FCPXMLSemanticContract: String, Codable, CaseIterable, Hashable, Sendable {
    case assetAdmission = "asset_admission"

    /// A cross dissolve that Final Cut instantiates natively at the timing it
    /// was given.
    ///
    /// This case was named `bare_dissolve_transition` until the round-trip
    /// probes disproved the bare form. Revision 2 sent a `<transition>` with no
    /// effect resource and no offset; it is DTD-valid, and Final Cut imported it
    /// disabled at `offset="0s"` against a synthesized `<effect uid=""/>`. There
    /// is no construct the old name could ever describe, so admitting it was
    /// unreachable by design.
    ///
    /// Four things must hold together, and revisions 2–4 each isolated one:
    /// a real `<effect>` resource carrying the transition's UID; a
    /// `<filter-video>` on the transition referencing it; the transition offset
    /// at `cut − duration/2`; and the adjacent clips **butt-joined** at the cut
    /// with unused source beyond it. Overlapping the clips is also DTD-valid and
    /// is also silently rewritten — a `<spine>` is strictly sequential.
    case crossDissolveTransition = "cross_dissolve_transition"

    case transformKeyframes = "transform_keyframes"
    case opacityKeyframes = "opacity_keyframes"
    case nativeColorAdjustment = "native_color_adjustment"
    case connectedOverlayLayers = "connected_overlay_layers"
    /// One full-duration, opaque, video-only movie connected above an
    /// unchanged source clip. This is intentionally separate from the prior
    /// connected-still admission; DTD validity cannot promote still evidence
    /// into a movie-semantic claim.
    case connectedRenderedMovieLayer = "connected_rendered_movie_layer"
}

/// The explicitly admitted subset of FCPXML semantics. An empty profile is the
/// default and means no FCPXML workflow is authorized.
public struct ManualFCPXMLSemanticsEvidence: Codable, Equatable, Sendable {
    public let admittedContracts: Set<FCPXMLSemanticContract>

    public init(admittedContracts: Set<FCPXMLSemanticContract> = []) {
        self.admittedContracts = admittedContracts
    }

    public static let unknown = ManualFCPXMLSemanticsEvidence()

    public static func requiredContracts(for effectID: EffectID) -> Set<FCPXMLSemanticContract> {
        switch effectID {
        case .naturalDissolve:
            return [.assetAdmission, .crossDissolveTransition]
        case .targetedRotateZoom:
            return [.assetAdmission, .transformKeyframes]
        case .livingStill:
            return [.assetAdmission, .connectedRenderedMovieLayer]
        case .oldTelevision:
            return [.assetAdmission, .connectedRenderedMovieLayer]
        }
    }

    public func missingContracts(for effectID: EffectID) -> Set<FCPXMLSemanticContract> {
        Self.requiredContracts(for: effectID).subtracting(admittedContracts)
    }
}

public struct CapabilityDecision: Equatable, Sendable {
    public let capability: FCPCommandConsoleCapability
    public let allowed: Bool
    public let reason: String

    public init(capability: FCPCommandConsoleCapability, allowed: Bool, reason: String) {
        self.capability = capability
        self.allowed = allowed
        self.reason = reason
    }
}

/// Non-serializable binding issued only by a future trusted Final Cut adapter.
/// Its initializer is internal so external callers cannot turn a JSON claim
/// into capability evidence. Tests may exercise that adapter boundary through
/// `@testable import`.
public struct VerifiedFinalCutSelectionEvidence: Equatable, Sendable {
    private struct Binding: Equatable, Sendable {
        let tokenID: String
        let timelineID: String
        let revision: String
        let selectionType: SelectionType
        let clipIDs: [String]
        let sourceHashes: [String]
        let isSpine: Bool
        let adjacent: Bool
    }

    private let binding: Binding

    internal init?(verifiedToken token: SelectionToken) {
        guard token.origin == .finalCutTimelineClaim,
              token.isSpine,
              token.sourceIdentities.count == token.clipIDs.count,
              token.selectionType != .twoAdjacentClips || token.adjacent else {
            return nil
        }
        binding = Binding(
            tokenID: token.tokenID,
            timelineID: token.timelineID,
            revision: token.revision,
            selectionType: token.selectionType,
            clipIDs: token.clipIDs,
            sourceHashes: token.sourceIdentities.map(\.sha256),
            isSpine: token.isSpine,
            adjacent: token.adjacent
        )
    }

    fileprivate func matches(_ token: SelectionToken) -> Bool {
        binding == Binding(
            tokenID: token.tokenID,
            timelineID: token.timelineID,
            revision: token.revision,
            selectionType: token.selectionType,
            clipIDs: token.clipIDs,
            sourceHashes: token.sourceIdentities.map(\.sha256),
            isSpine: token.isSpine,
            adjacent: token.adjacent
        )
    }
}

/// Proof that every source a plan names came through `LocalMediaAdmission`.
///
/// Like `VerifiedFinalCutSelectionEvidence`, the initializer is internal so a
/// decoded value cannot become evidence. Unlike it, this proves something about
/// *our* inputs rather than about Final Cut's state, which is why standalone
/// export can require it without ever inspecting a timeline.
public struct AdmittedLocalMediaEvidence: Equatable, Sendable {
    private struct Admitted: Equatable, Sendable {
        let itemID: String
        let canonicalPath: String
        let sha256: String
        let context: LocalMediaContextFacts
    }

    private let admitted: [Admitted]

    internal init?(admittedAssets: [LocalMediaAsset]) {
        guard !admittedAssets.isEmpty else { return nil }
        var seen: [Admitted] = []
        for asset in admittedAssets {
            guard let binding = Self.binding(for: asset) else { return nil }
            if let sameIdentity = seen.first(where: {
                $0.itemID == binding.itemID
                    && $0.canonicalPath == binding.canonicalPath
                    && $0.sha256 == binding.sha256
            }) {
                guard sameIdentity == binding else { return nil }
            } else {
                seen.append(binding)
            }
        }
        admitted = seen.sorted {
            ($0.itemID, $0.canonicalPath, $0.sha256)
                < ($1.itemID, $1.canonicalPath, $1.sha256)
        }
    }

    /// True when every identity the token carries was admitted. This is the
    /// plan-level check; the export boundary separately checks the complete
    /// typed asset context supplied for every role.
    fileprivate func covers(_ token: SelectionToken) -> Bool {
        guard !token.sourceIdentities.isEmpty else { return false }
        return token.sourceIdentities.allSatisfy { identity in
            admitted.contains {
                $0.itemID == identity.itemID
                    && $0.canonicalPath == identity.canonicalPath
                    && $0.sha256 == identity.sha256
            }
        }
    }

    /// Exact export-boundary binding. Public `LocalMediaAsset` constructors are
    /// useful to non-export callers, but cannot use a real admission token to
    /// substitute different orientation, transform, cadence, scan, or audio
    /// facts for the same path and digest.
    internal func covers(media: [LocalMediaRole: LocalMediaAsset]) -> Bool {
        guard !media.isEmpty else { return false }
        return media.values.allSatisfy { asset in
            guard let binding = Self.binding(for: asset) else { return false }
            return admitted.contains(binding)
        }
    }

    private static func binding(for asset: LocalMediaAsset) -> Admitted? {
        guard !asset.itemID.isEmpty,
              !asset.canonicalPath.isEmpty,
              !asset.sha256.isEmpty else {
            return nil
        }
        return Admitted(
            itemID: asset.itemID,
            canonicalPath: asset.canonicalPath,
            sha256: asset.sha256,
            context: asset.contextFacts
        )
    }
}

public enum CapabilityGateError: Error, LocalizedError, Equatable, Sendable {
    case migrationRequired(LegacyEffectPlanQuarantine)
    case invalidCurrentPlanSchema(String)
    case localMediaSelectionIsNotFinalCutEvidence(FCPCommandConsoleCapability)
    case missingVerifiedFinalCutSelectionEvidence(FCPCommandConsoleCapability)
    case selectionOriginIsNotVerifiedFinalCut(FCPCommandConsoleCapability, SelectionOrigin)
    case verifiedFinalCutSelectionEvidenceMismatch(FCPCommandConsoleCapability)
    case missingManualFCPXMLSemanticsEvidence(
        capability: FCPCommandConsoleCapability,
        effectID: EffectID,
        missing: Set<FCPXMLSemanticContract>
    )
    case standaloneExportRequiresLocalMediaOrigin(SelectionOrigin)
    case standaloneExportMediaNotAdmitted
    case standaloneExportRejectsTimelineSelection

    public var errorDescription: String? {
        switch self {
        case .migrationRequired: return "Legacy effect plans are quarantined and must be replanned as schema 2.0"
        case .invalidCurrentPlanSchema(let version): return "Capability requires a current schema 2.0 plan, got \(version)"
        case .localMediaSelectionIsNotFinalCutEvidence(let capability): return "\(capability.rawValue) is blocked because local media selection does not establish Final Cut selection or adjacency evidence"
        case .missingVerifiedFinalCutSelectionEvidence(let capability): return "\(capability.rawValue) requires externally verified Final Cut selection evidence"
        case .selectionOriginIsNotVerifiedFinalCut(let capability, let origin): return "\(capability.rawValue) is blocked because \(origin.rawValue) is not a verified Final Cut selection"
        case .verifiedFinalCutSelectionEvidenceMismatch(let capability): return "\(capability.rawValue) is blocked because Final Cut selection evidence does not exactly match this plan"
        case .missingManualFCPXMLSemanticsEvidence(let capability, let effectID, let missing):
            let requirements = missing.map(\.rawValue).sorted().joined(separator: ", ")
            return "\(capability.rawValue) for \(effectID.rawValue) is blocked until manual FCPXML semantics evidence admits: \(requirements)"
        case .standaloneExportRequiresLocalMediaOrigin(let origin):
            return "standalone_fcpxml_export generates a new project from admitted local media; \(origin.rawValue) is not that"
        case .standaloneExportMediaNotAdmitted:
            return "standalone_fcpxml_export requires every plan source identity to match canonical admitted local media"
        case .standaloneExportRejectsTimelineSelection:
            return "standalone_fcpxml_export cannot be issued against a Final Cut timeline selection because it does not modify an existing timeline"
        }
    }
}

public struct CapabilityGate: Sendable {
    public let manualSemanticsEvidence: ManualFCPXMLSemanticsEvidence

    public init(manualSemanticsEvidence: ManualFCPXMLSemanticsEvidence = .unknown) {
        self.manualSemanticsEvidence = manualSemanticsEvidence
    }

    public func decision(for admission: EffectPlanAdmissionResult, capability: FCPCommandConsoleCapability) -> CapabilityDecision {
        switch admission {
        case .migrationRequired:
            return CapabilityDecision(capability: capability, allowed: false, reason: "Legacy plan is quarantined; replan and validate schema 2.0")
        case .current(let plan):
            return decision(for: plan, capability: capability)
        }
    }

    public func decision(for admission: EffectPlanAdmissionResult, capability: FCPCommandConsoleCapability, selectionEvidence: VerifiedFinalCutSelectionEvidence) -> CapabilityDecision {
        switch admission {
        case .migrationRequired:
            return CapabilityDecision(capability: capability, allowed: false, reason: "Legacy plan is quarantined; replan and validate schema 2.0")
        case .current(let plan):
            return decision(for: plan, capability: capability, selectionEvidence: selectionEvidence)
        }
    }

    public func decision(for plan: EffectPlan, capability: FCPCommandConsoleCapability) -> CapabilityDecision {
        guard plan.schemaVersion == SchemaVersion.v2_0.rawValue else {
            return CapabilityDecision(capability: capability, allowed: false, reason: "Current capability admission requires schema 2.0")
        }
        switch capability {
        case .localOnlyPreview, .inertPayloadNeutralPackage:
            return CapabilityDecision(capability: capability, allowed: true, reason: "Current v2 plan is eligible for local-only, payload-neutral work")
        case .fcpxmlPreview, .fcpxmlExport:
            if plan.selectionToken.origin == .localMedia {
                return CapabilityDecision(capability: capability, allowed: false, reason: "Local media selection does not establish Final Cut selection or adjacency evidence")
            }
            return CapabilityDecision(capability: capability, allowed: false, reason: "Externally verified Final Cut selection evidence is required")
        case .standaloneFCPXMLExport:
            return CapabilityDecision(capability: capability, allowed: false, reason: "Standalone FCPXML export requires admitted local media evidence")
        }
    }

    public func decision(for plan: EffectPlan, capability: FCPCommandConsoleCapability, selectionEvidence: VerifiedFinalCutSelectionEvidence) -> CapabilityDecision {
        guard plan.schemaVersion == SchemaVersion.v2_0.rawValue else {
            return CapabilityDecision(capability: capability, allowed: false, reason: "Current capability admission requires schema 2.0")
        }
        switch capability {
        case .localOnlyPreview, .inertPayloadNeutralPackage:
            return CapabilityDecision(capability: capability, allowed: true, reason: "Current v2 plan is eligible for local-only, payload-neutral work")
        case .fcpxmlPreview, .fcpxmlExport:
            guard plan.selectionToken.origin == .finalCutTimelineClaim else {
                return CapabilityDecision(capability: capability, allowed: false, reason: "Selection origin is not an eligible Final Cut claim")
            }
            guard selectionEvidence.matches(plan.selectionToken) else {
                return CapabilityDecision(capability: capability, allowed: false, reason: "Final Cut selection evidence does not exactly match this plan")
            }
            let missing = manualSemanticsEvidence.missingContracts(for: plan.effectID)
            guard missing.isEmpty else {
                let requirements = missing.map(\.rawValue).sorted().joined(separator: ", ")
                return CapabilityDecision(capability: capability, allowed: false, reason: "Manual FCPXML semantics evidence is incomplete: \(requirements)")
            }
            return CapabilityDecision(capability: capability, allowed: true, reason: "Verified Final Cut selection and manual FCPXML semantics evidence admit all required contracts")
        case .standaloneFCPXMLExport:
            return CapabilityDecision(capability: capability, allowed: false, reason: "Standalone FCPXML export does not modify an existing timeline; a Final Cut selection cannot authorize it")
        }
    }

    // MARK: - Standalone export

    /// Decide standalone export, which needs admitted local media instead of a
    /// Final Cut selection. The semantic contracts are unchanged — only the
    /// question of *what is being claimed* differs.
    public func decision(
        for plan: EffectPlan,
        capability: FCPCommandConsoleCapability,
        mediaEvidence: AdmittedLocalMediaEvidence
    ) -> CapabilityDecision {
        guard plan.schemaVersion == SchemaVersion.v2_0.rawValue else {
            return CapabilityDecision(capability: capability, allowed: false, reason: "Current capability admission requires schema 2.0")
        }
        switch capability {
        case .localOnlyPreview, .inertPayloadNeutralPackage:
            return CapabilityDecision(capability: capability, allowed: true, reason: "Current v2 plan is eligible for local-only, payload-neutral work")
        case .fcpxmlPreview, .fcpxmlExport:
            return CapabilityDecision(capability: capability, allowed: false, reason: "Admitted local media is not Final Cut selection evidence and cannot authorize modifying an existing timeline")
        case .standaloneFCPXMLExport:
            guard plan.selectionToken.origin != .finalCutTimelineClaim else {
                return CapabilityDecision(capability: capability, allowed: false, reason: "Standalone export cannot be issued against a Final Cut timeline selection")
            }
            guard plan.selectionToken.origin == .localMedia else {
                return CapabilityDecision(capability: capability, allowed: false, reason: "Standalone export requires a local media selection, got \(plan.selectionToken.origin.rawValue)")
            }
            guard mediaEvidence.covers(plan.selectionToken) else {
                return CapabilityDecision(capability: capability, allowed: false, reason: "Every plan source must be canonical admitted local media matched on item, path, and digest")
            }
            let missing = manualSemanticsEvidence.missingContracts(for: plan.effectID)
            guard missing.isEmpty else {
                let requirements = missing.map(\.rawValue).sorted().joined(separator: ", ")
                return CapabilityDecision(capability: capability, allowed: false, reason: "Manual FCPXML semantics evidence is incomplete: \(requirements)")
            }
            return CapabilityDecision(capability: capability, allowed: true, reason: "Admitted local media and manual FCPXML semantics evidence admit generating a new project")
        }
    }

    public func decision(
        for admission: EffectPlanAdmissionResult,
        capability: FCPCommandConsoleCapability,
        mediaEvidence: AdmittedLocalMediaEvidence
    ) -> CapabilityDecision {
        switch admission {
        case .migrationRequired:
            return CapabilityDecision(capability: capability, allowed: false, reason: "Legacy plan is quarantined; replan and validate schema 2.0")
        case .current(let plan):
            return decision(for: plan, capability: capability, mediaEvidence: mediaEvidence)
        }
    }

    public func require(
        _ plan: EffectPlan,
        capability: FCPCommandConsoleCapability,
        mediaEvidence: AdmittedLocalMediaEvidence
    ) throws {
        guard plan.schemaVersion == SchemaVersion.v2_0.rawValue else {
            throw CapabilityGateError.invalidCurrentPlanSchema(plan.schemaVersion)
        }
        switch capability {
        case .localOnlyPreview, .inertPayloadNeutralPackage:
            return
        case .fcpxmlPreview, .fcpxmlExport:
            throw CapabilityGateError.missingVerifiedFinalCutSelectionEvidence(capability)
        case .standaloneFCPXMLExport:
            guard plan.selectionToken.origin != .finalCutTimelineClaim else {
                throw CapabilityGateError.standaloneExportRejectsTimelineSelection
            }
            guard plan.selectionToken.origin == .localMedia else {
                throw CapabilityGateError.standaloneExportRequiresLocalMediaOrigin(plan.selectionToken.origin)
            }
            guard mediaEvidence.covers(plan.selectionToken) else {
                throw CapabilityGateError.standaloneExportMediaNotAdmitted
            }
            let missing = manualSemanticsEvidence.missingContracts(for: plan.effectID)
            guard missing.isEmpty else {
                throw CapabilityGateError.missingManualFCPXMLSemanticsEvidence(
                    capability: capability,
                    effectID: plan.effectID,
                    missing: missing
                )
            }
        }
    }

    public func require(
        _ admission: EffectPlanAdmissionResult,
        capability: FCPCommandConsoleCapability,
        mediaEvidence: AdmittedLocalMediaEvidence
    ) throws {
        if case .migrationRequired(let legacy) = admission { throw CapabilityGateError.migrationRequired(legacy) }
        if case .current(let plan) = admission { try require(plan, capability: capability, mediaEvidence: mediaEvidence) }
    }

    public func require(_ admission: EffectPlanAdmissionResult, capability: FCPCommandConsoleCapability) throws {
        if case .migrationRequired(let legacy) = admission { throw CapabilityGateError.migrationRequired(legacy) }
        if case .current(let plan) = admission { try require(plan, capability: capability) }
    }

    public func require(_ admission: EffectPlanAdmissionResult, capability: FCPCommandConsoleCapability, selectionEvidence: VerifiedFinalCutSelectionEvidence) throws {
        if case .migrationRequired(let legacy) = admission { throw CapabilityGateError.migrationRequired(legacy) }
        if case .current(let plan) = admission { try require(plan, capability: capability, selectionEvidence: selectionEvidence) }
    }

    public func require(_ plan: EffectPlan, capability: FCPCommandConsoleCapability) throws {
        guard plan.schemaVersion == SchemaVersion.v2_0.rawValue else {
            throw CapabilityGateError.invalidCurrentPlanSchema(plan.schemaVersion)
        }
        switch capability {
        case .localOnlyPreview, .inertPayloadNeutralPackage:
            return
        case .fcpxmlPreview, .fcpxmlExport:
            if plan.selectionToken.origin == .localMedia {
                throw CapabilityGateError.localMediaSelectionIsNotFinalCutEvidence(capability)
            }
            throw CapabilityGateError.missingVerifiedFinalCutSelectionEvidence(capability)
        case .standaloneFCPXMLExport:
            throw CapabilityGateError.standaloneExportMediaNotAdmitted
        }
    }

    public func require(_ plan: EffectPlan, capability: FCPCommandConsoleCapability, selectionEvidence: VerifiedFinalCutSelectionEvidence) throws {
        guard plan.schemaVersion == SchemaVersion.v2_0.rawValue else {
            throw CapabilityGateError.invalidCurrentPlanSchema(plan.schemaVersion)
        }
        switch capability {
        case .localOnlyPreview, .inertPayloadNeutralPackage:
            return
        case .fcpxmlPreview, .fcpxmlExport:
            guard plan.selectionToken.origin == .finalCutTimelineClaim else {
                throw CapabilityGateError.selectionOriginIsNotVerifiedFinalCut(capability, plan.selectionToken.origin)
            }
            guard selectionEvidence.matches(plan.selectionToken) else {
                throw CapabilityGateError.verifiedFinalCutSelectionEvidenceMismatch(capability)
            }
            let missing = manualSemanticsEvidence.missingContracts(for: plan.effectID)
            guard missing.isEmpty else {
                throw CapabilityGateError.missingManualFCPXMLSemanticsEvidence(
                    capability: capability,
                    effectID: plan.effectID,
                    missing: missing
                )
            }
        case .standaloneFCPXMLExport:
            throw CapabilityGateError.standaloneExportRejectsTimelineSelection
        }
    }
}
