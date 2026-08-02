# FCPCommandConsole minimal runtime

This is a product-owned, deliberately small AppKit framework for the isolated
Final Cut copy. Its executable surface is limited to the typed interfaces and
fixed AppKit panel shell included in this directory.

The framework is intentionally not a proof of Final Cut behavior. It installs a
native menu item and disabled panel shell only after its host containment check.
Every mutation entry point returns `unsupported_unverified_fcp_12_3` until a
separately reviewed live spike verifies the exact host and exactly-one-library
invariant.

The copied-app signing policy is an exact five-key allowlist:
`com.apple.security.app-sandbox=false`,
`com.apple.security.cs.disable-library-validation=true`, and the preserved
audio-input, camera, and microphone entitlements. The library-validation
exception is required because locally signing the top-level copy otherwise
conflicts with its Apple-signed nested frameworks. Task-port/get-task-allow,
debugger, and DYLD-environment entitlements remain forbidden. This signing
policy does not establish runtime behavior or authorize a Final Cut library
mutation.

The copied-app startup compatibility has exactly two constructor-time,
compile-time Objective-C replacements. The existing
`POFDesktopOnboardingCoordinator` `setQueryDemoProjectInfo:` bridge retains and
validates its original setter IMP before calling it with one provider that
asynchronously completes on the main queue with nil demo metadata. The only
additional replacement is the `CCFirstLaunchHelper` instance method
`setupAndPresentFirstLaunchIfNeededWithCompletionHandler:`. It has the exact
`v24@0:8@?<v@?@"NSError">16` ABI and inspected original IMP offsets `0x924e8`
(arm64) and `0xc74c0` (x86_64). Its replacement immediately returns without
invoking, copying, retaining, inspecting, or otherwise accessing the
completion block.

Each replacement is installed only after copied-host containment, exact path,
bundle identifier, version, build, receipt, and active-slice UUID checks. The
onboarding bridge additionally requires the exact nested
`ProOnboardingFlowModelOne` framework path, whole-file SHA-256, active-slice
UUID, instance-method placement, argument count, return type, full encoding,
and original IMP. The first-launch replacement requires the same placement and
ABI checks plus that its original IMP resolves to the exact copied host image,
with the active-slice UUID and architecture-specific offset. Both replacements
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
