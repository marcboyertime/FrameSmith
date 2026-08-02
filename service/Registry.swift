import Foundation

public enum RegistryError: Error, LocalizedError, Equatable {
    case directoryNotFound(URL)
    case invalidFile(URL, String)
    case duplicateIdentifier(EffectID)
    case missingEffect(EffectID)

    public var errorDescription: String? {
        switch self {
        case .directoryNotFound(let url): return "Effect registry directory not found: \(url.path)"
        case .invalidFile(let url, let reason): return "Invalid effect definition \(url.lastPathComponent): \(reason)"
        case .duplicateIdentifier(let id): return "Duplicate effect identifier: \(id.rawValue)"
        case .missingEffect(let id): return "Effect is not present in registry: \(id.rawValue)"
        }
    }
}

/// JSON-backed registry. Effect metadata is never duplicated in planner
/// behaviour; only dispatch on the typed identifier is allowed.
public struct EffectRegistry: Sendable {
    public let definitions: [EffectID: EffectDefinition]

    public init(definitions: [EffectDefinition]) throws {
        var result: [EffectID: EffectDefinition] = [:]
        for definition in definitions {
            guard result[definition.identifier] == nil else { throw RegistryError.duplicateIdentifier(definition.identifier) }
            result[definition.identifier] = definition
        }
        self.definitions = result
    }

    public var all: [EffectDefinition] { EffectID.allCases.compactMap { definitions[$0] } }
    public func definition(for id: EffectID) throws -> EffectDefinition {
        guard let definition = definitions[id] else { throw RegistryError.missingEffect(id) }
        return definition
    }

    public func resolve(_ text: String) -> EffectID? {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        for definition in definitions.values {
            if definition.identifier == EffectID(identifier: normalized) || definition.identifier.rawValue == normalized || definition.aliases.contains(where: { $0.lowercased() == normalized }) {
                return definition.identifier
            }
        }
        return nil
    }

    public static func load(from directory: URL) throws -> EffectRegistry {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw RegistryError.directoryNotFound(directory)
        }
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        let decoder = JSONDecoder()
        var definitions: [EffectDefinition] = []
        for url in urls {
            do {
                definitions.append(try decoder.decode(EffectDefinition.self, from: Data(contentsOf: url)))
            } catch {
                throw RegistryError.invalidFile(url, error.localizedDescription)
            }
        }
        guard definitions.count == EffectID.allCases.count else {
            throw RegistryError.invalidFile(directory, "expected exactly \(EffectID.allCases.count) definitions, got \(definitions.count)")
        }
        return try EffectRegistry(definitions: definitions)
    }

    /// Locate the checked-out registry without relying on a bundled resource.
    /// Tests and callers can always pass an explicit URL to `load(from:)`.
    public static func discover() throws -> EffectRegistry {
        let fileManager = FileManager.default
        let candidates = [
            URL(fileURLWithPath: fileManager.currentDirectoryPath).appendingPathComponent("registry/effects"),
            URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("registry/effects")
        ]
        for candidate in candidates where fileManager.fileExists(atPath: candidate.path) {
            return try load(from: candidate)
        }
        throw RegistryError.directoryNotFound(candidates[0])
    }
}
