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

The isolated-copy startup compatibility is two reviewed current-application
preference writes plus one constructor-time Objective-C caller gate. That gate
can replace only `POFDesktopOnboardingCoordinator`
`setQueryDemoProjectInfo:` with an argument-discarding no-op. Before doing so,
it requires copied-host containment and active-slice UUID, the exact nested
`ProOnboardingFlowModelOne` framework path, its whole-file SHA-256 and active
slice UUID, instance-method placement, three Objective-C arguments, void
return type, exact `v24@0:8@?16` encoding, and the inspected implementation
offset in the active architecture. The static trace shows that a nil query
closure follows the framework’s pre-existing cleanup branch before the demo
fetch. This is neither a binary patch nor a CloudContent substitution, and it
does not fabricate a project, invoke CloudKit, or start a retry. The copied
artifact verifier records stock-versus-copied framework provenance before it
can report the gate contract as present.

The fixed CloudContent names and contracts were manually transcribed from the
locked `reference/elliotttate/SpliceKit` snapshot at
`f4f6618121309a69b66272b441f34cf8ad57f306` and static inspection of the exact
FCP 12.3 host. No SpliceKit source code, server, plugin framework, or runtime
feature is compiled into this framework.
