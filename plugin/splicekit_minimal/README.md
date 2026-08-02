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

The static candidate strings in the source were manually transcribed from the
locked `reference/elliotttate/SpliceKit` snapshot at
`f4f6618121309a69b66272b441f34cf8ad57f306`. No SpliceKit source code, server,
plugin framework, or runtime feature is compiled into this framework.
