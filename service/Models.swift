import Foundation

public enum SchemaVersion: String, Codable, CaseIterable, Sendable {
    case v2_0 = "2.0"
}

/// The only effect identifiers that are part of the Phase 1 contract.
public enum EffectID: String, Codable, CaseIterable, Sendable, Hashable {
    case targetedRotateZoom = "native.targeted_rotate_zoom"
    case oldTelevision = "look.old_television"
    case naturalDissolve = "transition.natural_dissolve"
    case livingStill = "motion.living_still"

    public init?(identifier: String) {
        let value = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch value {
        case "native.targeted_rotate_zoom": self = .targetedRotateZoom
        case "look.old_television": self = .oldTelevision
        case "transition.natural_dissolve": self = .naturalDissolve
        case "motion.living_still": self = .livingStill
        default:
            return nil
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard let id = EffectID(identifier: value) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown Phase 1 effect identifier: \(value)")
        }
        self = id
    }
}

public enum RepresentationClass: String, Codable, CaseIterable, Sendable {
    case fcpxmlNative = "fcpxml_native"
    case layeredMedia = "layered_media"
    case motionTemplate = "motion_template"
    case externalEditableComposition = "external_editable_composition"
    case bakedRender = "baked_render"

    public init?(identifier: String) {
        switch identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "fcpxml_native": self = .fcpxmlNative
        case "layered_media": self = .layeredMedia
        case "motion_template": self = .motionTemplate
        case "external_editable_composition": self = .externalEditableComposition
        case "baked_render": self = .bakedRender
        default: return nil
        }
    }
}

/// Legacy plan payloads are quarantined rather than upgraded into executable
/// current plans. The suggested class is explanatory only; the request must be
/// replanned and validated as schema 2.0 before any capability is considered.
public struct LegacyEffectPlanQuarantine: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let legacyRepresentation: String?
    public let suggestedRepresentation: RepresentationClass?
    public let replanningRequired: Bool

    public init(schemaVersion: String, legacyRepresentation: String?, suggestedRepresentation: RepresentationClass?, replanningRequired: Bool = true) {
        self.schemaVersion = schemaVersion
        self.legacyRepresentation = legacyRepresentation
        self.suggestedRepresentation = suggestedRepresentation
        self.replanningRequired = replanningRequired
    }
}

public enum EffectPlanAdmissionResult: Equatable, Sendable {
    case current(EffectPlan)
    case migrationRequired(LegacyEffectPlanQuarantine)
}

public enum EffectPlanAdmissionError: Error, LocalizedError, Equatable, Sendable {
    case invalidDocument
    case unsupportedSchemaVersion(String)

    public var errorDescription: String? {
        switch self {
        case .invalidDocument: return "Effect plan admission requires a JSON object with schemaVersion"
        case .unsupportedSchemaVersion(let value): return "Unsupported effect plan schema version: \(value)"
        }
    }
}

public enum EffectPlanAdmission {
    public static func decode(_ data: Data, decoder: JSONDecoder = JSONDecoder()) throws -> EffectPlanAdmissionResult {
        guard let document = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let schemaVersion = document["schemaVersion"] as? String else {
            throw EffectPlanAdmissionError.invalidDocument
        }
        switch schemaVersion {
        case SchemaVersion.v2_0.rawValue:
            return .current(try decoder.decode(EffectPlan.self, from: data))
        case "1.0":
            let legacyRepresentation = document["representation"] as? String
            return .migrationRequired(LegacyEffectPlanQuarantine(
                schemaVersion: schemaVersion,
                legacyRepresentation: legacyRepresentation,
                suggestedRepresentation: suggestedRepresentation(for: legacyRepresentation)
            ))
        default:
            throw EffectPlanAdmissionError.unsupportedSchemaVersion(schemaVersion)
        }
    }

    private static func suggestedRepresentation(for legacyValue: String?) -> RepresentationClass? {
        switch legacyValue {
        case "fcp_native": return .fcpxmlNative
        case "generated_asset_plus_fcp_native": return .layeredMedia
        case "external_render_required": return .bakedRender
        default: return nil
        }
    }
}

public enum SelectionType: String, Codable, CaseIterable, Sendable {
    case singleClip = "single-clip"
    case twoAdjacentClips = "two-adjacent-clips"
    case range
    case point
    case none

    public init(identifier: String) {
        switch identifier.lowercased().replacingOccurrences(of: "_", with: "-") {
        case "single-clip", "clip": self = .singleClip
        case "two-adjacent-clips", "adjacent-clips", "clips", "two-clips": self = .twoAdjacentClips
        case "range", "time-range": self = .range
        case "point", "coordinate": self = .point
        default: self = .none
        }
    }
}

/// Describes where a selection claim originated. This descriptive value is not
/// authorization: FCPXML capability also requires trusted external evidence.
public enum SelectionOrigin: String, Codable, CaseIterable, Sendable {
    case localMedia = "local_media"
    case unverifiedExternal = "unverified_external"
    case finalCutTimelineClaim = "final_cut_timeline_claim"
}

public enum Backend: String, Codable, CaseIterable, Sendable {
    case native
    case ffmpeg
    case depthflow
    case local
}

public enum Easing: String, Codable, CaseIterable, Sendable {
    case linear
    case easeIn = "ease_in"
    case easeOut = "ease_out"
    case easeInOut = "ease_in_out"
}

/// A JSON-compatible, typed value used for effect parameters. It deliberately
/// has no command, shell, selector, or arbitrary backend representation.
public enum ParameterValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case integer(Int)
    case boolean(Bool)
    case object([String: ParameterValue])
    case array([ParameterValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let value = try? container.decode(Bool.self) { self = .boolean(value); return }
        if let value = try? container.decode(Int.self) { self = .integer(value); return }
        if let value = try? container.decode(Double.self) { self = .number(value); return }
        if let value = try? container.decode(String.self) { self = .string(value); return }
        if let value = try? container.decode([String: ParameterValue].self) { self = .object(value); return }
        if let value = try? container.decode([ParameterValue].self) { self = .array(value); return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported parameter value")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .boolean(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    public var numberValue: Double? {
        switch self {
        case .number(let value): return value
        case .integer(let value): return Double(value)
        default: return nil
        }
    }

    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }
}

public struct Target: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var coordinateSpace: String
    public var confirmed: Bool

    public init(x: Double, y: Double, coordinateSpace: String = "normalized-frame", confirmed: Bool = false) {
        self.x = x
        self.y = y
        self.coordinateSpace = coordinateSpace
        self.confirmed = confirmed
    }

    /// Point confirmation is the one place where user coordinates are clamped.
    /// Decoding and validation never silently clamp serialized plans.
    public static func confirmed(x: Double, y: Double, coordinateSpace: String = "normalized-frame") -> Target {
        Target(x: min(1, max(0, x)), y: min(1, max(0, y)), coordinateSpace: coordinateSpace, confirmed: true)
    }

    public var isFinite: Bool { x.isFinite && y.isFinite }
    public var isInNormalizedBounds: Bool { isFinite && (0...1).contains(x) && (0...1).contains(y) }
}

/// Stable source identity captured with a selection token. A source identity
/// is deliberately content-addressed so a later executor can refuse a stale
/// or substituted media item before any mutation.
public struct SourceIdentity: Codable, Equatable, Sendable {
    public var itemID: String
    public var canonicalPath: String
    public var sha256: String

    public init(itemID: String, canonicalPath: String, sha256: String) {
        self.itemID = itemID
        self.canonicalPath = canonicalPath
        self.sha256 = sha256
    }
}

public typealias SelectionSource = SourceIdentity

public struct SelectionToken: Codable, Equatable, Sendable {
    public var tokenID: String
    public var selectionType: SelectionType
    public var timelineID: String
    public var origin: SelectionOrigin
    public var clipIDs: [String]
    public var sourceIdentities: [SourceIdentity]
    public var revision: String
    public var startFrame: Int?
    public var endFrame: Int?
    public var sourceDurationFrames: Int?
    public var sourceRangeStartFrame: Int?
    public var sourceRangeEndFrame: Int?
    public var leftSourceDurationFrames: Int?
    public var rightSourceDurationFrames: Int?
    public var leftSourceRangeStartFrame: Int?
    public var leftSourceRangeEndFrame: Int?
    public var rightSourceRangeStartFrame: Int?
    public var rightSourceRangeEndFrame: Int?
    public var leftClipEndFrame: Int?
    public var rightClipStartFrame: Int?
    public var boundaryFrame: Int?
    public var frameRate: Int?
    public var handleBeforeFrames: Int
    public var handleAfterFrames: Int
    public var isSpine: Bool
    public var adjacent: Bool

    public init(
        tokenID: String = UUID().uuidString,
        selectionType: SelectionType,
        timelineID: String = "timeline",
        origin: SelectionOrigin = .unverifiedExternal,
        clipIDs: [String],
        sourceIdentities: [SourceIdentity] = [],
        revision: String,
        startFrame: Int? = nil,
        endFrame: Int? = nil,
        sourceDurationFrames: Int? = nil,
        sourceRangeStartFrame: Int? = nil,
        sourceRangeEndFrame: Int? = nil,
        leftSourceDurationFrames: Int? = nil,
        rightSourceDurationFrames: Int? = nil,
        leftSourceRangeStartFrame: Int? = nil,
        leftSourceRangeEndFrame: Int? = nil,
        rightSourceRangeStartFrame: Int? = nil,
        rightSourceRangeEndFrame: Int? = nil,
        leftClipEndFrame: Int? = nil,
        rightClipStartFrame: Int? = nil,
        boundaryFrame: Int? = nil,
        frameRate: Int? = nil,
        handleBeforeFrames: Int = 0,
        handleAfterFrames: Int = 0,
        isSpine: Bool = true,
        adjacent: Bool = true
    ) {
        self.tokenID = tokenID
        self.selectionType = selectionType
        self.timelineID = timelineID
        self.origin = origin
        self.clipIDs = clipIDs
        self.sourceIdentities = sourceIdentities
        self.revision = revision
        self.startFrame = startFrame
        self.endFrame = endFrame
        self.sourceDurationFrames = sourceDurationFrames
        self.sourceRangeStartFrame = sourceRangeStartFrame
        self.sourceRangeEndFrame = sourceRangeEndFrame
        self.leftSourceDurationFrames = leftSourceDurationFrames
        self.rightSourceDurationFrames = rightSourceDurationFrames
        self.leftSourceRangeStartFrame = leftSourceRangeStartFrame
        self.leftSourceRangeEndFrame = leftSourceRangeEndFrame
        self.rightSourceRangeStartFrame = rightSourceRangeStartFrame
        self.rightSourceRangeEndFrame = rightSourceRangeEndFrame
        self.leftClipEndFrame = leftClipEndFrame
        self.rightClipStartFrame = rightClipStartFrame
        self.boundaryFrame = boundaryFrame
        self.frameRate = frameRate
        self.handleBeforeFrames = handleBeforeFrames
        self.handleAfterFrames = handleAfterFrames
        self.isSpine = isSpine
        self.adjacent = adjacent
    }

    private enum CodingKeys: String, CodingKey {
        case tokenID, selectionType, timelineID, origin, clipIDs, sourceIdentities, revision
        case startFrame, endFrame, sourceDurationFrames, sourceRangeStartFrame, sourceRangeEndFrame
        case leftSourceDurationFrames, rightSourceDurationFrames, leftSourceRangeStartFrame, leftSourceRangeEndFrame
        case rightSourceRangeStartFrame, rightSourceRangeEndFrame, leftClipEndFrame, rightClipStartFrame
        case boundaryFrame, frameRate, handleBeforeFrames, handleAfterFrames, isSpine, adjacent
    }

    /// Missing origin is legacy/unverified input, never an implicit Final Cut claim.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tokenID = try container.decode(String.self, forKey: .tokenID)
        selectionType = try container.decode(SelectionType.self, forKey: .selectionType)
        timelineID = try container.decode(String.self, forKey: .timelineID)
        origin = try container.decodeIfPresent(SelectionOrigin.self, forKey: .origin) ?? .unverifiedExternal
        clipIDs = try container.decode([String].self, forKey: .clipIDs)
        sourceIdentities = try container.decode([SourceIdentity].self, forKey: .sourceIdentities)
        revision = try container.decode(String.self, forKey: .revision)
        startFrame = try container.decodeIfPresent(Int.self, forKey: .startFrame)
        endFrame = try container.decodeIfPresent(Int.self, forKey: .endFrame)
        sourceDurationFrames = try container.decodeIfPresent(Int.self, forKey: .sourceDurationFrames)
        sourceRangeStartFrame = try container.decodeIfPresent(Int.self, forKey: .sourceRangeStartFrame)
        sourceRangeEndFrame = try container.decodeIfPresent(Int.self, forKey: .sourceRangeEndFrame)
        leftSourceDurationFrames = try container.decodeIfPresent(Int.self, forKey: .leftSourceDurationFrames)
        rightSourceDurationFrames = try container.decodeIfPresent(Int.self, forKey: .rightSourceDurationFrames)
        leftSourceRangeStartFrame = try container.decodeIfPresent(Int.self, forKey: .leftSourceRangeStartFrame)
        leftSourceRangeEndFrame = try container.decodeIfPresent(Int.self, forKey: .leftSourceRangeEndFrame)
        rightSourceRangeStartFrame = try container.decodeIfPresent(Int.self, forKey: .rightSourceRangeStartFrame)
        rightSourceRangeEndFrame = try container.decodeIfPresent(Int.self, forKey: .rightSourceRangeEndFrame)
        leftClipEndFrame = try container.decodeIfPresent(Int.self, forKey: .leftClipEndFrame)
        rightClipStartFrame = try container.decodeIfPresent(Int.self, forKey: .rightClipStartFrame)
        boundaryFrame = try container.decodeIfPresent(Int.self, forKey: .boundaryFrame)
        frameRate = try container.decodeIfPresent(Int.self, forKey: .frameRate)
        handleBeforeFrames = try container.decode(Int.self, forKey: .handleBeforeFrames)
        handleAfterFrames = try container.decode(Int.self, forKey: .handleAfterFrames)
        isSpine = try container.decode(Bool.self, forKey: .isSpine)
        adjacent = try container.decode(Bool.self, forKey: .adjacent)
    }

    public var frameCount: Int? {
        guard let startFrame, let endFrame else { return nil }
        return endFrame - startFrame
    }

    public var sourceItems: [SourceIdentity] {
        get { sourceIdentities }
        set { sourceIdentities = newValue }
    }
}

public struct RequestInterpretation: Codable, Equatable, Sendable {
    public var originalRequest: String
    public var confidence: Double
    public var ambiguities: [String]
    public var effectID: EffectID?

    public init(originalRequest: String, confidence: Double, ambiguities: [String] = [], effectID: EffectID? = nil) {
        self.originalRequest = originalRequest
        self.confidence = confidence
        self.ambiguities = ambiguities
        self.effectID = effectID
    }
}

public struct CostEstimate: Codable, Equatable, Sendable {
    public var paid: Bool
    public var usd: Double
    public var provider: String
    public var estimatedUnits: Double?
    public var requiresMediaUpload: Bool

    public init(paid: Bool = false, usd: Double = 0, provider: String = "local", estimatedUnits: Double? = nil, requiresMediaUpload: Bool = false) {
        self.paid = paid
        self.usd = usd
        self.provider = provider
        self.estimatedUnits = estimatedUnits
        self.requiresMediaUpload = requiresMediaUpload
    }

    private enum CodingKeys: String, CodingKey { case paid, usd, provider, estimatedUnits, requiresMediaUpload }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        paid = try container.decode(Bool.self, forKey: .paid)
        usd = try container.decode(Double.self, forKey: .usd)
        provider = try container.decode(String.self, forKey: .provider)
        estimatedUnits = try container.decodeIfPresent(Double.self, forKey: .estimatedUnits)
        requiresMediaUpload = try container.decodeIfPresent(Bool.self, forKey: .requiresMediaUpload) ?? false
    }
}

public struct EditableProperty: Codable, Equatable, Sendable {
    public var name: String
    public var valueType: String
    public var minimum: Double?
    public var maximum: Double?
    public var defaultValue: ParameterValue?
    public var keyframeable: Bool

    public init(name: String, valueType: String = "number", minimum: Double? = nil, maximum: Double? = nil, defaultValue: ParameterValue? = nil, keyframeable: Bool = false) {
        self.name = name
        self.valueType = valueType
        self.minimum = minimum
        self.maximum = maximum
        self.defaultValue = defaultValue
        self.keyframeable = keyframeable
    }
}

public struct EffectPlan: Codable, Equatable, Sendable {
    public var schemaVersion: String
    public var operationID: UUID
    public var originalRequest: String
    public var confidence: Double
    public var ambiguities: [String]
    public var effectID: EffectID
    public var selectionToken: SelectionToken
    public var normalizedPoint: Target?
    public var parameters: [String: ParameterValue]
    public var representation: RepresentationClass
    public var editableProperties: [EditableProperty]
    public var generatedAssets: [GeneratedAssetDefinition]
    public var previewStrategy: String
    public var verification: [String]
    public var fallback: String
    public var cost: CostEstimate
    public var preconditionRevision: String

    public init(
        schemaVersion: String = SchemaVersion.v2_0.rawValue,
        operationID: UUID = UUID(),
        originalRequest: String,
        confidence: Double,
        ambiguities: [String] = [],
        effectID: EffectID,
        selectionToken: SelectionToken,
        normalizedPoint: Target? = nil,
        parameters: [String: ParameterValue] = [:],
        representation: RepresentationClass,
        editableProperties: [EditableProperty] = [],
        generatedAssets: [GeneratedAssetDefinition] = [],
        previewStrategy: String = "",
        verification: [String] = [],
        fallback: String,
        cost: CostEstimate = CostEstimate(),
        preconditionRevision: String
    ) {
        self.schemaVersion = schemaVersion
        self.operationID = operationID
        self.originalRequest = originalRequest
        self.confidence = confidence
        self.ambiguities = ambiguities
        self.effectID = effectID
        self.selectionToken = selectionToken
        self.normalizedPoint = normalizedPoint
        self.parameters = parameters
        self.representation = representation
        self.editableProperties = editableProperties
        self.generatedAssets = generatedAssets
        self.previewStrategy = previewStrategy
        self.verification = verification
        self.fallback = fallback
        self.cost = cost
        self.preconditionRevision = preconditionRevision
    }

    public var interpretation: RequestInterpretation {
        RequestInterpretation(originalRequest: originalRequest, confidence: confidence, ambiguities: ambiguities, effectID: effectID)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, operationID, originalRequest, confidence, ambiguities, effectID,
             selectionToken, normalizedPoint, parameters, representation, editableProperties,
             generatedAssets, previewStrategy, verification, fallback, cost, preconditionRevision
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(String.self, forKey: .schemaVersion)
        guard schemaVersion == SchemaVersion.v2_0.rawValue else {
            throw DecodingError.dataCorruptedError(forKey: .schemaVersion, in: container, debugDescription: "Current EffectPlan decoding accepts only schema 2.0; use EffectPlanAdmission for legacy quarantine")
        }
        operationID = try container.decode(UUID.self, forKey: .operationID)
        originalRequest = try container.decode(String.self, forKey: .originalRequest)
        confidence = try container.decode(Double.self, forKey: .confidence)
        ambiguities = try container.decode([String].self, forKey: .ambiguities)
        effectID = try container.decode(EffectID.self, forKey: .effectID)
        selectionToken = try container.decode(SelectionToken.self, forKey: .selectionToken)
        normalizedPoint = try container.decodeIfPresent(Target.self, forKey: .normalizedPoint)
        parameters = try container.decode([String: ParameterValue].self, forKey: .parameters)
        representation = try container.decode(RepresentationClass.self, forKey: .representation)
        editableProperties = try container.decode([EditableProperty].self, forKey: .editableProperties)
        generatedAssets = try container.decodeIfPresent([GeneratedAssetDefinition].self, forKey: .generatedAssets) ?? []
        previewStrategy = try container.decodeIfPresent(String.self, forKey: .previewStrategy) ?? ""
        verification = try container.decodeIfPresent([String].self, forKey: .verification) ?? []
        fallback = try container.decode(String.self, forKey: .fallback)
        cost = try container.decode(CostEstimate.self, forKey: .cost)
        preconditionRevision = try container.decode(String.self, forKey: .preconditionRevision)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(operationID, forKey: .operationID)
        try container.encode(originalRequest, forKey: .originalRequest)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(ambiguities, forKey: .ambiguities)
        try container.encode(effectID, forKey: .effectID)
        try container.encode(selectionToken, forKey: .selectionToken)
        try container.encodeIfPresent(normalizedPoint, forKey: .normalizedPoint)
        try container.encode(parameters, forKey: .parameters)
        try container.encode(representation, forKey: .representation)
        try container.encode(editableProperties, forKey: .editableProperties)
        try container.encode(generatedAssets, forKey: .generatedAssets)
        try container.encode(previewStrategy, forKey: .previewStrategy)
        try container.encode(verification, forKey: .verification)
        try container.encode(fallback, forKey: .fallback)
        try container.encode(cost, forKey: .cost)
        try container.encode(preconditionRevision, forKey: .preconditionRevision)
    }
}

public struct ParameterDefinition: Codable, Equatable, Sendable {
    public var name: String
    public var type: String
    public var defaultValue: ParameterValue?
    public var minimum: Double?
    public var maximum: Double?
    public var allowedValues: [ParameterValue]?
    public var description: String?
    /// Presentation and liveness are registry facts, never inferred from the
    /// existence of a JSON parameter.  Old registries decode fail-closed.
    public var presentation: ParameterPresentation?

    public init(name: String, type: String, defaultValue: ParameterValue? = nil, minimum: Double? = nil, maximum: Double? = nil, allowedValues: [ParameterValue]? = nil, description: String? = nil, presentation: ParameterPresentation? = nil) {
        self.name = name
        self.type = type
        self.defaultValue = defaultValue
        self.minimum = minimum
        self.maximum = maximum
        self.allowedValues = allowedValues
        self.description = description
        self.presentation = presentation
    }
}

/// Whether a parameter can truthfully be changed in the current construction.
public enum ParameterExposure: String, Codable, CaseIterable, Sendable {
    case runtimeEditable = "runtime_editable"
    case approximateEditable = "approximate_editable"
    case invariantReadOnly = "invariant_read_only"
    case unsupportedReadOnly = "unsupported_read_only"

    public var isEditable: Bool { self == .runtimeEditable || self == .approximateEditable }
}

public enum ParameterGroup: String, Codable, CaseIterable, Sendable {
    case basic, advanced
    case `internal`
}

public struct ParameterPresentation: Codable, Equatable, Sendable {
    public var label: String
    public var explanation: String
    public var units: String?
    public var group: ParameterGroup
    public var exposure: ParameterExposure

    public init(label: String, explanation: String, units: String? = nil, group: ParameterGroup = .basic, exposure: ParameterExposure) {
        self.label = label; self.explanation = explanation; self.units = units; self.group = group; self.exposure = exposure
    }

    /// Missing metadata is deliberately read-only. This allows a caller to
    /// inspect a legacy definition without accidentally offering an edit.
    public static let failClosed = ParameterPresentation(label: "Unavailable parameter", explanation: "This registry does not declare a supported control.", group: .`internal`, exposure: .unsupportedReadOnly)
}

public struct GeneratedAssetDefinition: Codable, Equatable, Sendable {
    public var kind: String
    public var format: String
    public var alpha: Bool
    public var deterministic: Bool

    public init(kind: String, format: String, alpha: Bool = false, deterministic: Bool = true) {
        self.kind = kind; self.format = format; self.alpha = alpha; self.deterministic = deterministic
    }
}

public struct EffectDefinition: Codable, Equatable, Sendable {
    public var identifier: EffectID
    public var name: String
    public var aliases: [String]
    public var requiredSelection: SelectionType
    public var inputCount: Int
    public var representation: RepresentationClass
    public var parameters: [ParameterDefinition]
    public var backend: Backend
    public var editableProperties: [EditableProperty]
    public var generatedAssets: [GeneratedAssetDefinition]
    public var preview: String
    public var verification: [String]
    public var fallback: String

    public init(identifier: EffectID, name: String, aliases: [String], requiredSelection: SelectionType, inputCount: Int, representation: RepresentationClass, parameters: [ParameterDefinition], backend: Backend, editableProperties: [EditableProperty], generatedAssets: [GeneratedAssetDefinition], preview: String, verification: [String], fallback: String) {
        self.identifier = identifier; self.name = name; self.aliases = aliases; self.requiredSelection = requiredSelection; self.inputCount = inputCount; self.representation = representation; self.parameters = parameters; self.backend = backend; self.editableProperties = editableProperties; self.generatedAssets = generatedAssets; self.preview = preview; self.verification = verification; self.fallback = fallback
    }
}

public struct RollbackRecord: Codable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable { case pending, completed, failed, notRequired = "not-required" }
    public var operationID: UUID
    public var status: Status
    public var snapshotHash: String?
    public var completedAt: Date?
    public var error: String?

    public init(operationID: UUID, status: Status = .pending, snapshotHash: String? = nil, completedAt: Date? = nil, error: String? = nil) {
        self.operationID = operationID; self.status = status; self.snapshotHash = snapshotHash; self.completedAt = completedAt; self.error = error
    }
}

public struct OperationRecord: Codable, Equatable, Sendable {
    public var operationID: UUID
    public var planHash: String
    public var preconditionRevision: String
    public var beforeSnapshotHash: String
    public var expectedAfterSnapshotHash: String?
    public var createdModelIdentities: [String]
    public var generatedAssetHashes: [String]
    public var generatedAssetParameters: [String: ParameterValue]
    public var rollback: RollbackRecord
    public var createdAt: Date

    public init(operationID: UUID, planHash: String, preconditionRevision: String, beforeSnapshotHash: String, expectedAfterSnapshotHash: String? = nil, createdModelIdentities: [String] = [], generatedAssetHashes: [String] = [], generatedAssetParameters: [String: ParameterValue] = [:], rollback: RollbackRecord, createdAt: Date = Date()) {
        self.operationID = operationID; self.planHash = planHash; self.preconditionRevision = preconditionRevision; self.beforeSnapshotHash = beforeSnapshotHash; self.expectedAfterSnapshotHash = expectedAfterSnapshotHash; self.createdModelIdentities = createdModelIdentities; self.generatedAssetHashes = generatedAssetHashes; self.generatedAssetParameters = generatedAssetParameters; self.rollback = rollback; self.createdAt = createdAt
    }
}
