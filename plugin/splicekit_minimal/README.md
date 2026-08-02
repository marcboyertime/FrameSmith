# FCPCommandConsole minimal runtime

This is a product-owned, deliberately small AppKit framework for the isolated
Final Cut copy. Its executable surface is limited to the typed interfaces and
fixed AppKit panel shell included in this directory.

The framework is intentionally not a proof of Final Cut behavior. It installs a
native menu item and disabled panel shell only after its host containment check.
Every mutation entry point returns `unsupported_unverified_fcp_12_3` until a
separately reviewed live spike verifies the exact host and exactly-one-library
invariant.

The static candidate strings in the source were manually transcribed from the
locked `reference/elliotttate/SpliceKit` snapshot at
`f4f6618121309a69b66272b441f34cf8ad57f306`. No SpliceKit source code, server,
plugin framework, or runtime feature is compiled into this framework.
