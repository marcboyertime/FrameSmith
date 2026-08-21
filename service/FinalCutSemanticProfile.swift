import Foundation

/// The exact Final Cut Pro build a semantic profile was established against.
///
/// Admission is never version-free. Every contract in this file was admitted by
/// observing one specific build's import behaviour, and an application update
/// can change that behaviour without notice. A profile therefore only applies
/// when the installed build matches it exactly.
public struct FinalCutVersionIdentity: Codable, Equatable, Hashable, Sendable {
    public let shortVersion: String
    public let build: String

    public init(shortVersion: String, build: String) {
        self.shortVersion = shortVersion
        self.build = build
    }

    public var description: String { "\(shortVersion) (\(build))" }
}

/// One admitted contract, bound to the artifact that admitted it.
///
/// The digest is the returned FCPXML Final Cut itself produced, not the file we
/// sent. That direction matters: the sent file is our claim, the returned file
/// is the observation. Recording it makes an admission auditable after the
/// fact — the record names a document a reader can open and a digest they can
/// recompute.
public struct AdmittedContractRecord: Equatable, Hashable, Sendable {
    public let contract: FCPXMLSemanticContract
    /// Repo-relative worksheet that records the pass.
    public let evidenceDocument: String
    /// SHA-256 of the returned `Info.fcpxml` the pass read.
    public let returnedArtifactSHA256: String
    /// ISO-8601 date the pass was run.
    public let admittedOn: String
    /// What the pass did *not* establish. Kept beside the admission so a
    /// limitation cannot be lost by being recorded somewhere else.
    public let limitations: [String]

    internal init(
        contract: FCPXMLSemanticContract,
        evidenceDocument: String,
        returnedArtifactSHA256: String,
        admittedOn: String,
        limitations: [String] = []
    ) {
        self.contract = contract
        self.evidenceDocument = evidenceDocument
        self.returnedArtifactSHA256 = returnedArtifactSHA256
        self.admittedOn = admittedOn
        self.limitations = limitations
    }
}

/// A version-scoped set of admitted semantic contracts.
///
/// This is the contract store. Its shape is deliberate in three ways.
///
/// 1. **It is code, not data.** The memberwise initializer is `internal`, so no
///    decoder, plist, preference, or downloaded file can construct a profile
///    that admits anything. Adding an admission requires editing this file and
///    passing review — the same bar `VerifiedFinalCutSelectionEvidence` sets for
///    selection evidence. `Codable` is deliberately not conformed.
/// 2. **It is version-scoped.** `evidence(forInstalled:)` returns the empty
///    profile unless the installed build matches exactly. A Final Cut update
///    silently revokes every admission until the passes are re-run.
/// 3. **It carries its own limitations.** A record that admits a contract also
///    states what it failed to establish, so the caveat travels with the claim.
public struct FinalCutSemanticProfile: Equatable, Sendable {
    public let finalCut: FinalCutVersionIdentity
    public let records: [AdmittedContractRecord]

    internal init(finalCut: FinalCutVersionIdentity, records: [AdmittedContractRecord]) {
        self.finalCut = finalCut
        self.records = records
    }

    /// The contracts this profile admits, ignoring which build is installed.
    /// Callers deciding capability must use `evidence(forInstalled:)` instead.
    public var admittedContracts: Set<FCPXMLSemanticContract> {
        Set(records.map(\.contract))
    }

    /// Evidence usable for a capability decision, or `.unknown` on any version
    /// mismatch. Failing closed on drift is the whole point of the scoping.
    public func evidence(forInstalled installed: FinalCutVersionIdentity) -> ManualFCPXMLSemanticsEvidence {
        guard installed == finalCut else { return .unknown }
        return ManualFCPXMLSemanticsEvidence(admittedContracts: admittedContracts)
    }

    public func record(for contract: FCPXMLSemanticContract) -> AdmittedContractRecord? {
        records.first { $0.contract == contract }
    }

    /// Contracts an effect needs that this profile does not admit.
    public func missingContracts(for effectID: EffectID) -> Set<FCPXMLSemanticContract> {
        ManualFCPXMLSemanticsEvidence.requiredContracts(for: effectID)
            .subtracting(admittedContracts)
    }
}

/// The curated set of profiles. One per tested build.
public enum FinalCutSemanticProfileStore {
    /// Final Cut Pro 12.3 (450152) — the only build any manual pass has been
    /// run against.
    ///
    /// All seven contracts are admitted as of 2026-08-08. That is a statement
    /// about *semantics being accepted on import*, not about the four workflows
    /// being finished: editability is separate and exists only where an
    /// individual record says so, the connected rendered-movie pass establishes
    /// none, and no contract admits a mapping from creative language to values.
    public static let finalCut12_3_450152 = FinalCutSemanticProfile(
        finalCut: FinalCutVersionIdentity(shortVersion: "12.3", build: "450152"),
        records: [
            AdmittedContractRecord(
                contract: .assetAdmission,
                evidenceDocument: "docs/ROUNDTRIP_MANUAL_PASS.md",
                returnedArtifactSHA256: "d76a5635baad6050ef2f80c3592cc4f6ee63a2a1112575ebddc10ca4d0e3ae1f",
                admittedOn: "2026-08-04",
                limitations: [
                    "Established with .mov media referenced from a package Media/ directory; the returned src was unchanged, so Final Cut left the files in place rather than copying them into the library.",
                    "The living still pass did not independently establish this: its .png resolved by dedup against media already in the library, so that run proves nothing about first-import resolution.",
                    "Editability is NOT established, and for this contract that means relinking: no pass has moved, renamed, or replaced the referenced media after import to see whether Final Cut relinks or reports it offline."
                ]
            ),
            AdmittedContractRecord(
                contract: .crossDissolveTransition,
                evidenceDocument: "docs/ROUNDTRIP_MANUAL_PASS.md",
                returnedArtifactSHA256: "d76a5635baad6050ef2f80c3592cc4f6ee63a2a1112575ebddc10ca4d0e3ae1f",
                admittedOn: "2026-08-04",
                limitations: [
                    "Requires all four construction rules together: a real <effect> resource, a <filter-video> referencing it, offset at cut minus duration/2, and butt-joined adjacent clips. Overlapping clips are DTD-valid and silently re-flowed.",
                    "Duration editability confirmed separately (docs/DISSOLVE_EDITABILITY_PASS.md, returned 4ce61afc4f1b328dad69c866d63caf2037c9c62eab2c183718ef594a3da22be6). Edge-dragging was not exercised."
                ]
            ),
            AdmittedContractRecord(
                contract: .transformKeyframes,
                evidenceDocument: "docs/LIVING_STILL_ADMISSION_PASS.md",
                returnedArtifactSHA256: "8a3ecd236cc9c87459ef425f04951bafa29a68c84be937c36041d0a59c8f2ab9",
                admittedOn: "2026-08-04",
                limitations: [
                    "Covers position (nested X/Y sub-params) and scale (one param, paired values) only. Rotation encoding is unobserved and native.targeted_rotate_zoom must capture it before emitting one.",
                    "position is percent of frame height, not pixels; keyframe times are absolute from the 3600s source origin.",
                    "Editability confirmed 2026-08-05 (docs/LIVING_STILL_EDITABILITY_PASS.md, returned 1f32d6da03ef531449c42aab2da9d7b0081ccb6e3c0c22e6d3cebf49fa9085c0). Typing 54 px produced exactly 5, so the percent-of-height conversion holds in both directions.",
                    "Rotation admitted 2026-08-05 (docs/NATIVE_EFFECT_ADMISSION_PASS.md, returned cc9affa18d4c73eac723c75ec4fb9e8c08801142922ab4428879ced0c28f3099): a generated rotation, scale, and compensating position track returned with values intact. Rotation is plain degrees; anchor is a paired attribute; a movie clip's keyframes start at 0s, not the stills' 3600s.",
                    "That pass also normalised our output: co-timed position axes were collapsed from nested X/Y sub-params into one paired-value param, param order was canonicalised, and precision was reduced to about six significant figures. The nested form is required only when the axes are independently timed. Semantics survived; shape did not.",
                    "Rotation editability confirmed 2026-08-05 (docs/NATIVE_EFFECT_ADMISSION_PASS.md, returned 5c7f74df72bfd69f0e86e2e94f32b4494d3de4bd244bf83fc0feef02a204e6de): a rotation keyframe edited 12 to 30 degrees returned as 30, with scale, position, and keyframe count unchanged.",
                    "That pass required a REGENERATED package. A keyframe emitted at a clip's end boundary (4s on a 4s clip) renders correctly but cannot be selected: the playhead lands past the last frame and the Inspector reads interpolated values, so the user cannot edit it. Emit the final keyframe inside the clip.",
                    "Editing one position axis writes a keyframe on BOTH axes at that time. A strict tree comparison of a user-edited position will report a false difference."
                ]
            ),
            AdmittedContractRecord(
                contract: .opacityKeyframes,
                evidenceDocument: "docs/LIVING_STILL_ADMISSION_PASS.md",
                returnedArtifactSHA256: "8a3ecd236cc9c87459ef425f04951bafa29a68c84be937c36041d0a59c8f2ab9",
                admittedOn: "2026-08-04",
                limitations: [
                    "adjust-blend/amount keyframes only. Blend modes were not exercised.",
                    "Editability confirmed 2026-08-05 (docs/LIVING_STILL_EDITABILITY_PASS.md, returned 1f32d6da03ef531449c42aab2da9d7b0081ccb6e3c0c22e6d3cebf49fa9085c0): an animated opacity keyframe edited from 0 to 25% returned as 0.25.",
                    "The static attribute form was edited separately on a connected overlay (docs/NATIVE_EFFECT_ADMISSION_PASS.md, returned a81da13f7b3a7f7acae819634b3dfb2781e6259abfe76de15a4571c72ea675bc) and stayed an attribute rather than being promoted to a param."
                ]
            ),
            AdmittedContractRecord(
                contract: .nativeColorAdjustment,
                evidenceDocument: "docs/LIVING_STILL_ADMISSION_PASS.md",
                returnedArtifactSHA256: "8a3ecd236cc9c87459ef425f04951bafa29a68c84be937c36041d0a59c8f2ab9",
                admittedOn: "2026-08-04",
                limitations: [
                    "Admits the Color Adjustments construction carrying all 18 params and all three opaque payloads verbatim. Whether the payloads are required is untested.",
                    "Admits the construction, not a mapping: the probe reused the captured Saturation value of 25. No creative-language-to-parameter mapping is observed.",
                    "Editability is NOT established. Every pass has imported and exported this filter without touching one of its parameters, so whether an edited Saturation survives - and whether editing one rewrites the three opaque payloads - is unknown."
                ]
            ),
            AdmittedContractRecord(
                contract: .connectedOverlayLayers,
                evidenceDocument: "docs/NATIVE_EFFECT_ADMISSION_PASS.md",
                returnedArtifactSHA256: "f92bbd703ba0efcf4300d3fc4f4f28a32d4acc3cd0926b77a863d9b29ad46da2",
                admittedOn: "2026-08-05",
                limitations: [
                    "A connected clip is a CHILD of the spine asset-clip with lane=1, and its offset is measured from the parent clip's start, not the timeline origin. Timeline-relative offsets are valid FCPXML that silently misplace every overlay on a non-first clip.",
                    "Only lane 1 was exercised. Lanes below the spine, and more than one connected layer at once, are unobserved.",
                    "The overlay used the static blend form (amount and mode as attributes). Whether a mode attribute may coexist with an animated amount param is unobserved and was deliberately avoided.",
                    "Only the Overlay blend mode is observed. Other modes' indices are derivable from the menu ordering but a derived index that is wrong applies the wrong mode in a valid document.",
                    "Editability confirmed 2026-08-05 (docs/NATIVE_EFFECT_ADMISSION_PASS.md, returned a81da13f7b3a7f7acae819634b3dfb2781e6259abfe76de15a4571c72ea675bc). The overlay's opacity was edited 50% to 75% and returned as amount=0.75 with lane, offset, start, and mode all unchanged. The value stayed an ATTRIBUTE rather than being promoted to a param, so the static form survives an edit and is not merely an export artefact.",
                    "The blend mode dropdown was not changed, and the overlay was not moved or retimed. Editability of opacity does not extend to those."
                ]
            ),
            AdmittedContractRecord(
                contract: .connectedRenderedMovieLayer,
                evidenceDocument: "docs/CONNECTED_RENDERED_MOVIE_ADMISSION_PASS.md",
                returnedArtifactSHA256: "87c95fa47679788adbff8ac9854bdfa2b485c9acff0bc6c9abdcb573a2cb9bc7",
                admittedOn: "2026-08-08",
                limitations: [
                    "Admitted only for the two FCPXML 1.14 parent contexts in the worksheet: a connected <video> over a movie <asset-clip> (primary returned SHA above) and over a still <video> (returned SHA 26eb90634a82dbbe7dfc1150a7288c25dc972c973ef1bfce5181ac9af8a377de). No other parent kind is observed.",
                    "The connected resource was exactly video-only Apple ProRes 422 HQ (prores/HQ/apch/yuv422p10le), 1920x1080 at 30 fps, 120 frames and four seconds. Other codecs, profiles, pixel formats, audio-bearing renders, resolutions, frame rates and durations are unobserved.",
                    "The only admitted placement is one enabled, default-opaque <video> child with no child intrinsics or blend adjustment, at lane=1, offset=0s, inherited/zero start and duration=4s covering the full parent. Other lanes, offsets, starts, durations, multiple connected layers, transforms, filters, opacity adjustments and blend modes are unobserved.",
                    "The source spine returned unchanged in both admitted contexts: its original parent resource and timing remained, no visual or audio mutations were added, and the movie parent's source-audio metadata and dialogue role remained. This does not establish media-copy, relink or replacement behaviour.",
                    "Editability is NOT established. Neither the connected movie nor either parent was moved, retimed, blended or edited; the passes establish only import-and-return acceptance and do not generalize to retiming, blend behaviour, parameter mapping, editability or visual quality."
                ]
            )
        ]
    )

    public static let all: [FinalCutSemanticProfile] = [finalCut12_3_450152]

    public static func profile(for installed: FinalCutVersionIdentity) -> FinalCutSemanticProfile? {
        all.first { $0.finalCut == installed }
    }

    /// Evidence for the installed build, or `.unknown` when no profile matches.
    public static func evidence(forInstalled installed: FinalCutVersionIdentity) -> ManualFCPXMLSemanticsEvidence {
        profile(for: installed)?.evidence(forInstalled: installed) ?? .unknown
    }
}

/// Reads the installed Final Cut build. A read failure yields `nil`, which
/// callers must treat as "no profile applies" rather than as a match.
public struct InstalledFinalCutVersionReader: Sendable {
    public let applicationURL: URL

    public init(applicationURL: URL = URL(fileURLWithPath: "/Applications/Final Cut Pro.app")) {
        self.applicationURL = applicationURL
    }

    public func read() -> FinalCutVersionIdentity? {
        let plist = applicationURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plist),
              let raw = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let info = raw as? [String: Any],
              let short = info["CFBundleShortVersionString"] as? String,
              let build = info["CFBundleVersion"] as? String
        else { return nil }
        return FinalCutVersionIdentity(shortVersion: short, build: build)
    }
}
