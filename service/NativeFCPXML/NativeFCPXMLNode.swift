import Foundation

/// A deliberately small XML tree: ordered attributes, ordered children, one
/// escaping implementation, deterministic rendering.
///
/// This is not a general FCPXML DSL. It exists so the channel emitters can
/// return structure instead of interpolated strings, which is what lets
/// transform, opacity, and colour be composed by different callers without
/// each one re-deriving indentation and escaping.
public struct NativeFCPXMLNode: Equatable, Sendable {
    public let name: String
    public private(set) var attributes: [(name: String, value: String)]
    public private(set) var children: [NativeFCPXMLNode]
    /// Text content, mutually exclusive with `children`. Only `<data>` needs
    /// it — Final Cut carries the `effectConfig` archive as element text.
    public private(set) var text: String?

    public init(_ name: String, attributes: [(name: String, value: String)] = [], children: [NativeFCPXMLNode] = []) {
        self.name = name
        self.attributes = attributes
        self.children = children
        self.text = nil
    }

    public static func text(name: String, attributes: [(name: String, value: String)] = [], text: String) -> NativeFCPXMLNode {
        var node = NativeFCPXMLNode(name, attributes: attributes)
        node.text = text
        return node
    }

    public static func == (lhs: NativeFCPXMLNode, rhs: NativeFCPXMLNode) -> Bool {
        lhs.name == rhs.name
            && lhs.children == rhs.children
            && lhs.text == rhs.text
            && lhs.attributes.count == rhs.attributes.count
            && zip(lhs.attributes, rhs.attributes).allSatisfy { $0.name == $1.name && $0.value == $1.value }
    }

    public mutating func append(_ child: NativeFCPXMLNode) {
        children.append(child)
    }

    public mutating func append(contentsOf nodes: [NativeFCPXMLNode]) {
        children.append(contentsOf: nodes)
    }

    public func rendered(indent: Int = 0, indentWidth: Int = 2) -> String {
        let pad = String(repeating: " ", count: indent * indentWidth)
        let attributeText = attributes.map { " \($0.name)=\"\(Self.escapeAttribute($0.value))\"" }.joined()
        if let text {
            return "\(pad)<\(name)\(attributeText)>\(Self.escapeText(text))</\(name)>"
        }
        guard !children.isEmpty else {
            return "\(pad)<\(name)\(attributeText)/>"
        }
        let inner = children.map { $0.rendered(indent: indent + 1, indentWidth: indentWidth) }.joined(separator: "\n")
        return "\(pad)<\(name)\(attributeText)>\n\(inner)\n\(pad)</\(name)>"
    }

    /// `&` first, so already-escaped output is never double-escaped.
    public static func escapeAttribute(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    public static func escapeText(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// Percent-encodes a filesystem path into a `file://` URL the way the
    /// dissolve probe does, which Final Cut has already accepted four times.
    public static func fileURLString(_ url: URL) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~/")
        let path = url.standardizedFileURL.path
        guard let encoded = path.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return url.standardizedFileURL.absoluteString
        }
        return "file://\(encoded)"
    }
}
