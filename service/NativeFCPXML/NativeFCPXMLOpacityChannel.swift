import Foundation

/// A blend mode as Final Cut writes it: an index and a display name in one
/// string, e.g. `"14 (Overlay)"`.
///
/// The same convention appears throughout the Color Adjustments payload —
/// `"0 (SDR)"`, `"11 (Video)"`, `"2 (In & Out)"` — so it is a general enum
/// encoding rather than something specific to blending.
///
/// **Only `overlay` is observed.** The blend menu's ordering suggests the
/// indices are derivable, but a derived index that happens to be wrong produces
/// a valid document applying the *wrong mode*, which is exactly the failure
/// this project keeps catching. Other modes must be captured before they are
/// named here; `captured(_:)` exists so a caller can carry an observed value
/// without waiting for a constant, and its use should cite a capture.
public struct NativeFCPXMLBlendMode: Equatable, Hashable, Sendable {
    public let attributeValue: String

    private init(_ attributeValue: String) {
        self.attributeValue = attributeValue
    }

    /// Observed 2026-08-05, `docs/CONNECTED_LAYERS_GROUND_TRUTH.md`.
    public static let overlay = NativeFCPXMLBlendMode("14 (Overlay)")

    /// Escape hatch for a mode that has been captured but not yet promoted to
    /// a constant. Do not invent values for this.
    public static func captured(_ attributeValue: String) -> NativeFCPXMLBlendMode {
        NativeFCPXMLBlendMode(attributeValue)
    }
}

/// `<adjust-blend>` — opacity and blend mode.
///
/// Two forms, and which one applies depends on whether the value moves:
///
/// - **Animated** opacity is `<param name="amount">` carrying a
///   `keyframeAnimation`, values on a 0–1 scale rather than the inspector's
///   0–100 percent.
/// - **Static** opacity is an `amount` **attribute** on `<adjust-blend>`
///   itself, same 0–1 scale. Blend mode rides alongside it as `mode`.
///
/// That split is not specific to blending — `adjust-transform` does the same
/// with `position` and `anchor`. See `docs/CONNECTED_LAYERS_GROUND_TRUTH.md`.
///
/// Unlike `position`, the `amount` param does **not** nest. The DTD permits the
/// same `param*` recursion for both; only the capture distinguishes them.
public struct NativeFCPXMLOpacityChannel: Equatable, Sendable {
    /// Animated opacity, 0–1.
    public var amount: [NativeFCPXMLKeyframe]
    /// Static opacity, 0–1. Mutually exclusive with `amount`.
    public var staticAmount: Double?
    /// Blend mode. Omitted entirely when `nil`, matching Final Cut's habit of
    /// writing nothing for an untouched property.
    public var mode: NativeFCPXMLBlendMode?

    public init(
        amount: [NativeFCPXMLKeyframe] = [],
        staticAmount: Double? = nil,
        mode: NativeFCPXMLBlendMode? = nil
    ) {
        precondition(
            staticAmount == nil || amount.isEmpty,
            "opacity is either static (attribute) or animated (param), never both"
        )
        self.amount = amount
        self.staticAmount = staticAmount
        self.mode = mode
    }

    public var isEmpty: Bool { amount.isEmpty && staticAmount == nil && mode == nil }

    public var node: NativeFCPXMLNode? {
        guard !isEmpty else { return nil }

        // Observed attribute order: `amount` then `mode`.
        var attributes: [(name: String, value: String)] = []
        if let staticAmount {
            attributes.append(("amount", NativeFCPXMLNumber.string(staticAmount)))
        }
        if let mode {
            attributes.append(("mode", mode.attributeValue))
        }

        var children: [NativeFCPXMLNode] = []
        if !amount.isEmpty {
            children.append(NativeFCPXMLNode("param", attributes: [("name", "amount")], children: [.keyframeAnimation(amount)]))
        }

        return NativeFCPXMLNode("adjust-blend", attributes: attributes, children: children)
    }

    /// A fade held at full opacity until `fadeStartFrame`, reaching
    /// `endOpacity` at `endFrame`.
    ///
    /// Only two keyframes are emitted. The composition model carries three
    /// (`0 / 3.65 / 4`), but Final Cut holds a parameter flat before its first
    /// keyframe, so an explicit one at frame 0 is redundant — the capture
    /// wrote two for exactly this shape.
    public static func fade(
        fadeStartFrame: Int,
        endFrame: Int,
        rate: NativeFCPXMLFrameRate,
        startOpacity: Double = 1,
        endOpacity: Double = 0
    ) -> NativeFCPXMLOpacityChannel {
        NativeFCPXMLOpacityChannel(amount: [
            NativeFCPXMLKeyframe(
                time: NativeFCPXMLStillTiming.keyframeTime(frame: fadeStartFrame, rate: rate),
                value: NativeFCPXMLNumber.string(startOpacity)
            ),
            NativeFCPXMLKeyframe(
                time: NativeFCPXMLStillTiming.keyframeTime(frame: endFrame, rate: rate),
                value: NativeFCPXMLNumber.string(endOpacity)
            )
        ])
    }

    /// A held opacity and blend mode — the form a connected overlay uses.
    public static func composite(opacity: Double, mode: NativeFCPXMLBlendMode?) -> NativeFCPXMLOpacityChannel {
        NativeFCPXMLOpacityChannel(staticAmount: opacity, mode: mode)
    }
}
