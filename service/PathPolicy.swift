import Foundation

public enum PathPolicyError: Error, LocalizedError, Equatable {
    case missing(URL)
    case notRegularFile(URL)
    case outsideAllowedRoots(URL)
    case outsideOutputRoot(URL)
    case traversal(URL)
    case shellMetacharacter(URL)
    case unresolvedSymlink(URL)
    case overwrite(URL)
    case forbiddenFinalCutPath(URL)

    public var errorDescription: String? {
        switch self {
        case .missing(let u): return "Path does not exist: \(u.path)"
        case .notRegularFile(let u): return "Path is not a regular file: \(u.path)"
        case .outsideAllowedRoots(let u): return "Input is outside configured roots: \(u.path)"
        case .outsideOutputRoot(let u): return "Output is outside ~/Movies/FCPCommandConsole: \(u.path)"
        case .traversal(let u): return "Path traversal is not allowed: \(u.path)"
        case .shellMetacharacter(let u): return "Shell metacharacters are not allowed in paths: \(u.path)"
        case .unresolvedSymlink(let u): return "Symlink could not be resolved safely: \(u.path)"
        case .overwrite(let u): return "Refusing to overwrite existing output: \(u.path)"
        case .forbiddenFinalCutPath(let u): return "Final Cut application/library paths are forbidden: \(u.path)"
        }
    }
}

public struct PathPolicy: Sendable {
    public let allowedInputRoots: [URL]
    public let outputRoot: URL

    public init(allowedInputRoots: [URL], outputRoot: URL = PathPolicy.defaultOutputRoot) {
        self.allowedInputRoots = allowedInputRoots.map(Self.lexicalURL)
        self.outputRoot = Self.lexicalURL(outputRoot)
    }

    public static var defaultOutputRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies/FCPCommandConsole", isDirectory: true)
    }

    public func canonicalizeInput(_ input: URL) throws -> URL {
        try validateLexical(input)
        guard FileManager.default.fileExists(atPath: input.path) else { throw PathPolicyError.missing(input) }
        let resolved = input.resolvingSymlinksInPath().standardizedFileURL
        guard resolved.path != "/" else { throw PathPolicyError.notRegularFile(resolved) }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDirectory) else { throw PathPolicyError.unresolvedSymlink(input) }
        guard !isDirectory.boolValue else { throw PathPolicyError.notRegularFile(resolved) }
        guard FileManager.default.isReadableFile(atPath: resolved.path) else { throw PathPolicyError.notRegularFile(resolved) }
        guard !isForbiddenFinalCutPath(resolved) else { throw PathPolicyError.forbiddenFinalCutPath(resolved) }
        guard allowedInputRoots.contains(where: { isDescendant(resolved, of: $0) }) else { throw PathPolicyError.outsideAllowedRoots(resolved) }
        return resolved
    }

    public func canonicalizeExistingInput(_ input: URL) throws -> URL { try canonicalizeInput(input) }

    public func validateOutput(_ output: URL, overwrite: Bool = false) throws -> URL {
        try validateLexical(output)
        let resolved = output.standardizedFileURL
        guard isDescendant(resolved, of: outputRoot) else { throw PathPolicyError.outsideOutputRoot(resolved) }
        guard !isForbiddenFinalCutPath(resolved) else { throw PathPolicyError.forbiddenFinalCutPath(resolved) }
        if FileManager.default.fileExists(atPath: resolved.path) {
            if (try? resolved.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true { throw PathPolicyError.unresolvedSymlink(resolved) }
            guard overwrite else { throw PathPolicyError.overwrite(resolved) }
        }
        return resolved
    }

    public func validateOutputPath(_ output: URL, overwrite: Bool = false) throws -> URL { try validateOutput(output, overwrite: overwrite) }

    private func validateLexical(_ url: URL) throws {
        let raw = url.path
        if raw.split(separator: "/").contains("..") { throw PathPolicyError.traversal(url) }
        if raw.unicodeScalars.contains(where: { ";&|`$()<>*?{}\n\r".unicodeScalars.contains($0) }) {
            throw PathPolicyError.shellMetacharacter(url)
        }
        if raw.isEmpty || !url.isFileURL { throw PathPolicyError.missing(url) }
    }

    private func isForbiddenFinalCutPath(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return path == "/Applications/Final Cut Pro.app" || path.hasPrefix("/Applications/Final Cut Pro.app/") || path.contains(".fcpbundle") || path.contains("/Final Cut Pro Libraries/")
    }

    private func isDescendant(_ candidate: URL, of root: URL) -> Bool {
        let candidatePath = candidate.standardizedFileURL.path.hasSuffix("/") ? candidate.standardizedFileURL.path : candidate.standardizedFileURL.path + "/"
        let rootPath = root.standardizedFileURL.path.hasSuffix("/") ? root.standardizedFileURL.path : root.standardizedFileURL.path + "/"
        return candidatePath == rootPath || candidatePath.hasPrefix(rootPath)
    }

    private static func lexicalURL(_ url: URL) -> URL { url.standardizedFileURL }
}
