# FCPCommandConsole minimal runtime

This is a product-owned, deliberately small AppKit framework for the isolated
Final Cut copy. Its executable surface is limited to the typed interfaces and
fixed AppKit panel shell included in this directory.

The framework is intentionally not a proof of Final Cut behavior. It installs a
native menu item and disabled panel shell only after its host containment check.
Workflow 1 has one typed native adapter for `native.targeted_rotate_zoom`.
Its fixed Final Cut 12.3 contract records only the inspected selection
reacquisition, represented-tool/video-effect-stack/xform path, transform
getters/setters, action bracket, and `FFUndoHandler` scope/undo-manager
accessors. Every contract is tied to the exact Flexo path, SHA-256, slice UUID,
method placement, full Objective-C ABI, and slice-specific IMP offset; it does
not accept caller selectors, methods, or backend choices.

The adapter immediately re-enumerates the active libraries and recaptures the
single selected spine item, stable identifier, source identity, frame geometry,
selection revision, and timeline revision before it could write. It compares
that capture with the transaction and accepts only the enrolled exactly-one
disposable library. The product point is deterministically converted from a
top-left normalized coordinate into a candidate centered-pixel, y-up Final Cut
plane; the conversion has offline math coverage but remains unverified for a
native write.

The runtime is deliberately still disabled for native mutation. Static
inspection proves Final Cut calls the transform setters with `options == 0`,
but it does not prove that option's interpolation semantics, an API to enumerate
and remove every pre-existing keyframe, or that the discovered undo scope owns
this exact project edit. Without those contracts, a partial position/rotation/
scale write could not be restored to its exact original keyframe topology.
The adapter therefore returns
`unsupported_pending_live_contract_missing_exact_native_easing_and_native_undo_rollback_contracts`
after the recapture gate and performs no write, rollback, or undo. A future
live disposable-library spike must prove those contracts before the already
typed write/readback/rollback path may be admitted.

The copied-app signing policy is an exact five-key allowlist:
`com.apple.security.app-sandbox=false`,
`com.apple.security.cs.disable-library-validation=true`, and the preserved
audio-input, camera, and microphone entitlements. The library-validation
exception is required because locally signing the top-level copy otherwise
conflicts with its Apple-signed nested frameworks. Task-port/get-task-allow,
debugger, and DYLD-environment entitlements remain forbidden. This signing
policy does not establish runtime behavior or authorize a Final Cut library
mutation.

The copied-app startup compatibility has exactly two compile-time Objective-C
replacements. The existing
`POFDesktopOnboardingCoordinator` `setQueryDemoProjectInfo:` bridge retains and
validates its original setter IMP before calling it with one provider that
asynchronously completes on the main queue with nil demo metadata. The only
additional replacement is the `CCFirstLaunchHelper` instance method
`setupAndPresentFirstLaunchIfNeededWithCompletionHandler:`. It has the exact
`v24@0:8@?<v@?@"NSError">16` ABI and inspected original IMP offsets `0x924e8`
(arm64) and `0xc74c0` (x86_64). Its replacement immediately returns without
invoking, copying, retaining, inspecting, or otherwise accessing the
completion block.

The Cloud replacement is governed by a small main-thread state machine. The
constructor registers one `NSApplicationWillFinishLaunchingNotification`
observer before its immediate guarded attempt. If and only if the exact helper
class or exact instance method is unavailable, the observer makes one
synchronous second attempt at that notification; installation, every other
guard failure, and the second attempt all remove the observer. There are no
timers, polling, delayed work, third attempts, or completion-block access.

Each replacement is installed only after copied-host containment, exact path,
bundle identifier, version, build, receipt, and active-slice UUID checks. The
onboarding bridge additionally requires the exact nested
`ProOnboardingFlowModelOne` framework path, whole-file SHA-256, active-slice
UUID, instance-method placement, argument count, return type, full encoding,
and original IMP. The first-launch replacement requires the same placement and
full-encoding, void-return, and original-IMP checks plus that its original IMP
resolves to the exact copied host image, with the active-slice UUID and
architecture-specific offset. Its nested block encoding is deliberately not
checked with `method_getNumberOfArguments`: on the supported Objective-C
runtime that parser reports twelve for
`v24@0:8@?<v@?@"NSError">16`, despite the receiver, selector, and block ABI.
The fixed full encoding remains the authoritative ABI guard. Both replacements
post-verify their installed IMP and encoding; any mismatch leaves the target
method unchanged. Static inspection also pins the PEAppController send and its
independent continuation in both slices, and shows the automatic listener is
created only by the suppressed call's completion route. The copied artifact
verifier records stock-versus-copied provenance before it can report the
compatibility contract as present.

This bridge is not a license workaround. Static receipt validation in this FCP
release compares the parsed receipt bundle identifier with
`NSBundle.mainBundle.bundleIdentifier`; therefore the separate copied app uses
the receipt-compatible `com.apple.FinalCut` identifier. Runtime containment
also requires the exact copied app path, the copied receipt's reviewed SHA-256,
the copied executable UUID, and the embedded framework path. The stock
pre-injection executable SHA-256 remains a patcher provenance check because
the copied executable must gain one reviewed load command and a new signature.
The runtime never writes Final Cut preferences. No production library may be
open; the existing exactly-one disposable library manifest gate remains
fail-closed and all mutations remain disabled.

The fixed CloudContent names and contracts were manually transcribed from the
locked `reference/elliotttate/SpliceKit` snapshot at
`f4f6618121309a69b66272b441f34cf8ad57f306` and static inspection of the exact
FCP 12.3 host. No SpliceKit source code, server, plugin framework, or runtime
feature is compiled into this framework.
