import CoreFoundation
import Foundation

/// The wire contract for the isolated planner helper.  The helper is a
/// deliberately small, one-shot JSON process: it accepts one request and
/// emits one response.  The types below are kept separate from the existing
/// CLI models so the runtime-facing contract can remain closed and snake_case
/// without changing the legacy command line surface.
public enum PlannerHelperErrorCode: String, Codable, CaseIterable, Sendable, Error {
    case invalidArguments = "invalid_arguments"
    case inputTooLarge = "input_too_large"
    case malformedJSON = "malformed_json"
    case multipleJSONValues = "multiple_json_values"
    case unknownField = "unknown_field"
    case unsupportedSchemaVersion = "unsupported_schema_version"
    case invalidEnvelope = "invalid_envelope"
    case invalidOperation = "invalid_operation"
    case invalidRequest = "invalid_request"
    case unsafeRequest = "unsafe_request"
    case noMatch = "no_match"
    case ambiguousRequest = "ambiguous_request"
    case targetRequired = "target_required"
    case invalidTarget = "invalid_target"
    case invalidSelection = "invalid_selection"
    case staleSelection = "stale_selection"
    case resourceMissing = "resource_missing"
    case resourceTampered = "resource_tampered"
    case registryInvalid = "registry_invalid"
    case schemaInvalid = "schema_invalid"
    case planInvalid = "plan_invalid"
    case internalError = "internal_error"
}

/// Public, stable error payload.  Messages are intentionally short and do
/// not contain input values, file paths, environment data, or underlying
/// parser diagnostics.
public struct PlannerHelperError: Codable, Equatable, Sendable {
    public let code: PlannerHelperErrorCode
    public let message: String

    public init(code: PlannerHelperErrorCode, message: String? = nil) {
        self.code = code
        self.message = PlannerHelperError.safeMessage(message ?? code.defaultMessage)
    }

    private static func safeMessage(_ value: String) -> String {
        let bounded = String(value.unicodeScalars.prefix(160))
        let sanitized = bounded.unicodeScalars.map { scalar -> Character in
            switch scalar.value {
            case 0x20...0x7e: return Character(String(scalar))
            default: return "?"
            }
        }
        let result = String(sanitized)
        return result.isEmpty ? "planner helper request failed" : result
    }
}

private extension PlannerHelperErrorCode {
    var defaultMessage: String {
        switch self {
        case .invalidArguments: return "planner helper accepts no arguments"
        case .inputTooLarge: return "request exceeds the input byte limit"
        case .malformedJSON: return "request is not valid JSON"
        case .multipleJSONValues: return "exactly one JSON value is required"
        case .unknownField: return "request contains an unknown field"
        case .unsupportedSchemaVersion: return "request schema version is unsupported"
        case .invalidEnvelope: return "request envelope is invalid"
        case .invalidOperation: return "operation identifier is invalid"
        case .invalidRequest: return "request text is invalid"
        case .unsafeRequest: return "request contains unsupported command syntax"
        case .noMatch: return "request did not match a supported workflow"
        case .ambiguousRequest: return "ambiguous requests fail closed"
        case .targetRequired: return "this workflow requires a confirmed target"
        case .invalidTarget: return "confirmed target is invalid"
        case .invalidSelection: return "selection token is invalid"
        case .staleSelection: return "selection token is stale"
        case .resourceMissing: return "planner helper resources are missing"
        case .resourceTampered: return "planner helper resources failed integrity checks"
        case .registryInvalid: return "planner helper registry is invalid"
        case .schemaInvalid: return "planner helper schema is invalid"
        case .planInvalid: return "constructed plan failed validation"
        case .internalError: return "planner helper failed"
        }
    }
}

/// Request text is nested to make it explicit that the helper receives the
/// caller's original command and does not synthesize a command or backend
/// method.
public struct PlannerHelperRequestText: Codable, Equatable, Sendable {
    public let originalText: String

    public init(originalText: String) { self.originalText = originalText }

    private enum CodingKeys: String, CodingKey, CaseIterable { case originalText = "original_text" }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try container.rejectUnknownFields()
        originalText = try container.decode(String.self, forKey: .originalText)
        guard !originalText.isEmpty else { throw PlannerHelperInputError.invalidRequest }
    }
}

/// A confirmed normalized target.  The wire type is intentionally narrower
/// than `Target`: no arbitrary coordinate-space or confirmation flag can be
/// supplied by a caller.
public struct PlannerHelperTarget: Codable, Equatable, Sendable {
    public let type: String
    public let normalizedX: Double
    public let normalizedY: Double

    public init(normalizedX: Double, normalizedY: Double) {
        self.type = "confirmed_point"
        self.normalizedX = normalizedX
        self.normalizedY = normalizedY
    }

    fileprivate var core: Target {
        Target(x: normalizedX, y: normalizedY, coordinateSpace: "normalized-frame", confirmed: true)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case type
        case normalizedX = "normalized_x"
        case normalizedY = "normalized_y"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try container.rejectUnknownFields()
        type = try container.decode(String.self, forKey: .type)
        normalizedX = try container.decode(Double.self, forKey: .normalizedX)
        normalizedY = try container.decode(Double.self, forKey: .normalizedY)
        guard type == "confirmed_point", normalizedX.isFinite, normalizedY.isFinite,
              (0...1).contains(normalizedX), (0...1).contains(normalizedY) else {
            throw PlannerHelperInputError.invalidTarget
        }
    }
}

/// Source identity in the helper's closed selection-token wire form.
public struct PlannerHelperSourceIdentity: Codable, Equatable, Sendable {
    public let itemID: String
    public let canonicalPath: String
    public let sha256: String

    public init(itemID: String, canonicalPath: String, sha256: String) {
        self.itemID = itemID
        self.canonicalPath = canonicalPath
        self.sha256 = sha256
    }

    fileprivate init(core: SourceIdentity) {
        self.init(itemID: core.itemID, canonicalPath: core.canonicalPath, sha256: core.sha256)
    }

    fileprivate var core: SourceIdentity {
        SourceIdentity(itemID: itemID, canonicalPath: canonicalPath, sha256: sha256)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case itemID = "item_id"
        case canonicalPath = "canonical_path"
        case sha256
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try container.rejectUnknownFields()
        itemID = try container.decode(String.self, forKey: .itemID)
        canonicalPath = try container.decode(String.self, forKey: .canonicalPath)
        sha256 = try container.decode(String.self, forKey: .sha256)
    }
}

/// Snake_case, closed representation of the caller-supplied `SelectionToken`.
/// Every field is copied into the core token; no timing, adjacency, handle,
/// source, or revision value is inferred by the helper.
public struct PlannerHelperSelection: Codable, Equatable, Sendable {
    public let tokenID: String
    public let selectionType: SelectionType
    public let timelineID: String
    public let origin: SelectionOrigin
    public let clipIDs: [String]
    public let sourceIdentities: [PlannerHelperSourceIdentity]
    public let revision: String
    public let startFrame: Int?
    public let endFrame: Int?
    public let sourceDurationFrames: Int?
    public let sourceRangeStartFrame: Int?
    public let sourceRangeEndFrame: Int?
    public let leftSourceDurationFrames: Int?
    public let rightSourceDurationFrames: Int?
    public let leftSourceRangeStartFrame: Int?
    public let leftSourceRangeEndFrame: Int?
    public let rightSourceRangeStartFrame: Int?
    public let rightSourceRangeEndFrame: Int?
    public let leftClipEndFrame: Int?
    public let rightClipStartFrame: Int?
    public let boundaryFrame: Int?
    public let frameRate: Int?
    public let handleBeforeFrames: Int
    public let handleAfterFrames: Int
    public let isSpine: Bool
    public let adjacent: Bool

    public init(core: SelectionToken) {
        tokenID = core.tokenID
        selectionType = core.selectionType
        timelineID = core.timelineID
        origin = core.origin
        clipIDs = core.clipIDs
        sourceIdentities = core.sourceIdentities.map(PlannerHelperSourceIdentity.init(core:))
        revision = core.revision
        startFrame = core.startFrame
        endFrame = core.endFrame
        sourceDurationFrames = core.sourceDurationFrames
        sourceRangeStartFrame = core.sourceRangeStartFrame
        sourceRangeEndFrame = core.sourceRangeEndFrame
        leftSourceDurationFrames = core.leftSourceDurationFrames
        rightSourceDurationFrames = core.rightSourceDurationFrames
        leftSourceRangeStartFrame = core.leftSourceRangeStartFrame
        leftSourceRangeEndFrame = core.leftSourceRangeEndFrame
        rightSourceRangeStartFrame = core.rightSourceRangeStartFrame
        rightSourceRangeEndFrame = core.rightSourceRangeEndFrame
        leftClipEndFrame = core.leftClipEndFrame
        rightClipStartFrame = core.rightClipStartFrame
        boundaryFrame = core.boundaryFrame
        frameRate = core.frameRate
        handleBeforeFrames = core.handleBeforeFrames
        handleAfterFrames = core.handleAfterFrames
        isSpine = core.isSpine
        adjacent = core.adjacent
    }

    public init(
        tokenID: String,
        selectionType: SelectionType,
        timelineID: String,
        origin: SelectionOrigin = .unverifiedExternal,
        clipIDs: [String],
        sourceIdentities: [PlannerHelperSourceIdentity],
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
        handleBeforeFrames: Int,
        handleAfterFrames: Int,
        isSpine: Bool,
        adjacent: Bool
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

    fileprivate var core: SelectionToken {
        SelectionToken(
            tokenID: tokenID,
            selectionType: selectionType,
            timelineID: timelineID,
            origin: origin,
            clipIDs: clipIDs,
            sourceIdentities: sourceIdentities.map(\.core),
            revision: revision,
            startFrame: startFrame,
            endFrame: endFrame,
            sourceDurationFrames: sourceDurationFrames,
            sourceRangeStartFrame: sourceRangeStartFrame,
            sourceRangeEndFrame: sourceRangeEndFrame,
            leftSourceDurationFrames: leftSourceDurationFrames,
            rightSourceDurationFrames: rightSourceDurationFrames,
            leftSourceRangeStartFrame: leftSourceRangeStartFrame,
            leftSourceRangeEndFrame: leftSourceRangeEndFrame,
            rightSourceRangeStartFrame: rightSourceRangeStartFrame,
            rightSourceRangeEndFrame: rightSourceRangeEndFrame,
            leftClipEndFrame: leftClipEndFrame,
            rightClipStartFrame: rightClipStartFrame,
            boundaryFrame: boundaryFrame,
            frameRate: frameRate,
            handleBeforeFrames: handleBeforeFrames,
            handleAfterFrames: handleAfterFrames,
            isSpine: isSpine,
            adjacent: adjacent
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case tokenID = "token_id"
        case selectionType = "selection_type"
        case timelineID = "timeline_id"
        case origin
        case clipIDs = "clip_ids"
        case sourceIdentities = "source_identities"
        case revision
        case startFrame = "start_frame"
        case endFrame = "end_frame"
        case sourceDurationFrames = "source_duration_frames"
        case sourceRangeStartFrame = "source_range_start_frame"
        case sourceRangeEndFrame = "source_range_end_frame"
        case leftSourceDurationFrames = "left_source_duration_frames"
        case rightSourceDurationFrames = "right_source_duration_frames"
        case leftSourceRangeStartFrame = "left_source_range_start_frame"
        case leftSourceRangeEndFrame = "left_source_range_end_frame"
        case rightSourceRangeStartFrame = "right_source_range_start_frame"
        case rightSourceRangeEndFrame = "right_source_range_end_frame"
        case leftClipEndFrame = "left_clip_end_frame"
        case rightClipStartFrame = "right_clip_start_frame"
        case boundaryFrame = "boundary_frame"
        case frameRate = "frame_rate"
        case handleBeforeFrames = "handle_before_frames"
        case handleAfterFrames = "handle_after_frames"
        case isSpine = "is_spine"
        case adjacent
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try container.rejectUnknownFields()
        tokenID = try container.decode(String.self, forKey: .tokenID)
        let selectionTypeText = try container.decode(String.self, forKey: .selectionType)
        guard let parsedSelectionType = SelectionType(rawValue: selectionTypeText) else {
            throw PlannerHelperInputError.invalidSelection
        }
        selectionType = parsedSelectionType
        timelineID = try container.decode(String.self, forKey: .timelineID)
        origin = try container.decodeIfPresent(SelectionOrigin.self, forKey: .origin) ?? .unverifiedExternal
        clipIDs = try container.decode([String].self, forKey: .clipIDs)
        sourceIdentities = try container.decode([PlannerHelperSourceIdentity].self, forKey: .sourceIdentities)
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
}

public struct PlannerHelperRequestEnvelope: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let operationID: UUID
    public let request: PlannerHelperRequestText
    public let selection: PlannerHelperSelection
    public let target: PlannerHelperTarget?

    public init(schemaVersion: String = "1.0", operationID: UUID, request: PlannerHelperRequestText, selection: PlannerHelperSelection, target: PlannerHelperTarget? = nil) {
        self.schemaVersion = schemaVersion
        self.operationID = operationID
        self.request = request
        self.selection = selection
        self.target = target
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case operationID = "operation_id"
        case request
        case selection
        case target
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try container.rejectUnknownFields()
        schemaVersion = try container.decode(String.self, forKey: .schemaVersion)
        guard schemaVersion == "1.0" else { throw PlannerHelperInputError.unsupportedSchemaVersion }
        let operationText = try container.decode(String.self, forKey: .operationID)
        guard let operation = UUID(uuidString: operationText) else { throw PlannerHelperInputError.invalidOperation }
        operationID = operation
        request = try container.decode(PlannerHelperRequestText.self, forKey: .request)
        selection = try container.decode(PlannerHelperSelection.self, forKey: .selection)
        // A target is required as a key, but may be explicitly null.  This
        // prevents the helper from silently inventing target state.
        target = try container.decode(PlannerHelperTarget?.self, forKey: .target)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(operationID.uuidString, forKey: .operationID)
        try container.encode(request, forKey: .request)
        try container.encode(selection, forKey: .selection)
        // The key is mandatory even when no target was confirmed; `null` is
        // the explicit representation of that absence on the wire.
        try container.encode(target, forKey: .target)
    }
}

public struct PlannerHelperResponseEnvelope: Codable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable { case ok, error }

    public let schemaVersion: String
    public let status: Status
    public let plan: EffectPlan?
    public let error: PlannerHelperError?

    public static func success(_ plan: EffectPlan) -> PlannerHelperResponseEnvelope {
        PlannerHelperResponseEnvelope(schemaVersion: "1.0", status: .ok, plan: plan, error: nil)
    }

    public static func failure(_ error: PlannerHelperError) -> PlannerHelperResponseEnvelope {
        PlannerHelperResponseEnvelope(schemaVersion: "1.0", status: .error, plan: nil, error: error)
    }

    private init(schemaVersion: String, status: Status, plan: EffectPlan?, error: PlannerHelperError?) {
        self.schemaVersion = schemaVersion
        self.status = status
        self.plan = plan
        self.error = error
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case status
        case plan
        case error
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try container.rejectUnknownFields()
        schemaVersion = try container.decode(String.self, forKey: .schemaVersion)
        status = try container.decode(Status.self, forKey: .status)
        plan = try container.decodeIfPresent(EffectPlan.self, forKey: .plan)
        error = try container.decodeIfPresent(PlannerHelperError.self, forKey: .error)
        guard (status == .ok && plan != nil && error == nil) || (status == .error && plan == nil && error != nil) else {
            throw PlannerHelperInputError.invalidEnvelope
        }
    }
}

/// Canonical output encoding for the runtime wire contract.  Foundation's
/// generic `.convertToSnakeCase` strategy splits initialisms such as `clipIDs`
/// into `clip_i_ds`; the explicit mapping below keeps the contract stable
/// (`clip_ids`, `operation_id`, and so on) while leaving registry parameter-map
/// keys untouched.
public enum PlannerHelperWireCodec {
    public static func encode(_ response: PlannerHelperResponseEnvelope) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let canonical = try encoder.encode(response)
        let object = try JSONSerialization.jsonObject(with: canonical, options: [.fragmentsAllowed])
        let wire = transform(object)
        guard JSONSerialization.isValidJSONObject(wire) else { throw PlannerHelperWireError.encodingFailed }
        let wireEncoder = JSONEncoder()
        wireEncoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try wireEncoder.encode(AnyEncodable(value: wire))
    }

    private static let keys: [String: String] = [
        "schemaVersion": "schema_version",
        "operationID": "operation_id",
        "originalRequest": "original_request",
        "effectID": "effect_id",
        "selectionToken": "selection_token",
        "normalizedPoint": "normalized_point",
        "editableProperties": "editable_properties",
        "generatedAssets": "generated_assets",
        "previewStrategy": "preview_strategy",
        "preconditionRevision": "precondition_revision",
        "selectionType": "selection_type",
        "timelineID": "timeline_id",
        "clipIDs": "clip_ids",
        "sourceIdentities": "source_identities",
        "tokenID": "token_id",
        "startFrame": "start_frame",
        "endFrame": "end_frame",
        "sourceDurationFrames": "source_duration_frames",
        "sourceRangeStartFrame": "source_range_start_frame",
        "sourceRangeEndFrame": "source_range_end_frame",
        "leftSourceDurationFrames": "left_source_duration_frames",
        "rightSourceDurationFrames": "right_source_duration_frames",
        "leftSourceRangeStartFrame": "left_source_range_start_frame",
        "leftSourceRangeEndFrame": "left_source_range_end_frame",
        "rightSourceRangeStartFrame": "right_source_range_start_frame",
        "rightSourceRangeEndFrame": "right_source_range_end_frame",
        "leftClipEndFrame": "left_clip_end_frame",
        "rightClipStartFrame": "right_clip_start_frame",
        "boundaryFrame": "boundary_frame",
        "frameRate": "frame_rate",
        "handleBeforeFrames": "handle_before_frames",
        "handleAfterFrames": "handle_after_frames",
        "isSpine": "is_spine",
        "canonicalPath": "canonical_path",
        "itemID": "item_id",
        "coordinateSpace": "coordinate_space",
        "valueType": "value_type",
        "defaultValue": "default_value",
        "requiresMediaUpload": "requires_media_upload",
        "estimatedUnits": "estimated_units"
    ]

    private static func transform(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            var result: [String: Any] = [:]
            for (key, value) in dictionary {
                let transformedKey = keys[key] ?? key
                result[transformedKey] = transform(value)
            }
            return result
        }
        if let array = value as? [Any] { return array.map(transform) }
        return value
    }
}

public enum PlannerHelperWireError: Error, Equatable, Sendable { case encodingFailed }

private struct PlannerHelperDynamicKey: CodingKey {
    let stringValue: String
    init?(stringValue: String) { self.stringValue = stringValue }
    let intValue: Int? = nil
    init?(intValue: Int) { return nil }
}

private struct AnyEncodable: Encodable {
    let value: Any

    func encode(to encoder: Encoder) throws {
        if value is NSNull {
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        } else if let value = value as? String {
            var container = encoder.singleValueContainer()
            try container.encode(value)
        } else if let value = value as? NSNumber {
            var container = encoder.singleValueContainer()
            // JSONSerialization represents both JSON booleans and numbers as
            // NSNumber.  `objCType == "c"` is not a safe discriminator: it
            // also classifies legitimate 0/1 numeric values as booleans on
            // Darwin.  CoreFoundation gives JSON booleans their own singleton
            // type, preserving the helper's typed wire contract exactly.
            if CFGetTypeID(value) == CFBooleanGetTypeID() { try container.encode(value.boolValue) }
            else if value.doubleValue.rounded() == value.doubleValue, value.doubleValue <= Double(Int.max), value.doubleValue >= Double(Int.min) {
                try container.encode(value.intValue)
            } else {
                try container.encode(value.doubleValue)
            }
        } else if let value = value as? Bool {
            var container = encoder.singleValueContainer()
            try container.encode(value)
        } else if let value = value as? [String: Any] {
            var container = encoder.container(keyedBy: PlannerHelperDynamicKey.self)
            for key in value.keys.sorted() {
                guard let codingKey = PlannerHelperDynamicKey(stringValue: key), let nested = value[key] else { continue }
                try container.encode(AnyEncodable(value: nested), forKey: codingKey)
            }
        } else if let value = value as? [Any] {
            var container = encoder.unkeyedContainer()
            for nested in value { try container.encode(AnyEncodable(value: nested)) }
        } else {
            throw PlannerHelperWireError.encodingFailed
        }
    }
}

private enum PlannerHelperInputError: Error {
    case invalidRequest
    case invalidTarget
    case unsupportedSchemaVersion
    case unknownField
    case invalidEnvelope
    case invalidOperation
    case invalidSelection
}

private extension KeyedDecodingContainer where Key: CaseIterable {
    func rejectUnknownFields() throws {
        // CodingKey's stringValue is already the exact snake_case wire name
        // for every helper type.  A key not represented by the type is never
        // ignored: fail closed before any planner logic runs.
        let allowed = Set(Key.allCases.map(\.stringValue))
        guard allKeys.allSatisfy({ allowed.contains($0.stringValue) }) else {
            throw PlannerHelperInputError.unknownField
        }
    }
}

/// Resource loading is explicit and bundle-rooted.  No current-directory or
/// repository discovery is performed by this loader.
public struct PlannerHelperResources {
    public let rootURL: URL
    public let registry: EffectRegistry
    public let schemaValidator: PlanSchemaValidator

    private static let expectedHashes: [String: String] = [
        "registry/effects/look.old_television.json": "01234fcffdebfb7a7cf57aa171f2253f33169b5ed42edb2bb3ccdd31e9dd9a9f",
        "registry/effects/motion.living_still.json": "70224f52497c745fd32326ef34f77cfdc11687f7ceb862a1f463c09e1239e38f",
        "registry/effects/native.targeted_rotate_zoom.json": "20d511f53cf1f5e33d554357e4806ded15b6de564a4912558fb4ff05e5d57cbd",
        "registry/effects/transition.natural_dissolve.json": "30686fe7d71e618a3ecc98ef4658c2b45e1e1f401bc5f00c74da4b80b9d3a573",
        "schemas/effect-plan.schema.json": "4387255973853dabba3d1ab62eb94bbb7e8e649a5516733ea3508a586520bf01"
    ]

    public init(rootURL: URL) throws {
        let root = rootURL.standardizedFileURL
        self.rootURL = root
        let registryURL = root.appendingPathComponent("registry/effects", isDirectory: true)
        let schemaURL = root.appendingPathComponent("schemas/effect-plan.schema.json")
        try Self.validateRegularResource(registryURL, directory: true)
        try Self.validateRegularResource(schemaURL, directory: false)

        let files = try FileManager.default.contentsOfDirectory(at: registryURL, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles])
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard files.count == EffectID.allCases.count else { throw PlannerHelperResourceError.registryInvalid }
        for file in files {
            let relative = "registry/effects/\(file.lastPathComponent)"
            guard let expected = Self.expectedHashes[relative], try ContentHasher.sha256File(file) == expected else {
                throw PlannerHelperResourceError.resourceTampered
            }
        }
        guard let schemaExpected = Self.expectedHashes["schemas/effect-plan.schema.json"], try ContentHasher.sha256File(schemaURL) == schemaExpected else {
            throw PlannerHelperResourceError.resourceTampered
        }

        do {
            let loadedRegistry = try EffectRegistry.load(from: registryURL)
            guard loadedRegistry.all.count == EffectID.allCases.count,
                  Set(loadedRegistry.all.map(\.identifier)) == Set(EffectID.allCases) else {
                throw PlannerHelperResourceError.registryInvalid
            }
            registry = loadedRegistry
        } catch let error as PlannerHelperResourceError {
            throw error
        } catch {
            throw PlannerHelperResourceError.registryInvalid
        }
        do {
            schemaValidator = try PlanSchemaValidator(schemaURL: schemaURL)
        } catch {
            throw PlannerHelperResourceError.schemaInvalid
        }
    }

    private static func validateRegularResource(_ url: URL, directory: Bool) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { throw PlannerHelperResourceError.resourceMissing }
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else { throw PlannerHelperResourceError.resourceTampered }
        if directory {
            guard values.isDirectory == true else { throw PlannerHelperResourceError.resourceMissing }
        } else {
            guard values.isRegularFile == true else { throw PlannerHelperResourceError.resourceMissing }
        }
    }
}

public enum PlannerHelperResourceError: Error, Equatable, Sendable {
    case resourceMissing
    case resourceTampered
    case registryInvalid
    case schemaInvalid
}

public enum PlannerHelperLimits {
    public static let maxInputBytes = 256 * 1024
    public static let maxRequestTextScalars = 32 * 1024
}

/// Reusable engine shared by the executable and unit tests.  It does not read
/// stdin, inspect the environment, resolve caller paths, or invoke a backend.
public struct PlannerHelperEngine {
    public let resources: PlannerHelperResources

    public init(resources: PlannerHelperResources) { self.resources = resources }

    public func handle(data: Data) -> PlannerHelperResponseEnvelope {
        guard data.count <= PlannerHelperLimits.maxInputBytes else { return .failure(PlannerHelperError(code: .inputTooLarge)) }
        do {
            guard !data.isEmpty else { throw PlannerHelperInputError.invalidRequest }
            guard String(data: data, encoding: .utf8) != nil else { throw PlannerHelperInputError.invalidRequest }
            try Self.validateSingleJSONValue(data)
            let decoder = JSONDecoder()
            let envelope = try decoder.decode(PlannerHelperRequestEnvelope.self, from: data)
            return try handle(envelope: envelope)
        } catch let error as PlannerHelperErrorCode {
            return .failure(PlannerHelperError(code: error))
        } catch let error as PlannerHelperInputError {
            return .failure(PlannerHelperError(code: Self.code(for: error)))
        } catch let error as DecodingError {
            return .failure(PlannerHelperError(code: Self.code(for: error)))
        } catch {
            return Self.errorResponse(for: error)
        }
    }

    public func handle(envelope: PlannerHelperRequestEnvelope) throws -> PlannerHelperResponseEnvelope {
        guard envelope.schemaVersion == "1.0" else { return .failure(PlannerHelperError(code: .unsupportedSchemaVersion)) }
        guard envelope.request.originalText.unicodeScalars.count <= PlannerHelperLimits.maxRequestTextScalars else {
            return .failure(PlannerHelperError(code: .invalidRequest))
        }
        do {
            let planner = DeterministicPlanner(registry: resources.registry)
            let plan = try planner.plan(
                request: envelope.request.originalText,
                selection: envelope.selection.core,
                target: envelope.target?.core,
                operationID: envelope.operationID
            )
            // Plan construction validates policy metadata.  The independent
            // serialized schema check is still mandatory before success.
            let canonicalEncoder = JSONEncoder()
            canonicalEncoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            let canonicalData = try canonicalEncoder.encode(plan)
            try resources.schemaValidator.validate(canonicalData)
            let roundTrip = try JSONDecoder().decode(EffectPlan.self, from: canonicalData)
            try PlanValidator(registry: resources.registry).validate(roundTrip)
            return .success(roundTrip)
        } catch {
            return Self.errorResponse(for: error)
        }
    }

    private static func validateSingleJSONValue(_ data: Data) throws {
        guard let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            // Distinguish a second complete value from malformed JSON without
            // exposing Foundation's diagnostics or any input bytes.
            if hasTrailingJSONValue(data) { throw PlannerHelperErrorCode.multipleJSONValues }
            throw PlannerHelperErrorCode.malformedJSON
        }
        guard let envelope = object as? [String: Any] else { throw PlannerHelperErrorCode.invalidEnvelope }
        try validateInputKeys(envelope)
    }

    private static func validateInputKeys(_ envelope: [String: Any]) throws {
        try rejectUnknown(envelope, allowed: ["schema_version", "operation_id", "request", "selection", "target"])
        guard let request = envelope["request"] as? [String: Any], let selection = envelope["selection"] as? [String: Any] else { return }
        try rejectUnknown(request, allowed: ["original_text"])
        try rejectUnknown(selection, allowed: [
            "token_id", "selection_type", "timeline_id", "origin", "clip_ids", "source_identities", "revision",
            "start_frame", "end_frame", "source_duration_frames", "source_range_start_frame",
            "source_range_end_frame", "left_source_duration_frames", "right_source_duration_frames",
            "left_source_range_start_frame", "left_source_range_end_frame", "right_source_range_start_frame",
            "right_source_range_end_frame", "left_clip_end_frame", "right_clip_start_frame", "boundary_frame",
            "frame_rate", "handle_before_frames", "handle_after_frames", "is_spine", "adjacent"
        ])
        if let sourceIdentities = selection["source_identities"] as? [Any] {
            for source in sourceIdentities {
                guard let source = source as? [String: Any] else { continue }
                try rejectUnknown(source, allowed: ["item_id", "canonical_path", "sha256"])
            }
        }
        if let target = envelope["target"] as? [String: Any] {
            try rejectUnknown(target, allowed: ["type", "normalized_x", "normalized_y"])
        }
    }

    private static func rejectUnknown(_ object: [String: Any], allowed: Set<String>) throws {
        guard object.keys.allSatisfy({ allowed.contains($0) }) else { throw PlannerHelperErrorCode.unknownField }
    }

    private static func hasTrailingJSONValue(_ data: Data) -> Bool {
        let bytes = Array(data)
        guard let first = bytes.first(where: { !Self.isWhitespace($0) }) else { return false }
        guard first == 0x7b || first == 0x5b else { return false }
        var depth = 0
        var inString = false
        var escaped = false
        var ended = false
        for byte in bytes {
            if ended {
                if !Self.isWhitespace(byte) { return true }
                continue
            }
            if inString {
                if escaped { escaped = false }
                else if byte == 0x5c { escaped = true }
                else if byte == 0x22 { inString = false }
                continue
            }
            if byte == 0x22 { inString = true; continue }
            if byte == 0x7b || byte == 0x5b { depth += 1 }
            if byte == 0x7d || byte == 0x5d {
                depth -= 1
                if depth == 0 { ended = true }
            }
        }
        return false
    }

    private static func isWhitespace(_ byte: UInt8) -> Bool {
        byte == 0x20 || byte == 0x09 || byte == 0x0a || byte == 0x0d
    }

    private static func code(for error: PlannerHelperInputError) -> PlannerHelperErrorCode {
        switch error {
        case .invalidRequest: return .invalidRequest
        case .invalidTarget: return .invalidTarget
        case .unsupportedSchemaVersion: return .unsupportedSchemaVersion
        case .unknownField: return .unknownField
        case .invalidEnvelope: return .invalidEnvelope
        case .invalidOperation: return .invalidOperation
        case .invalidSelection: return .invalidSelection
        }
    }

    private static func code(for error: DecodingError) -> PlannerHelperErrorCode {
        switch error {
        case .keyNotFound: return .invalidEnvelope
        case .typeMismatch: return .invalidEnvelope
        case .valueNotFound: return .invalidEnvelope
        case .dataCorrupted: return .invalidEnvelope
        @unknown default: return .invalidEnvelope
        }
    }

    private static func errorResponse(for error: Error) -> PlannerHelperResponseEnvelope {
        if let code = error as? PlannerHelperErrorCode { return .failure(PlannerHelperError(code: code)) }
        if let plannerError = error as? PlannerError {
            switch plannerError {
            case .noMatch: return .failure(PlannerHelperError(code: .noMatch))
            case .ambiguous: return .failure(PlannerHelperError(code: .ambiguousRequest))
            case .unsafeRequest: return .failure(PlannerHelperError(code: .unsafeRequest))
            case .invalidSelection: return .failure(PlannerHelperError(code: .invalidSelection))
            case .validation(let validation): return errorResponse(for: validation)
            }
        }
        if let validation = error as? PlanValidationError {
            switch validation {
            case .invalidTarget(let reason):
                return .failure(PlannerHelperError(code: reason.contains("requires") ? .targetRequired : .invalidTarget))
            case .invalidSelection: return .failure(PlannerHelperError(code: .invalidSelection))
            case .staleRevision: return .failure(PlannerHelperError(code: .staleSelection))
            case .ambiguousRequest: return .failure(PlannerHelperError(code: .ambiguousRequest))
            default: return .failure(PlannerHelperError(code: .planInvalid))
            }
        }
        if let schema = error as? PlanSchemaValidationError {
            switch schema {
            case .schemaUnreadable, .invalidSchema: return .failure(PlannerHelperError(code: .schemaInvalid))
            default: return .failure(PlannerHelperError(code: .planInvalid))
            }
        }
        if let resource = error as? PlannerHelperResourceError {
            switch resource {
            case .resourceMissing: return .failure(PlannerHelperError(code: .resourceMissing))
            case .resourceTampered: return .failure(PlannerHelperError(code: .resourceTampered))
            case .registryInvalid: return .failure(PlannerHelperError(code: .registryInvalid))
            case .schemaInvalid: return .failure(PlannerHelperError(code: .schemaInvalid))
            }
        }
        return .failure(PlannerHelperError(code: .internalError))
    }

    private static func readBounded(_ handle: FileHandle, maxBytes: Int = PlannerHelperLimits.maxInputBytes) throws -> Data {
        var result = Data()
        while true {
            let chunk = try handle.read(upToCount: min(16 * 1024, maxBytes + 1 - result.count)) ?? Data()
            if chunk.isEmpty { return result }
            result.append(chunk)
            if result.count > maxBytes { return result }
        }
    }

    public static func readStdin(maxBytes: Int = PlannerHelperLimits.maxInputBytes) -> Result<Data, Error> {
        Result { try readBounded(FileHandle.standardInput, maxBytes: maxBytes) }
    }
}
