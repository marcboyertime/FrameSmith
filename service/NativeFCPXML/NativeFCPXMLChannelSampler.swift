import Foundation

/// The state of every intrinsic channel at one instant, in **screen** terms.
///
/// The emitted values are in Final Cut's units — percent of frame height,
/// positive-Y-up, degrees. This struct is what a renderer needs instead:
/// pixels, positive-Y-down. The conversion happens once, here, because a
/// preview that applies the raw emitted numbers would show a picture 10.8×
/// off and flipped, which is the same class of error the capture work exists
/// to catch.
public struct NativeFCPXMLChannelState: Equatable, Sendable {
    /// Horizontal offset in pixels, positive right.
    public let offsetX: Double
    /// Vertical offset in pixels, **positive down** (screen convention).
    public let offsetY: Double
    /// Uniform scale, 1.0 = 100%.
    public let scale: Double
    /// Rotation in degrees.
    public let rotationDegrees: Double
    /// Opacity, 0–1.
    public let opacity: Double

    public init(offsetX: Double, offsetY: Double, scale: Double, rotationDegrees: Double, opacity: Double) {
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.scale = scale
        self.rotationDegrees = rotationDegrees
        self.opacity = opacity
    }

    public static let identity = NativeFCPXMLChannelState(
        offsetX: 0, offsetY: 0, scale: 1, rotationDegrees: 0, opacity: 1
    )
}

/// Evaluates emitted channels at a point in time.
///
/// This samples **the same keyframes that get exported**, not a parallel model
/// of the effect. That is the point: if a preview were computed from the
/// composition and the export from the channels, the two could disagree and
/// only Final Cut would ever notice. Sampling the channels means a preview that
/// is wrong is a symptom of an export that is wrong.
///
/// ## What this does not model
///
/// Interpolation is **linear**. Final Cut's default keyframe interpolation is
/// not linear — the capture showed a `curve` attribute written only when
/// interpolation differs from the default, and the default's actual shape has
/// never been observed. Values at the keyframes themselves are therefore exact;
/// values between them are an approximation whose error is largest mid-segment.
/// Callers must not present interpolated frames as exact.
public struct NativeFCPXMLChannelSampler: Sendable {
    public let frameHeight: Int

    public init(frameHeight: Int) {
        precondition(frameHeight > 0, "frame height must be positive")
        self.frameHeight = frameHeight
    }

    /// Linear interpolation across a keyframe track, holding flat outside it.
    ///
    /// Holding rather than extrapolating matches what the opacity emitter
    /// already relies on: Final Cut holds a parameter flat before its first
    /// keyframe, which is why the living still fade emits two keyframes rather
    /// than three.
    public func sample(_ keyframes: [NativeFCPXMLKeyframe], at seconds: Double) -> Double? {
        guard !keyframes.isEmpty else { return nil }
        let points: [(time: Double, value: Double)] = keyframes.compactMap { keyframe in
            guard let value = Self.firstComponent(of: keyframe.value) else { return nil }
            return (keyframe.time.seconds, value)
        }
        guard let first = points.first else { return nil }
        if seconds <= first.time { return first.value }
        guard let last = points.last else { return nil }
        if seconds >= last.time { return last.value }

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            guard seconds <= current.time else { continue }
            let span = current.time - previous.time
            guard span > 0 else { return current.value }
            let progress = (seconds - previous.time) / span
            return previous.value + (current.value - previous.value) * progress
        }
        return last.value
    }

    /// Combines the transform and opacity channels into screen-space state.
    ///
    /// `origin` matters: a still's keyframes are absolute from 3600 s while a
    /// movie's start at 0 s, so a caller asking for "one second in" means a
    /// different absolute time for each.
    public func state(
        transform: NativeFCPXMLTransformChannel,
        opacity: NativeFCPXMLOpacityChannel,
        atClipSeconds seconds: Double,
        origin: NativeFCPXMLTimingOrigin
    ) -> NativeFCPXMLChannelState {
        let absolute = Double(origin.sourceStartSeconds) + seconds
        let height = Double(frameHeight)

        // Percent of frame height back to pixels, and Y back to screen-down.
        let percentX = sample(transform.positionX, at: absolute) ?? transform.staticPosition?.x ?? 0
        let percentY = sample(transform.positionY, at: absolute) ?? transform.staticPosition?.y ?? 0
        let scale = sample(transform.scale, at: absolute) ?? 1
        let rotation = sample(transform.rotation, at: absolute) ?? 0

        let opacityValue: Double
        if let animated = sample(opacity.amount, at: absolute) {
            opacityValue = animated
        } else {
            opacityValue = opacity.staticAmount ?? 1
        }

        return NativeFCPXMLChannelState(
            offsetX: percentX / 100 * height,
            offsetY: -percentY / 100 * height,
            scale: scale,
            rotationDegrees: rotation,
            opacity: opacityValue
        )
    }

    /// Scale keyframes carry paired values (`"1.08 1.08"`); the rest are
    /// scalars. Uniform scale is all any admitted emitter produces, so the
    /// first component is the value — but a non-uniform pair would silently
    /// lose its second component here, so callers emitting one must extend
    /// this rather than assume it copes.
    static func firstComponent(of value: String) -> Double? {
        Double(value.split(separator: " ").first.map(String.init) ?? value)
    }
}
