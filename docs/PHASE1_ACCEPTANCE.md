# Phase 1 acceptance

Refreshed 2026-08-03 from checkpoint `c282b0f`. Phase 1 remains **incomplete:
0/4 Final Cut workflows accepted**.

## Verified offline and local-app facts

- `swift build` succeeded.
- `swift test` passed 94 tests with 0 failures.
- Schema v2 models, registry, deterministic parser/planner, validator, legacy
  quarantine, granular capability gate, local admission, role tokens,
  aspect-fit mapping, source preview, and inert package builder are implemented
  and tested.
- The standalone app has been installed at
  `/Users/marcboyer/Applications/FCPCommandConsole.app` with bundle identifier
  `com.marcboyer.FCPCommandConsole`; signature/resource checks passed.
- Local packages preserve source bytes and refuse stale/nonregular/symlinked
  sources, unsafe roots, operation collisions, and identity mismatch.
- Package writes are anchored to a descriptor on the vetted output root and
  published with `renameatx_np(RENAME_EXCL)`; a plan whose command, target, or
  role sources have drifted is refused before the output root is touched.
- The installer refuses symlinked, dangling, and non-bundle install targets and
  verifies the installed bundle after the swap.

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

Preflight was re-run read-only on 2026-08-03: both media files still match
their `manifest.json` SHA-256 and byte counts, the FCPXML is still valid
against the installed FCPXML 1.13 DTD, `Returned/` is empty, and the disposable
`FCPCommandConsole Test` library exists. The package is byte-identical to what
was generated, so the manual pass starts from a proven input.

Acceptance next requires exactly one manual import/export test of that package.
Stop on the first error, crash, alert, missing media/transition, or normalized
export difference. If it succeeds, record only asset admission and bare-dissolve
transition evidence. Transform, opacity, color, and overlay probes stay separate.

`docs/ROUNDTRIP_MANUAL_PASS.md` is the execution sheet: numbered steps, stop
conditions, and the rows to fill in during the pass.

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
