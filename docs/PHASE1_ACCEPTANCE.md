# Phase 1 acceptance

Refreshed 2026-08-03 from verified evidence only.

## Implemented and testable offline

Schema-versioned Codable models; exactly four registry definitions
(`native.targeted_rotate_zoom`, `look.old_television`,
`transition.natural_dissolve`, `motion.living_still`); deterministic aliases and
bounded parsing; fail-closed ambiguity handling; target finite/range policy;
spatial anchor compensation; dissolve adjacency, frame, range, handle, and
revision checks; canonical path policy; SHA-256 and source preservation; monthly
cost ledger with independent, operation-scoped media-upload approval; provenance
and idempotency records; closed FFmpeg overlay generation; CLI inspection; and
source audits.

Offline acceptance commands, all currently passing:

    swift test
    swift run fcpcommandconsole doctor-core
    make test
    make overlay-smoke
    /bin/zsh -n Scripts/launch-isolated-fcpcommandconsole
    /bin/zsh Scripts/tests/run-isolated-launcher-tests
    /bin/zsh plugin/tests/run-offline-tests
    git diff --check

`run-offline-tests` aborts unless a real `ripgrep` binary is on `PATH`.

## Proven live

These are the only live facts. They are infrastructure facts, not product facts.

- A Schema 16 copied artifact is installed and independently verified on schema,
  policy/runtime/helper hashes, signature, Team, identifier, CandidateCDHashFull,
  entitlement allowlist, MAS receipt, and bundle inventory. The stock app is
  unchanged on all six integrity checks.
- The isolated launcher preflight passes against that artifact.
- Two real launches of the exact copied app left normal Final Cut preferences
  unchanged, admitted only the disposable library, used the isolated HOME, and
  ended with a captured closed-process guard.
- The disposable library was opened through the admitted public
  `NSDocumentController openDocumentWithContentsOfURL:display:completionHandler:`
  route exactly once, and the exact enrolled library verified after the open.

## Not accepted as live

Disposable project resume; native effect application; main-thread model
mutation; import; append; undo; rollback; FCPXML interchange; responder/dialog
fallback; model downloads; uploads; and any perceptual quality claim.

The disposable project resume arm has run twice and been **rejected both times
with zero mutations**. Its current blocker is a wrong pre-resume invariant, not
a receiver or ABI mismatch. See STATUS.md.

## Workflow acceptance matrix

All four rows remain **0/4 live accepted**.

| Workflow | Current state | Required before enablement |
| --- | --- | --- |
| Targeted rotate/zoom | Typed math and static route evidence only; native execution disabled | Exact selected clip/source/handle/revision admission; one bounded transform write and readback; validated coordinate convention; transaction provenance; native undo and exact original keyframe rollback in the disposable library; manual acceptance |
| Native dissolve | Registry only | Exact adjacent clips, range, handles, revisions, typed duration, native transition readback, provenance, undo/rollback, and manual playback acceptance |
| Old-TV editable composition | Registry and composition definition only | Native editable layers/effects with every parameter represented in the typed plan; exact target and readback; transaction provenance; undo/rollback; manual visual acceptance |
| Living still | Registry plus local-generation-or-native-fallback policy only | Routine free dependencies require exact source, recorded license, and hash verification; paid calls and media uploads require exact explicit approval; then approved local output with hashes/cost/provenance or disclosed native fallback, source preservation, native insertion/readback, undo/rollback, and manual motion/quality acceptance |

Each row needs manual human acceptance. No agent-run check can satisfy the
manual acceptance requirement.

## Completion boundary

Phase 1 is not complete. A verified artifact, a passing preflight, a proven
isolation guarantee, and a successful library open do not upgrade any workflow
row. Bootstrap evidence is still incomplete because the resume operation has not
produced a verified result.
