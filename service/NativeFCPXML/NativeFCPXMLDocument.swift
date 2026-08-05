import Foundation

/// Assembles a complete FCPXML document around emitted channels.
///
/// The wrapper deliberately differs from the ground-truth capture in one way.
/// Final Cut exported `<library location="file:///…/FCPCommandConsole Test.fcpbundle/">`
/// wrapping the event, plus four `<smart-collection>` elements. Both are
/// artefacts of *exporting from* a library. A probe that names a specific
/// library on disk would be directing the import at it, which crosses the line
/// this project keeps between generating a file and driving Final Cut. The
/// bare `<event>` form used here is what all four dissolve revisions imported
/// with, so it is the proven construction for the import direction.
public struct NativeFCPXMLDocument: Equatable, Sendable {
    public let version: String
    public let resources: [NativeFCPXMLNode]
    public let eventName: String
    public let projectName: String
    public let sequenceFormatID: String
    public let sequenceDuration: NativeFCPXMLTime
    public let spineChildren: [NativeFCPXMLNode]

    public init(
        version: String,
        resources: [NativeFCPXMLNode],
        eventName: String,
        projectName: String,
        sequenceFormatID: String,
        sequenceDuration: NativeFCPXMLTime,
        spineChildren: [NativeFCPXMLNode]
    ) {
        self.version = version
        self.resources = resources
        self.eventName = eventName
        self.projectName = projectName
        self.sequenceFormatID = sequenceFormatID
        self.sequenceDuration = sequenceDuration
        self.spineChildren = spineChildren
    }

    /// `audioLayout`/`audioRate` are carried across from the capture even
    /// though a still has no audio: Final Cut wrote them on a sequence whose
    /// only element was a silent image, so they are part of the observed
    /// construction rather than something inferred.
    public var rootNode: NativeFCPXMLNode {
        NativeFCPXMLNode("fcpxml", attributes: [("version", version)], children: [
            NativeFCPXMLNode("resources", children: resources),
            NativeFCPXMLNode("event", attributes: [("name", eventName)], children: [
                NativeFCPXMLNode("project", attributes: [("name", projectName)], children: [
                    NativeFCPXMLNode("sequence", attributes: [
                        ("format", sequenceFormatID),
                        ("duration", sequenceDuration.attributeValue),
                        ("tcStart", NativeFCPXMLTime.zero.attributeValue),
                        ("tcFormat", "NDF"),
                        ("audioLayout", "stereo"),
                        ("audioRate", "48k")
                    ], children: [
                        NativeFCPXMLNode("spine", children: spineChildren)
                    ])
                ])
            ])
        ])
    }

    public var xmlString: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE fcpxml>
        \(rootNode.rendered())
        """
    }
}

/// The installed Interchange DTDs, resolved by version.
public enum NativeFCPXMLDTD {
    public static let resourcesRoot = URL(fileURLWithPath: "/Applications/Final Cut Pro.app/Contents/Frameworks/Interchange.framework/Versions/A/Resources")

    public static func url(forVersion version: String) -> URL {
        resourcesRoot.appendingPathComponent("FCPXMLv\(version.replacingOccurrences(of: ".", with: "_")).dtd")
    }

    public static func isInstalled(version: String) -> Bool {
        FileManager.default.isReadableFile(atPath: url(forVersion: version).path)
    }
}
