# Public-repository path audit

Recorded 2026-08-21 after searching the repository for
`/Users/marcboyer`.

## Portable product/runtime defaults

The standalone probe CLIs and fixture generator now derive their runtime roots
from `FileManager.default.homeDirectoryForCurrentUser` or `$HOME`. The generic
round-trip output-root guard no longer embeds one account name. Main app,
planning, preview, render-cache, and standalone export roots were already
home-relative or explicitly injected.

## Intentionally nonportable local evidence

Paths in `STATUS.md`, admission-pass reports, bakeoff reports, technique-card
evidence arrays, historical handoffs, and troubleshooting transcripts identify
where observations were made on the evidence Mac. They are retained because
changing them would break provenance. They are local observations, not product
defaults, portable fixtures, or compatibility claims.

## Version-pinned isolated Final Cut instrumentation

`Scripts/launch-isolated-fcpcommandconsole`,
`Scripts/capture-disposable-fcp-baseline`, `plugin/splicekit_minimal`, its policy
plist/tests, and `config/fcpcommandconsole-isolation.sb` intentionally bind the
single admitted evidence host, copied Final Cut application, disposable library,
and fixture paths. They are development-only, version/hash-pinned evidence
machinery and are not shipped in `FrameSmith.app`. Making those paths generic
without a new isolated-host enrollment would weaken their safety contract, so
they remain explicitly nonportable.

No private media, credentials, personal tokens, or runtime payloads are
committed by this checkpoint.
