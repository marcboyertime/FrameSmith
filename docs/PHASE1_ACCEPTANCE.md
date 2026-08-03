# Phase 1 acceptance

Refreshed 2026-08-03 from checkpoint `406edb8`. Phase 1 remains **incomplete:
0/4 Final Cut workflows accepted**.

## Verified offline and local-app facts

- `swift build` succeeded.
- `swift test` passed 79 tests with 0 failures.
- Schema v2 models, registry, deterministic parser/planner, validator, legacy
  quarantine, granular capability gate, local admission, role tokens,
  aspect-fit mapping, source preview, and inert package builder are implemented
  and tested.
- The standalone app has been installed at
  `/Users/marcboyer/Applications/FCPCommandConsole.app` with bundle identifier
  `com.marcboyer.FCPCommandConsole`; signature/resource checks passed.
- Local packages preserve source bytes and refuse stale/nonregular/symlinked
  sources, unsafe roots, operation collisions, and identity mismatch.

None of these are Final Cut workflow acceptance.

## Final Cut evidence and manual gate

The installed environment is Final Cut Pro 12.3 build 450152. The v1 predecessor
crashed while importing `asset-clip`; crash report
`/Users/marcboyer/Library/Logs/DiagnosticReports/Final Cut Pro-2026-08-03-082455.ips`,
incident `42DFFCF1-9E45-41DA-992F-ADB212422B07`, operation
`A78B1B9D-60D7-4CD8-960B-FA9104C301E7`.

The immutable reduced v2 package at
`/Users/marcboyer/Movies/FCPCommandConsole/exports/roundtrip-spikes/CA7D0733-A435-498E-BD82-149CFF863FC3`
passed syntax/DTD checks only. All Final Cut manual semantic rows are unknown.

Acceptance next requires exactly one manual import/export test of that package.
Stop on the first error, crash, alert, missing media/transition, or normalized
export difference. If it succeeds, record only asset admission and bare-dissolve
transition evidence. Transform, opacity, color, and overlay probes stay separate.

## Workflow matrix

| Workflow | Offline/local status | Final Cut acceptance |
| --- | --- | --- |
| Targeted rotate/zoom | planner/math/local point selection implemented | not accepted |
| Natural dissolve | registry + reduced v2 syntax package | not accepted |
| Old Television | layered-media plan/composition/local package only | not accepted |
| Living Still | native-fallback plan/local package only | not accepted |

Do not report workflow success from a plan, DTD pass, package, source preview,
or app signature. Only a documented Final Cut import/export/readback/manual
result can advance an appropriate row.
