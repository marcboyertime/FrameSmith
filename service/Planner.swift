import Foundation

public enum PlannerError: Error, LocalizedError, Equatable {
    case noMatch
    case ambiguous([EffectID])
    case unsafeRequest(String)
    case invalidSelection(String)
    case validation(PlanValidationError)

    public var errorDescription: String? {
        switch self {
        case .noMatch: return "Request did not match one of the four supported workflows"
        case .ambiguous(let ids): return "Request is ambiguous: \(ids.map(\.rawValue).joined(separator: ", "))"
        case .unsafeRequest(let reason): return "Request rejected: \(reason)"
        case .invalidSelection(let reason): return "Selection token rejected: \(reason)"
        case .validation(let error): return error.localizedDescription
        }
    }
}

public struct DeterministicRequestParser: Sendable {
    public let registry: EffectRegistry

    public init(registry: EffectRegistry) { self.registry = registry }

    public func parse(_ request: String) throws -> RequestInterpretation {
        let original = request.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty else { throw PlannerError.noMatch }
        let lower = original.lowercased()
        let dangerous = ["/bin/sh", "bash ", "zsh ", "shell", "osascript", "applescript", "selector", "xpath", "javascript:", "--exec", "curl ", "ffmpeg ", "python ", "system(", "process(", "rm -"]
        if dangerous.contains(where: { lower.contains($0) }) || original.contains(where: { ";&|`$<>\n\r".contains($0) }) {
            throw PlannerError.unsafeRequest("commands and shell-like syntax are not accepted")
        }

        var matches: [EffectID] = []
        for definition in registry.all {
            let candidates = [definition.identifier.rawValue, definition.name] + definition.aliases
            if candidates.contains(where: { lower.contains($0.lowercased()) }) {
                matches.append(definition.identifier)
            }
        }
        // A small amount of restrained vocabulary is useful when the registry
        // is intentionally terse. It still resolves only to the four IDs.
        if lower.contains("rotate") || lower.contains("zoom") || lower.contains("target") || lower.contains("conform") || lower.contains("crop") { matches.append(.targetedRotateZoom) }
        if lower.contains("dissolve") || lower.contains("cross fade") || lower.contains("crossfade") { matches.append(.naturalDissolve) }
        if lower.contains("old tv") || lower.contains("vhs") || lower.contains("scanline") || lower.contains("scan line") || lower.contains("television") { matches.append(.oldTelevision) }
        if lower.contains("living still") || lower.contains("bring this still to life") || lower.contains("make this still move") || lower.contains("animate still") || lower.contains("gently alive") || lower.contains("depthflow") || lower.contains("depth flow") || lower.contains("parallax") { matches.append(.livingStill) }
        matches = Array(Set(matches))
        guard !matches.isEmpty else { throw PlannerError.noMatch }
        guard matches.count == 1, let id = matches.first else { throw PlannerError.ambiguous(matches.sorted { $0.rawValue < $1.rawValue }) }

        // Confidence is deterministic and intentionally conservative. Any
        // unsupported modifiers are retained as an ambiguity, not interpreted.
        var ambiguities: [String] = []
        let supportedWords = [
            "targeted", "target", "rotate", "rotation", "zoom", "zooming", "conform", "crop", "slow", "select",
            "dissolve", "natural", "naturally", "cross", "fade", "quickly", "old", "tv", "television",
            "footage", "black", "white", "vhs", "scanline", "scanlines", "scan", "static", "grain",
            "overlay", "subtle", "instability", "flicker", "desaturate", "desaturation", "monochrome", "living", "still", "image", "feel", "gently", "alive", "look", "like",
            "bring", "this", "life", "move", "animate", "depthflow", "depth", "flow", "parallax",
            "seconds", "second", "secs", "duration", "fps", "frames", "frame", "degrees", "degree", "deg",
            "by", "for", "four", "toward", "towards", "point", "i", "select", "slight", "slightly", "enrich", "colors",
            "ease", "linear", "in", "out", "clockwise", "counterclockwise", "counter", "while", "with", "to",
            "at", "the", "a", "an", "on", "and", "into", "next", "clip", "clips", "selection", "please", "make",
            "give", "apply", "add", "use", "then"
        ]
        for token in lower.split(whereSeparator: { !$0.isLetter && !$0.isNumber }) where !supportedWords.contains(String(token)) && Double(token) == nil {
            ambiguities.append(String(token))
        }
        let confidence = ambiguities.isEmpty ? 0.98 : 0.75
        return RequestInterpretation(originalRequest: original, confidence: confidence, ambiguities: ambiguities, effectID: id)
    }
}

public typealias RequestParser = DeterministicRequestParser

public struct DeterministicPlanner: Sendable {
    public let registry: EffectRegistry
    public let parser: DeterministicRequestParser

    public init(registry: EffectRegistry) {
        self.registry = registry
        self.parser = DeterministicRequestParser(registry: registry)
    }

    public func plan(request: String, selection: SelectionToken, target: Target? = nil, operationID: UUID = UUID()) throws -> EffectPlan {
        let interpretation = try parser.parse(request)
        guard let effectID = interpretation.effectID else { throw PlannerError.noMatch }
        let definition = try registry.definition(for: effectID)
        guard selection.selectionType == definition.requiredSelection else {
            throw PlannerError.invalidSelection("expected \(definition.requiredSelection.rawValue), got \(selection.selectionType.rawValue)")
        }
        var parameters: [String: ParameterValue] = [:]
        for parameter in definition.parameters {
            if let value = parameter.defaultValue { parameters[parameter.name] = value }
        }
        parseBoundedParameters(from: interpretation.originalRequest, definition: definition, into: &parameters)
        let fallback = definition.fallback
        let plan = EffectPlan(
            operationID: operationID,
            originalRequest: interpretation.originalRequest,
            confidence: interpretation.confidence,
            ambiguities: interpretation.ambiguities,
            effectID: effectID,
            selectionToken: selection,
            normalizedPoint: target,
            parameters: parameters,
            representation: definition.representation,
            editableProperties: definition.editableProperties,
            generatedAssets: definition.generatedAssets,
            previewStrategy: definition.preview,
            verification: definition.verification,
            fallback: fallback,
            cost: CostEstimate(paid: false, usd: 0, provider: "local"),
            preconditionRevision: selection.revision
        )
        try PlanValidator(registry: registry).validate(plan)
        return plan
    }

    public func plan(request: String, selectionFixture: URL, target: Target? = nil, operationID: UUID = UUID()) throws -> EffectPlan {
        let token = try JSONDecoder().decode(SelectionToken.self, from: Data(contentsOf: selectionFixture))
        return try plan(request: request, selection: token, target: target, operationID: operationID)
    }

    private func parseBoundedParameters(from request: String, definition: EffectDefinition, into parameters: inout [String: ParameterValue]) {
        let lower = request.lowercased()
        for parameter in definition.parameters {
            let key = parameter.name.lowercased()
            let synonyms = [key, key.replacingOccurrences(of: "_", with: " "), key.replacingOccurrences(of: "-", with: " ")]
            guard let synonym = synonyms.first(where: { lower.contains($0) }) else { continue }
            let pattern = "(?:\\(synonym)\\)?\\s*(?:to|at|=|:)??\\s*([0-9]+(?:\\.[0-9]+)?)".replacingOccurrences(of: "(synonym)", with: NSRegularExpression.escapedPattern(for: synonym))
            guard let regex = try? NSRegularExpression(pattern: pattern), let match = regex.firstMatch(in: request, range: NSRange(request.startIndex..., in: request)), let range = Range(match.range(at: 1), in: request), let number = Double(request[range]), number.isFinite else { continue }
            let bounded = min(parameter.maximum ?? number, max(parameter.minimum ?? number, number))
            switch parameter.type {
            case "integer": parameters[parameter.name] = .integer(Int(bounded.rounded()))
            case "boolean": parameters[parameter.name] = .boolean(bounded != 0)
            default: parameters[parameter.name] = .number(bounded)
            }
        }
        if definition.identifier == .naturalDissolve, lower.contains("ease in") { parameters["easing"] = .string(Easing.easeIn.rawValue) }
        if definition.identifier == .naturalDissolve, lower.contains("ease out") { parameters["easing"] = .string(Easing.easeOut.rawValue) }
        if definition.identifier == .targetedRotateZoom {
            if let seconds = firstNumber(in: lower, pattern: #"([0-9]+(?:\.[0-9]+)?)\s*(?:seconds?|secs?|s)\b"#) { parameters["durationSeconds"] = .number(min(30, max(0.1, seconds))) }
            if let rotation = firstNumber(in: lower, pattern: #"([0-9]+(?:\.[0-9]+)?)\s*(?:degrees?|deg)\b"#) {
                let signed = lower.contains("counterclockwise") || lower.contains("counter-clockwise") ? -rotation : rotation
                parameters["rotationEndDegrees"] = .number(min(180, max(-180, signed)))
            }
            if lower.contains("counterclockwise") || lower.contains("counter-clockwise") { parameters["direction"] = .string("counterclockwise") }
            if lower.contains("clockwise") && !lower.contains("counterclockwise") { parameters["direction"] = .string("clockwise") }
        }
        if definition.identifier == .oldTelevision && (lower.contains("scanline") || lower.contains("scan line")) { parameters["kind"] = .string("scanline") }
        if definition.identifier == .livingStill {
            if let seconds = firstNumber(in: lower, pattern: #"([0-9]+(?:\.[0-9]+)?)\s*(?:seconds?|secs?|s)\b"#) {
                let bounded = min(30, max(0.1, seconds))
                parameters["durationSeconds"] = .number(bounded)
            } else if lower.contains("four seconds") {
                parameters["durationSeconds"] = .number(4)
            }
        }
    }

    private func firstNumber(in text: String, pattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern), let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), let range = Range(match.range(at: 1), in: text) else { return nil }
        return Double(text[range])
    }
}

public typealias Planner = DeterministicPlanner

public enum PlanValidationError: Error, LocalizedError, Equatable {
    case unsupportedSchema(String)
    case missingFallback
    case invalidConfidence
    case ambiguousRequest
    case unknownEffect(EffectID)
    case invalidTarget(String)
    case invalidParameter(String)
    case invalidSelection(String)
    case staleRevision(expected: String, actual: String)
    case paidCallNotAllowed
    case invalidCost
    case duplicateUnsafeField(String)
    case representationMismatch(expected: RepresentationClass, actual: RepresentationClass)
    case invalidPlanMetadata(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let value): return "Unsupported plan schema version: \(value)"
        case .missingFallback: return "An explicit fallback is required"
        case .invalidConfidence: return "Confidence must be finite and between 0 and 1"
        case .ambiguousRequest: return "Ambiguous requests fail closed"
        case .unknownEffect(let id): return "Unknown effect: \(id.rawValue)"
        case .invalidTarget(let reason): return "Invalid normalized target: \(reason)"
        case .invalidParameter(let reason): return "Invalid parameter: \(reason)"
        case .invalidSelection(let reason): return "Invalid selection: \(reason)"
        case .staleRevision(let expected, let actual): return "Stale selection revision (plan \(expected), token \(actual))"
        case .paidCallNotAllowed: return "Phase 1 plans cannot make paid provider calls"
        case .invalidCost: return "Invalid cost estimate"
        case .duplicateUnsafeField(let field): return "Unsafe/arbitrary field is not permitted: \(field)"
        case .representationMismatch(let expected, let actual): return "Representation mismatch (expected \(expected.rawValue), got \(actual.rawValue))"
        case .invalidPlanMetadata(let reason): return "Invalid registry-derived plan metadata: \(reason)"
        }
    }
}

public struct PlanValidator: Sendable {
    public let registry: EffectRegistry
    public init(registry: EffectRegistry) { self.registry = registry }

    public func validate(_ plan: EffectPlan, currentRevision: String? = nil) throws {
        guard plan.schemaVersion == SchemaVersion.v2_0.rawValue else { throw PlanValidationError.unsupportedSchema(plan.schemaVersion) }
        guard plan.confidence.isFinite, (0...1).contains(plan.confidence) else { throw PlanValidationError.invalidConfidence }
        guard plan.ambiguities.isEmpty else { throw PlanValidationError.ambiguousRequest }
        guard !plan.fallback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw PlanValidationError.missingFallback }
        guard plan.preconditionRevision == plan.selectionToken.revision else { throw PlanValidationError.staleRevision(expected: plan.preconditionRevision, actual: plan.selectionToken.revision) }
        if let currentRevision, currentRevision != plan.preconditionRevision { throw PlanValidationError.staleRevision(expected: currentRevision, actual: plan.preconditionRevision) }
        guard let definition = registry.definitions[plan.effectID] else { throw PlanValidationError.unknownEffect(plan.effectID) }
        guard plan.representation == definition.representation else { throw PlanValidationError.representationMismatch(expected: definition.representation, actual: plan.representation) }
        guard plan.editableProperties == definition.editableProperties else { throw PlanValidationError.invalidPlanMetadata("editable properties must come from the effect registry") }
        guard plan.generatedAssets == definition.generatedAssets else { throw PlanValidationError.invalidPlanMetadata("generated assets must come from the effect registry") }
        guard plan.previewStrategy == definition.preview, !plan.previewStrategy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw PlanValidationError.invalidPlanMetadata("preview strategy must be declared by the registry") }
        guard plan.verification == definition.verification, !plan.verification.isEmpty else { throw PlanValidationError.invalidPlanMetadata("verification requirements must be declared by the registry") }
        guard plan.fallback == definition.fallback else { throw PlanValidationError.invalidPlanMetadata("fallback must be the registry fallback") }
        guard plan.cost.paid == false, plan.cost.usd == 0, plan.cost.provider == "local", plan.cost.requiresMediaUpload == false else { throw PlanValidationError.paidCallNotAllowed }
        guard plan.cost.usd.isFinite, plan.cost.usd >= 0, plan.cost.estimatedUnits.map({ $0.isFinite && $0 >= 0 }) ?? true else { throw PlanValidationError.invalidCost }

        if let point = plan.normalizedPoint {
            guard point.isFinite else { throw PlanValidationError.invalidTarget("NaN or infinity") }
            guard point.isInNormalizedBounds else { throw PlanValidationError.invalidTarget("outside [0,1]") }
            guard point.confirmed else { throw PlanValidationError.invalidTarget("point must be explicitly confirmed before construction") }
        }
        let unsafeKeys = plan.parameters.keys.filter { key in
            let lower = key.lowercased()
            return lower.contains("command") || lower.contains("shell") || lower.contains("selector") || lower.contains("backendmethod")
        }
        if let key = unsafeKeys.first { throw PlanValidationError.duplicateUnsafeField(key) }

        let definitionByName = Dictionary(uniqueKeysWithValues: definition.parameters.map { ($0.name, $0) })
        for (name, value) in plan.parameters {
            guard let parameter = definitionByName[name] else { throw PlanValidationError.invalidParameter("unknown parameter \(name)") }
            try validate(value: value, definition: parameter)
        }
        try validateSelection(plan.selectionToken, for: definition, parameters: plan.parameters)
        if definition.identifier == .targetedRotateZoom, plan.normalizedPoint == nil { throw PlanValidationError.invalidTarget("targeted rotate+zoom requires an explicit point") }
    }

    private func validate(value: ParameterValue, definition: ParameterDefinition) throws {
        switch (definition.type, value) {
        case ("number", .number(let n)), ("float", .number(let n)):
            guard n.isFinite else { throw PlanValidationError.invalidParameter("\(definition.name) is not finite") }
            if let minimum = definition.minimum, n < minimum { throw PlanValidationError.invalidParameter("\(definition.name) below minimum") }
            if let maximum = definition.maximum, n > maximum { throw PlanValidationError.invalidParameter("\(definition.name) above maximum") }
        case ("number", .integer(let n)), ("float", .integer(let n)):
            try validate(value: .number(Double(n)), definition: definition)
        case ("integer", .integer(let n)):
            if let minimum = definition.minimum, Double(n) < minimum { throw PlanValidationError.invalidParameter("\(definition.name) below minimum") }
            if let maximum = definition.maximum, Double(n) > maximum { throw PlanValidationError.invalidParameter("\(definition.name) above maximum") }
        case ("string", .string(let string)):
            if let allowed = definition.allowedValues, !allowed.contains(.string(string)) { throw PlanValidationError.invalidParameter("\(definition.name) value is not allowed") }
        case ("boolean", .boolean): break
        default: throw PlanValidationError.invalidParameter("\(definition.name) has wrong type")
        }
    }

    private func validateSelection(_ token: SelectionToken, for definition: EffectDefinition, parameters: [String: ParameterValue]) throws {
        guard !token.tokenID.isEmpty, !token.revision.isEmpty else { throw PlanValidationError.invalidSelection("token id and revision are required") }
        guard token.clipIDs.allSatisfy({ !$0.isEmpty }) else { throw PlanValidationError.invalidSelection("empty clip id") }
        guard Set(token.clipIDs).count == token.clipIDs.count else { throw PlanValidationError.invalidSelection("duplicate clip id") }
        let isLocalMediaPreview = token.origin == .localMedia
        guard token.isSpine || isLocalMediaPreview else { throw PlanValidationError.invalidSelection("selection must be on the spine") }
        let nonNegativeFrames: [Int?] = [token.startFrame, token.endFrame, token.sourceDurationFrames, token.sourceRangeStartFrame, token.sourceRangeEndFrame, token.leftSourceDurationFrames, token.rightSourceDurationFrames, token.leftSourceRangeStartFrame, token.leftSourceRangeEndFrame, token.rightSourceRangeStartFrame, token.rightSourceRangeEndFrame, token.boundaryFrame, token.leftClipEndFrame, token.rightClipStartFrame]
        guard nonNegativeFrames.compactMap({ $0 }).allSatisfy({ $0 >= 0 }) else { throw PlanValidationError.invalidSelection("negative frame value") }
        guard token.handleBeforeFrames >= 0, token.handleAfterFrames >= 0 else { throw PlanValidationError.invalidSelection("negative handle") }
        if let frameRate = token.frameRate { guard (1...240).contains(frameRate) else { throw PlanValidationError.invalidSelection("invalid frame rate") } }
        if let start = token.startFrame, let end = token.endFrame { guard end > start else { throw PlanValidationError.invalidSelection("invalid range") } }
        guard token.sourceIdentities.count == definition.inputCount else { throw PlanValidationError.invalidSelection("exactly \(definition.inputCount) typed source identities are required") }
        guard token.sourceIdentities.count == token.clipIDs.count else { throw PlanValidationError.invalidSelection("source identity and clip counts differ") }
        try validateSourceIdentities(token.sourceIdentities, matching: token.clipIDs)
        switch definition.identifier {
        case .naturalDissolve:
            guard token.selectionType == .twoAdjacentClips, token.clipIDs.count == 2 else { throw PlanValidationError.invalidSelection("dissolve requires exactly two clips") }
            if isLocalMediaPreview { return }
            guard token.adjacent else { throw PlanValidationError.invalidSelection("dissolve clips must be adjacent") }
            guard let boundary = token.boundaryFrame ?? token.endFrame, boundary >= 0 else { throw PlanValidationError.invalidSelection("frame-quantized boundary is required") }
            let leftRangeStart = token.leftSourceRangeStartFrame ?? token.sourceRangeStartFrame
            let leftRangeEnd = token.leftSourceRangeEndFrame ?? token.sourceRangeEndFrame
            let rightRangeStart = token.rightSourceRangeStartFrame
            let rightRangeEnd = token.rightSourceRangeEndFrame
            guard let leftRangeStart, let leftRangeEnd, leftRangeStart >= 0, leftRangeEnd > leftRangeStart else { throw PlanValidationError.invalidSelection("invalid left source range") }
            if let rightRangeStart, let rightRangeEnd {
                guard rightRangeStart >= 0, rightRangeEnd > rightRangeStart else { throw PlanValidationError.invalidSelection("invalid right source range") }
            }
            let leftDuration = token.leftSourceDurationFrames ?? token.sourceDurationFrames
            let rightDuration = token.rightSourceDurationFrames ?? token.sourceDurationFrames
            guard let leftDuration, leftDuration >= leftRangeEnd else { throw PlanValidationError.invalidSelection("left source duration/range mismatch") }
            if let rightRangeEnd, let rightDuration { guard rightDuration >= rightRangeEnd else { throw PlanValidationError.invalidSelection("right source duration/range mismatch") } }
            if let leftClipEnd = token.leftClipEndFrame, let rightClipStart = token.rightClipStartFrame { guard leftClipEnd == rightClipStart, leftClipEnd == boundary else { throw PlanValidationError.invalidSelection("clips have an overlap or gap at the transition boundary") } }
            let requestedFrames = Int((parameters["durationFrames"]?.numberValue ?? 12).rounded(.up))
            let requiredHandle = max(1, Int(ceil(Double(requestedFrames) / 2.0)))
            guard token.handleBeforeFrames >= requiredHandle, token.handleAfterFrames >= requiredHandle else { throw PlanValidationError.invalidSelection("insufficient handles for requested dissolve") }
            guard let start = token.startFrame, let end = token.endFrame, end > start else { throw PlanValidationError.invalidSelection("overlap/gap or invalid dissolve range") }
        case .targetedRotateZoom, .oldTelevision, .livingStill:
            guard token.selectionType == definition.requiredSelection, token.clipIDs.count == definition.inputCount else { throw PlanValidationError.invalidSelection("selection cardinality mismatch") }
            if let duration = token.sourceDurationFrames { guard duration > 0 else { throw PlanValidationError.invalidSelection("source duration must be positive") } }
        }
    }

    private func validateSourceIdentities(_ identities: [SourceIdentity], matching clipIDs: [String]) throws {
        var itemIDs = Set<String>()
        var paths = Set<String>()
        for (index, identity) in identities.enumerated() {
            guard identity.itemID == clipIDs[index], !identity.itemID.isEmpty else {
                throw PlanValidationError.invalidSelection("source identity order or item id does not match the selected clip")
            }
            guard itemIDs.insert(identity.itemID).inserted else { throw PlanValidationError.invalidSelection("duplicate source item id") }

            let path = identity.canonicalPath
            guard path.hasPrefix("/"), !path.isEmpty else { throw PlanValidationError.invalidSelection("source path must be absolute") }
            guard !path.split(separator: "/").contains("..") else { throw PlanValidationError.invalidSelection("source path traversal is not allowed") }
            guard !path.unicodeScalars.contains(where: { ";&|`$()<>*?{}\n\r".unicodeScalars.contains($0) }) else {
                throw PlanValidationError.invalidSelection("source path contains shell metacharacters")
            }
            let url = URL(fileURLWithPath: path)
            guard url.standardizedFileURL.path == path else { throw PlanValidationError.invalidSelection("source path is not canonical") }
            guard url.resolvingSymlinksInPath().standardizedFileURL.path == path else { throw PlanValidationError.invalidSelection("source path must not be a symlink") }
            let forbiddenFinalCutPath = path == "/Applications/Final Cut Pro.app" || path.hasPrefix("/Applications/Final Cut Pro.app/") || path.contains(".fcpbundle") || path.contains("/Final Cut Pro Libraries/")
            guard !forbiddenFinalCutPath else { throw PlanValidationError.invalidSelection("Final Cut application/library paths are forbidden") }
            guard paths.insert(path).inserted else { throw PlanValidationError.invalidSelection("duplicate canonical source path") }

            let digest = identity.sha256
            guard digest.count == 64, digest.unicodeScalars.allSatisfy({ scalar in
                (scalar.value >= 48 && scalar.value <= 57) || (scalar.value >= 97 && scalar.value <= 102)
            }) else { throw PlanValidationError.invalidSelection("source SHA-256 must be 64 lowercase hexadecimal characters") }
        }
    }
}

public typealias PlanPolicyValidator = PlanValidator
