import Foundation

/// Errors raised while validating a serialized EffectPlan against the checked
/// in JSON Schema. This intentionally implements only the JSON Schema keywords
/// used by `schemas/effect-plan.schema.json`; it has no network or package
/// dependency and fails closed for unsupported schema shapes.
public enum PlanSchemaValidationError: Error, LocalizedError, Equatable {
    case schemaUnreadable(String)
    case invalidSchema(String)
    case invalidJSON(String)
    case violation(path: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .schemaUnreadable(let reason): return "EffectPlan schema is unreadable: \(reason)"
        case .invalidSchema(let reason): return "EffectPlan schema is unsupported or invalid: \(reason)"
        case .invalidJSON(let reason): return "Serialized EffectPlan is not valid JSON: \(reason)"
        case .violation(let path, let reason): return "EffectPlan schema violation at \(path): \(reason)"
        }
    }
}

/// Small dependency-free validator for the repository's draft-2020-12 subset.
/// It supports refs into `$defs`, object/array/string/number/boolean/null
/// types, required/additionalProperties, enum/const, bounds, patterns,
/// minLength/minItems, and UUID format checks.
public struct PlanSchemaValidator {
    private let schema: [String: Any]

    public init(schemaURL: URL) throws {
        do {
            let data = try Data(contentsOf: schemaURL)
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw PlanSchemaValidationError.invalidSchema("root must be an object")
            }
            guard object["$schema"] as? String == "https://json-schema.org/draft/2020-12/schema" else {
                throw PlanSchemaValidationError.invalidSchema("only draft 2020-12 is supported")
            }
            schema = object
        } catch let error as PlanSchemaValidationError {
            throw error
        } catch {
            throw PlanSchemaValidationError.schemaUnreadable(error.localizedDescription)
        }
    }

    public func validate(_ data: Data) throws {
        let value: Any
        do {
            value = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw PlanSchemaValidationError.invalidJSON(error.localizedDescription)
        }
        try validate(value, against: schema, path: "$", root: schema)
    }

    private func validate(_ value: Any, against rawSchema: [String: Any], path: String, root: [String: Any]) throws {
        var current = rawSchema
        if let reference = rawSchema["$ref"] as? String {
            guard reference.hasPrefix("#/$defs/"), let defs = root["$defs"] as? [String: Any] else {
                throw PlanSchemaValidationError.invalidSchema("unsupported reference \(reference)")
            }
            let name = String(reference.dropFirst("#/$defs/".count))
            guard let definition = defs[name] as? [String: Any] else {
                throw PlanSchemaValidationError.invalidSchema("missing definition \(name)")
            }
            current = definition
        }

        if let anyOf = current["anyOf"] as? [[String: Any]] {
            var failures: [String] = []
            for branch in anyOf {
                do {
                    try validate(value, against: branch, path: path, root: root)
                    return
                } catch {
                    failures.append(error.localizedDescription)
                }
            }
            throw violation(path, "none of anyOf branches matched (\(failures.joined(separator: "; ")))" )
        }

        if let type = current["type"] as? String, !matchesType(value, type) {
            throw violation(path, "expected \(type), got \(typeName(value))")
        }
        if let constant = current["const"], !jsonEqual(value, constant) {
            throw violation(path, "must equal \(render(constant))")
        }
        if let allowed = current["enum"] as? [Any], !allowed.contains(where: { jsonEqual(value, $0) }) {
            throw violation(path, "value is not one of the permitted enum values")
        }

        if let object = value as? [String: Any] {
            if let required = current["required"] as? [String] {
                for key in required where object[key] == nil {
                    throw violation(append(path, key), "required property is missing")
                }
            }
            let properties = (current["properties"] as? [String: Any]) ?? [:]
            if let additionalProperties = current["additionalProperties"] {
                if let allowed = additionalProperties as? Bool {
                    if !allowed {
                        for key in object.keys where properties[key] == nil {
                            throw violation(append(path, key), "additionalProperties is false")
                        }
                    }
                } else if let additionalSchema = additionalProperties as? [String: Any] {
                    // Object-valued additionalProperties is used by the
                    // parameterValue definition (and recursively nested
                    // parameter objects). Validate each unknown key against
                    // that schema instead of silently accepting arbitrary
                    // JSON values.
                    for key in object.keys where properties[key] == nil {
                        guard let propertyValue = object[key] else { continue }
                        try validate(propertyValue, against: additionalSchema, path: append(path, key), root: root)
                    }
                } else {
                    throw PlanSchemaValidationError.invalidSchema("additionalProperties must be a boolean or schema object")
                }
            }
            if let properties = current["properties"] as? [String: Any] {
                for (key, propertySchema) in properties {
                    guard let propertyValue = object[key], let propertySchema = propertySchema as? [String: Any] else { continue }
                    try validate(propertyValue, against: propertySchema, path: append(path, key), root: root)
                }
            }
        }

        if let array = value as? [Any] {
            if let minimum = number(current["minItems"]) { guard Double(array.count) >= minimum else { throw violation(path, "must contain at least \(Int(minimum)) item(s)") } }
            if let itemSchema = current["items"] as? [String: Any] {
                for (index, item) in array.enumerated() {
                    try validate(item, against: itemSchema, path: append(path, "[\(index)]"), root: root)
                }
            }
        }

        if let string = value as? String {
            if let minimum = number(current["minLength"]) { guard Double(string.count) >= minimum else { throw violation(path, "must contain at least \(Int(minimum)) character(s)") } }
            if let pattern = current["pattern"] as? String {
                guard let regex = try? NSRegularExpression(pattern: pattern), regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)) != nil else {
                    throw violation(path, "does not match required pattern")
                }
            }
            if let format = current["format"] as? String, format == "uuid", UUID(uuidString: string) == nil {
                throw violation(path, "must be a UUID")
            } else if let format = current["format"] as? String, format != "uuid" {
                throw PlanSchemaValidationError.invalidSchema("unsupported string format \(format)")
            }
        }

        if let numeric = numericValue(value) {
            if let minimum = number(current["minimum"]) { guard numeric >= minimum else { throw violation(path, "must be >= \(minimum)") } }
            if let maximum = number(current["maximum"]) { guard numeric <= maximum else { throw violation(path, "must be <= \(maximum)") } }
        }
    }

    private func matchesType(_ value: Any, _ expected: String) -> Bool {
        switch expected {
        case "object": return value is [String: Any]
        case "array": return value is [Any]
        case "string": return value is String
        case "boolean": return isBoolean(value)
        case "number": return numericValue(value) != nil
        case "integer":
            guard let numeric = numericValue(value) else { return false }
            return numeric.rounded() == numeric
        case "null": return value is NSNull
        default: return false
        }
    }

    private func numericValue(_ value: Any) -> Double? {
        guard let number = value as? NSNumber, !isBoolean(number) else { return nil }
        let value = number.doubleValue
        return value.isFinite ? value : nil
    }

    private func number(_ value: Any?) -> Double? {
        guard let value else { return nil }
        return numericValue(value)
    }

    private func isBoolean(_ value: Any) -> Bool {
        guard let number = value as? NSNumber else { return false }
        return String(cString: number.objCType) == "c"
    }

    private func typeName(_ value: Any) -> String {
        if value is [String: Any] { return "object" }
        if value is [Any] { return "array" }
        if value is String { return "string" }
        if isBoolean(value) { return "boolean" }
        if numericValue(value) != nil { return "number" }
        if value is NSNull { return "null" }
        return String(describing: type(of: value))
    }

    private func jsonEqual(_ lhs: Any, _ rhs: Any) -> Bool {
        if let left = lhs as? String, let right = rhs as? String { return left == right }
        if let left = lhs as? Bool, let right = rhs as? Bool { return left == right }
        if let left = numericValue(lhs), let right = numericValue(rhs) { return left == right }
        if lhs is NSNull, rhs is NSNull { return true }
        if let left = lhs as? [Any], let right = rhs as? [Any] { return left.count == right.count && zip(left, right).allSatisfy { jsonEqual($0, $1) } }
        if let left = lhs as? [String: Any], let right = rhs as? [String: Any] {
            return left.count == right.count && left.allSatisfy { key, value in right[key].map { jsonEqual(value, $0) } ?? false }
        }
        return false
    }

    private func violation(_ path: String, _ reason: String) -> PlanSchemaValidationError {
        .violation(path: path, reason: reason)
    }

    private func append(_ path: String, _ component: String) -> String {
        component.hasPrefix("[") ? "\(path)\(component)" : "\(path).\(component)"
    }

    private func render(_ value: Any) -> String {
        if let string = value as? String { return "\"\(string)\"" }
        return String(describing: value)
    }
}
