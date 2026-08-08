# FrameSmith parameter liveness

Registry metadata is the source of truth for presentation and liveness. It is decoded by `ParameterDefinition` and checked during registry load, then remains registry-owned: `PlanValidator`, `LocalMediaPlanRevisionService`, and the inspector consult it to decide which controls are supported. It is not copied into an `EffectPlan`, which carries the plan's parameter values and execution semantics. Shared emitter channels consume validated values for FCPXML construction; the current visual viewer renders only Living Still and Targeted Rotate + Zoom single-media transform, opacity, and color channels, not two-clip transition or connected-overlay descriptors. Missing metadata fails closed as unsupported/read-only.

Living Still is live for duration, start/end scale, pan X, pan Y, start/end opacity, and fade duration. Pan X is a width fraction converted to Final Cut percent-of-frame-height; pan Y is a height fraction and is sign-inverted for Final Cut's positive-up axis. The still-only emitter frame-quantizes at 30 fps, uses the 3600-second still origin, and keeps the final keyframe addressable. `preserveOriginal`, `nativeFallbackEnabled`, `depthFlowStatus`, and `motionMethod` are invariants. `easing` is unsupported/read-only because no emitted FCPXML easing representation is established. `colorEnrichment` is unsupported/read-only: the only admitted color construction is the singular captured Color Adjustments Saturation 25 adapter. Preview color is indicative only; no arbitrary color editing, calibration, or perceptual claim exists.

Targeted Rotate + Zoom is live for duration, start/end scale, and signed start/end rotation. Positive Final Cut rotation is counterclockwise; `direction` is derived compatibility metadata (zero is canonically clockwise), never a direct control. `easing` is unsupported/read-only. A confirmed normalized target is an execution input, not a parameter. Stills use the 3600-second origin, movies zero; a requested quantized movie duration beyond the admitted source duration is refused.

Natural Dissolve has a production emitter and shared FCPXML construction
descriptor,
but its current registry presentation declares `durationFrames`, `easing`,
`preserveAudio`, and `edgeBehavior` unsupported/read-only. There is no
approximate or runtime-editable Natural Dissolve registry control. The
canonical read-only `durationFrames=12` is validated with the complete registry
plan and drives both the dissolve descriptor and emitted FCPXML. There is no
direct `durationSeconds` production route or fallback. The emitter preserves
the admitted centred, butt-joined construction and refuses insufficient handle
rather than moving an edit point or shortening a requested transition; it does
not establish a user-editable easing or audio mapping. The historical
2026-08-07 real-Final-Cut import covered the earlier one-second (30-frame)
dissolve geometry; the current canonical 12-frame route has automated
construction evidence only and still needs a fresh Final Cut import.

Old Television has a native FCPXML base treatment and an optional admitted-still
connected overlay. Its production registry contains only the nine construction
values the standalone emitter consumes: duration, Saturation 25, three-keyframe
flicker floor, optional-overlay opacity/start/duration, and fixed Overlay blend,
bounded timing, and identity transform. Numeric values are unsupported/read-only
and the fixed enum semantics are invariant/read-only; none is currently
runtime-editable or approximate. Production construction requires the complete,
validated registry plan and generates no FFmpeg, static-grain, or scanline
assets. `OldTelevisionCompositionBuilder` and `SafeFFmpegOverlayAdapter` remain
separate research/low-level code, not this production registry contract. The
optional overlay has construction evidence only and lacks fresh real-Final-Cut
and perceptual evidence. The current visual viewer does not render its
connected-overlay descriptor.
