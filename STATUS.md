# FCPCommandConsole status

Captured 2026-08-03 (local machine). Every row below was re-verified in this
session; nothing is carried forward on trust.

## Canonical copied artifact

| Item | Value |
| --- | --- |
| Copied app | `/Users/marcboyer/Applications/SpliceKit/FCPCommandConsole/Final Cut Pro - FCPCommandConsole.app` |
| SchemaVersion | 16 |
| CandidateCDHashFull | `bda386441e36c0489edd8694eb70add2005c7fbe857ed80c7297ae01b16bb458` |
| Team / Identifier | `KDV9RC892F` / `com.apple.FinalCut` |
| Signature | `codesign --verify --deep --strict` valid |
| Stock executable | `6d29cb4326c2f35c96fbc57f29741fba8b5156265e188b19c975bc6cefba8390`, unchanged |
| Install provenance | `provenance/patch-20260803T103731Z-update-runtime-24324` |

It was installed transactionally from the exact verified Schema 15 predecessor
(`21e99732…`), whose own verifier transaction is
`provenance/patch-20260803T053233Z-verify-56034`. The launcher is pinned to the
Schema 16 policy and to the CandidateCDHashFull above.

## Recovery history in this session

1. The canonical artifact began as a fail-closed Schema 14 rollback. The damaged
   Schema 15 artifact's only defect was a flattened policy file, caused by a
   prior `plutil -extract` run without `-o`, which overwrote the plist in place.
2. Restoring the exact `abb1a7f` policy bytes into an unchanged staged copy of
   the damaged donor revalidated the original signature chain with **no
   re-signing**, reproducing the pinned Schema 15 CandidateCDHashFull exactly.
   Evidence: `provenance/recovery-20260803T080225Z-schema15-staged-donor-restore`.
3. The reconstructed bundle inventory matched the manifest recorded at the
   original Schema 15 installation across all 47,412 entries.
4. Schema 16 was then installed through the updater's own exact predecessor
   admission. A first Schema 16 build rejected its live resume operation; the
   verified Schema 15 predecessor was restored
   (`provenance/rollback-20260803T083246Z-schema16-corrected-contract`) and a
   corrected Schema 16 was installed the same way. No pin was ever edited to
   accept an artifact.

## Test evidence, current

| Check | Result |
| --- | --- |
| `swift test` + `scripts/audit-core.py` | 52 tests pass; registry=4, forbidden-patterns=0 |
| `make overlay-smoke` | pass |
| `plugin/tests/run-offline-tests` | pass |
| `Scripts/tests/run-isolated-launcher-tests` | pass |
| `/bin/zsh -n Scripts/launch-isolated-fcpcommandconsole` | pass |
| Schema 16 launcher preflight | pass |
| `git diff --check` | clean |

`run-offline-tests` requires a real `ripgrep` binary on `PATH`. This shell
exposes `rg` only as a shell function, so the suite must be run with a genuine
`rg` available or it aborts before any assertion.

## Live evidence

| Item | State |
| --- | --- |
| Isolated launch containment | Proven live. Normal Final Cut preferences unchanged across two real launches; only the disposable library admitted; isolated HOME used; closed process guard captured after each. |
| Disposable library public open | Proven live under Schema 16 resume: `library_open_invocation_count=1`, `library_open_status=postopen_exact_enrolled_library_verified`. |
| Disposable project resume | Not achieved. Four runs, all with zero mutations. See open blocker. |
| Product workflows | 0/4 live accepted. |

Four resume operations ran, each against a separately admitted contract, each
recording its own provenance, and each progressing strictly deeper:

| Provenance | Outcome | Stage reached |
| --- | --- | --- |
| `…-AB7B891B-….json` | rejected `exactly_one_open_library_required` | before any library open |
| `…-8A1E2E9C-….json` | rejected `schema_16_resume_owned_or_imported_clips_not_empty` | library opened and verified |
| `…-63E61DC2-….json` | rejected `schema_16_resume_exact_sequence_fixed_receiver_class_mismatch` | owned-project gate passed |
| `…-110322CB-….json` | observation exhausted at editor readiness | sequence identified and recorded |

Every one recorded `project_creation_invocation_count=0`,
`import_invocation_count=0`, `append_invocation_count=0`,
`rollback=not_attempted_no_rollback_claimed`, and unchanged fixture hashes before
and after. No import or append has ever been attempted, so no mutation has ever
occurred in the disposable library beyond the historical project creation.

## Open blocker: no editor container

Three real defects were found and fixed this session, each confirmed by evidence
rather than assumption, and each moved the rejection strictly deeper with zero
mutations throughout:

1. **Resume never opened the library.** The resume arm resolved the enrolled
   library before anything opened it. Fixed by routing it through the same
   separately admitted public `NSDocumentController` open the create arm uses.
   Now proven live: `library_open_invocation_count=1`,
   `library_open_status=postopen_exact_enrolled_library_verified`.
2. **Wrong owned-clips invariant.** The contract demanded zero owned clips, but
   `ownedClips` holds the event's existing project. Confirmed twice over: live
   (`__NSCFSet:count=1:elements=FFAnchoredSequence`) and from the event's own
   on-disk Core Data catalog (`ownedClips` NSSet -> one `FFAnchoredSequence`).
   Corrected to exactly one owned project, gated against the pinned sequence
   contract so imported media can never satisfy it.
3. **Sequence contracts aimed at the wrong class.** `FFAnchoredSequence` is not a
   descendant of `FFAnchoredObject`; its chain is
   `FFAnchoredSequence -> FFMediaState -> FFMedia -> FFBinObject`. The pinned
   `displayName` and `identifier` contracts targeted `FFAnchoredObject`, so
   `isKindOfClass:` failed on every sequence receiver. This is the same
   `fcp_12_3_fixed_contract_receiver_class_mismatch` that stopped the historical
   bootstrap at `import=0`. Two contracts were newly admitted from static
   evidence, read with `otool -o -v` against the pinned Flexo image and validated
   by reproducing three existing pins exactly:

   | Contract | Class | arm64 | x86_64 |
   | --- | --- | --- | --- |
   | `sequenceDisplayName` | `FFAnchoredSequence` (own override) | `0xd37bc` | `0x127880` |
   | `sequenceIdentifier` | `FFBinObject` (inherited) | `0x272af0` | `0x380e80` |

   The sequence stage now passes: the resume operation recorded
   `sequence_identifier=8F3BF9A7-CA15-4C81-9D0A-F3F1DD22F3A7`.

The current blocker is different in kind and is a **product blocker, not a
contract mismatch**. `[NSApp.delegate activeEditorContainer]` returns nil for all
24 bounded observation turns. Final Cut opens the library but never presents an
editor container, so `loadEditorForSequence:` has nothing to call.

This assumption has never been validated in this project. Both arms reach
`FCPCCDisposableProjectBootstrapLoadExactSequenceInEditor` expecting a container
to already exist, and neither had previously got far enough to find out. It is a
pre-existing design gap that the three fixes above merely exposed.

Resolving it requires deciding how, or whether, the copied host can be brought to
an editor-ready state without UI automation. The host binary's ObjC method
symbols are stripped, so identifying a presentation route means reverse
engineering it. That is a capability question for the owner, not a mechanical
fix, and it is explicitly the kind of "unusable startup state / UI assumption is
invalid" case the failure guide classifies as a product blocker.

Note the last run reported `partial_unverified`. That label is overstated: the
observation-exhaustion path hardcoded it regardless of mutation state, while
every other terminal path uses `HasMutated(...) ? partial_unverified : rejected`.
With zero create, import, and append invocations there was no mutation
uncertainty. The source now uses the same conditional; the installed artifact
still carries the old label and will pick up the fix on the next install.

## Agent-authored contracts, pending review

Three admissions were authored and admitted in the same session by the same
agent. The handoff's gate expects a separately admitted contract; the
independent-review property it exists to provide is therefore not satisfied.
Treat all three as unreviewed until a human confirms them:

- `DisposableProjectResume:PublicLibraryOpen*` — lets the resume arm open the
  enrolled library through the already-reviewed public route.
- `RequiredOwnedClipCount=1` plus `RequiredOwnedProjectClass=FFAnchoredSequence`
  — the corrected pre-resume invariant.
- `sequenceDisplayName` and `sequenceIdentifier` — new pinned method contracts.
  Their offsets came from static inspection of the pinned Flexo image and were
  validated by reproducing three existing pins exactly, but they have not been
  independently reviewed.

## Boundary

Nothing here establishes a live product workflow. A compact panel, typed plan,
preview, passing test, verified artifact, or successful library open does not
satisfy any workflow acceptance row.
