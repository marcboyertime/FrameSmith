# FCPCommandConsole minimal runtime

This is a product-owned, deliberately small AppKit framework for the isolated
Final Cut copy. Its executable surface is limited to the typed interfaces and
fixed AppKit panel shell included in this directory.

The framework is intentionally not a proof of Final Cut behavior. It installs a
native menu item and disabled panel shell only after its host containment check.
Every mutation entry point returns `unsupported_unverified_fcp_12_3` until a
separately reviewed live spike verifies the exact host and exactly-one-library
invariant.

The copied-app signing policy removes only the documented Apple-bound
entitlements and adds exactly
`com.apple.security.cs.disable-library-validation=true`. A controlled launch
attempt stopped in `dyld` before any library access because locally signing the
top-level copy caused a Team ID mismatch with Apple-signed nested frameworks.
This narrow entitlement is therefore required to preserve those nested
frameworks; sandboxing remains required, while task-port/get-task-allow,
debugger, and DYLD-environment entitlements remain forbidden. That observation
does not establish runtime behavior or authorize a Final Cut library mutation.

The copied-app startup compatibility is one constructor-time Objective-C caller
compatibility bridge. It can replace only `POFDesktopOnboardingCoordinator`
`setQueryDemoProjectInfo:` after retaining and validating the original setter
IMP. Before doing so, it requires copied-host containment and active-slice UUID,
the exact nested `ProOnboardingFlowModelOne` framework path, its whole-file
SHA-256 and active slice UUID, instance-method placement, three Objective-C
arguments, void return type, exact `v24@0:8@?16` encoding, and the inspected
implementation offset in the active architecture. The bridge then calls that
original setter with one provider that asynchronously completes on the main
queue with nil demo metadata. This preserves the coordinator completion flow
without fabricating a project or error, invoking CloudKit, or starting a retry.
The copied artifact verifier records stock-versus-copied framework provenance
before it can report the compatibility contract as present.

This bridge is not a license workaround. Static receipt validation in this FCP
release compares the parsed receipt bundle identifier with
`NSBundle.mainBundle.bundleIdentifier`; therefore the separate copied app uses
the receipt-compatible `com.apple.FinalCut` identifier. Runtime containment
also requires the exact copied app path, the copied receipt's reviewed SHA-256,
the copied executable UUID, and the embedded framework path. The stock
pre-injection executable SHA-256 remains a patcher provenance check because
the copied executable must gain one reviewed load command and a new signature.
The runtime never writes Final Cut preferences. Before any manual Option-launch
test, no production library may be open; the existing exactly-one disposable
library manifest gate remains fail-closed and all mutations remain disabled.

The fixed CloudContent names and contracts were manually transcribed from the
locked `reference/elliotttate/SpliceKit` snapshot at
`f4f6618121309a69b66272b441f34cf8ad57f306` and static inspection of the exact
FCP 12.3 host. No SpliceKit source code, server, plugin framework, or runtime
feature is compiled into this framework.
