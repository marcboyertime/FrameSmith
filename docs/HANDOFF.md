# FCPCommandConsole Phase 1 handoff

This is the recovery-first, evidence-backed continuation record for a new AI. Treat
every item marked historical, damaged, interrupted, or unverified as a constraint,
not as completion. The immediate objective is to restore one canonical copied-app
artifact before continuing any product work.

## Authority and hard safety boundary

The user authorizes full local filesystem, terminal, process, and network access for
all work in this repository and its stated runtime paths, without recurring approval
requests. That authority does not relax these hard rules:

- Never modify /Applications/Final Cut Pro.app, a production Final Cut library, or
  user media. The only permitted host is the exact copied app below.
- Never use AppleScript, Accessibility APIs, simulated keyboard/mouse input,
  coordinate-based UI automation, dialog/responder fallback, or generic
  selector/method dispatch. Live FCPXML project replacement is hard-prohibited;
  bounded offline fixture or diagnostic use is allowed only when it cannot touch a
  Final Cut project, production library, or user media.
- Never stop, weaken, bypass, unload, or otherwise interfere with SafeSight.
- Never use remote Git or disclose secrets. Paid calls and media uploads require
  explicit approval for the exact operation before they occur.
- Routine free downloads are allowed under the granted network authority when the
  exact source is recorded, its license is reviewed and recorded, and the downloaded
  file is hash-verified before use. They never authorize a paid call or media upload.
- Never overwrite sources, fixtures, libraries, provenance, preferences, or copied
  artifacts to conceal a mismatch. Preserve failure evidence.
- Never claim a workflow is working from source, tests, a signature, a launch, or
  a dirty diff. Live acceptance requires the exact evidence listed below.

Safety-rule review:

| Category | Current rule | Meaning |
| --- | --- | --- |
| Hard | Stock app, production libraries/media, SafeSight, UI automation, live FCPXML project replacement, generic dispatch, secrets, remote Git | Prohibited without exception in this Phase 1 work. |
| Relaxed | Local filesystem, terminal, exact copied-process, network permissions, and routine free downloads with source/license/hash evidence; approved paid/upload operation | Broad local authority is granted; do not request recurring approval for ordinary in-scope work. Paid calls or media upload still require explicit approval for that exact operation. |
| Refined | Copied-app recovery and launch | Only the exact copied app and disposable runtime root may be touched; every mutation is gated by identity, provenance, process closure, and preference comparison. |
| Scope | Product completion | Four workflows must be independently live accepted. Artifact recovery, static tests, or partial bootstrap evidence is not product completion. |

## Fixed paths and current state

| Item | Path or state |
| --- | --- |
| Repository | /Users/marcboyer/Developer/FCPCommandConsole |
| Runtime root | /Users/marcboyer/Movies/FCPCommandConsole |
| Copied app | /Users/marcboyer/Applications/SpliceKit/FCPCommandConsole/Final Cut Pro - FCPCommandConsole.app |
| Immutable stock app | /Applications/Final Cut Pro.app |
| Canonical recoverable artifact | Signed Schema 14 copied app after fail-closed recovery |
| Recovery evidence directory | /Users/marcboyer/Movies/FCPCommandConsole/provenance/recovery-20260803T063015Z-schema15-policy-flattening |
| Historical partial project evidence | /Users/marcboyer/Movies/FCPCommandConsole/provenance/disposable-project-bootstrap-B42DFA39-B63E-4050-9CDD-B4E2B00DACBA.json |
| Historical postlaunch baseline | /Users/marcboyer/Movies/FCPCommandConsole/provenance/postlaunch-schema15-partial-20260803T054100Z |

The current artifact situation is deliberately not a Schema 15 success:

1. The canonical signed artifact is Schema 14, restored through fail-closed recovery.
2. A damaged Schema 15 artifact had the exact runtime and helper but a flattened
   policy. It is damaged and must not be launched or used as an update source.
3. A rebuild intended to repair that state is unverified and has mismatched runtime,
   helper, and CandidateCDHashFull values. It is not canonical and must not replace
   the recovered Schema 14 artifact.
4. Six interrupted Schema 16 source files are dirty. They are source-in-progress,
   neither installed nor accepted.
5. 52 tests and overlay smoke were rerun and passed current at handoff. The current offline suite fails
   because it still expects a Schema 15 fragment. That failure blocks any source or
   installation claim until corrected and rerun.
6. Live workflow acceptance is 0/4.

Recovery chronology: the fail-closed recovery transaction did not launch Final Cut
and did not run launcher preflight. Its artifact result is recovery evidence only;
the separate Schema 15 and Schema 16 preflight gates remain required before any
future copied-app launch.

Start a new session with read-only orientation only:

    cd /Users/marcboyer/Developer/FCPCommandConsole
    sed -n '1,260p' AGENTS.md
    git status --short
    git log -12 --oneline
    git diff --stat
    git diff --check
    find /Users/marcboyer/Movies/FCPCommandConsole/provenance/recovery-20260803T063015Z-schema15-policy-flattening -maxdepth 2 -type f -print | sort
    sed -n '1,260p' /Users/marcboyer/Movies/FCPCommandConsole/provenance/recovery-20260803T063015Z-schema15-policy-flattening/outcome.txt
    sed -n '1,260p' /Users/marcboyer/Movies/FCPCommandConsole/provenance/recovery-20260803T063015Z-schema15-policy-flattening/pre-state.txt

The recovery directory has no summary.json. outcome.txt and pre-state.txt are the
authoritative recovery narrative inputs; direct copied-app checks are the only way
to confirm the current artifact. Do not invent a replacement path or edit evidence.

## What is proven, historical, and blocked

| Evidence class | State | Exact interpretation |
| --- | --- | --- |
| Registry/core foundation | Proven in source | Four typed workflow definitions, parsing/schema/policy/math, provenance and cost foundations, deterministic overlay generation, compact read-only panel, and bounded helper bridge exist. |
| Core test evidence | Current pass at handoff | 52 Swift tests and overlay smoke were rerun and passed. Rerun after relevant edits; this does not prove Final Cut execution. |
| Offline suite | Currently blocked | It fails on a current Schema 15 fragment expectation. Diagnose and repair the expectation before accepting a Schema 16 source change. |
| Canonical copied artifact | Recoverable | Signed Schema 14 after fail-closed recovery is the only current canonical base. |
| Damaged Schema 15 | Rejected evidence | Runtime/helper happened to match expected values, but flattened policy invalidates the artifact. It must not be launched or become an update base. |
| Rebuilt candidate | Unverified/rejected | Runtime, helper, and CandidateCDHashFull mismatch; no install, launch, or promotion. |
| Project bootstrap | Historical partial live evidence | One project was created; import and append were zero due to a fixed receiver-class mismatch. It is not a completed project bootstrap. |
| Panel | Disabled shell | Apply/Undo and planner binding are disabled. |
| Product workflows | 0/4 accepted | No workflow has live Final Cut acceptance. |

Historical partial-project provenance records create=1, import=0, append=0,
observation_turns=2, unchanged fixture hashes, status=partial_unverified, and
rollback=not_attempted_no_rollback_claimed. Its reason is
fcp_12_3_fixed_contract_receiver_class_mismatch. Preserve it as a boundary for
future diagnostics; never retry around it without a newly admitted fixed contract.

## Interrupted Schema 16 work

The following six dirty files are interrupted source work and must be inspected
before any edit, test claim, install, or cleanup:

    plugin/patcher/update-copied-runtime
    plugin/scripts/build-minimal-runtime
    plugin/splicekit_minimal/Resources/FCPCCOnboardingQueryCompatibility.plist
    plugin/splicekit_minimal/Sources/FCPCommandConsoleRuntime.m
    plugin/tests/MutationStubTests.m
    plugin/tests/run-offline-tests

Read-only inspection:

    git diff -- plugin/patcher/update-copied-runtime plugin/scripts/build-minimal-runtime plugin/splicekit_minimal/Resources/FCPCCOnboardingQueryCompatibility.plist plugin/splicekit_minimal/Sources/FCPCommandConsoleRuntime.m plugin/tests/MutationStubTests.m plugin/tests/run-offline-tests
    git diff --check
    rg -n 'SchemaVersion|Schema 15|Schema 16|RESUME|resume|CandidateCDHashFull|partial_unverified' plugin/patcher/update-copied-runtime plugin/scripts/build-minimal-runtime plugin/splicekit_minimal/Resources/FCPCCOnboardingQueryCompatibility.plist plugin/splicekit_minimal/Sources/FCPCommandConsoleRuntime.m plugin/tests/MutationStubTests.m plugin/tests/run-offline-tests

The intended direction is a separate exact resume route with exact empty-project
admission and bounded stage diagnostics. It must not be treated as complete until:
the source diff is understood; the failing offline expectation is fixed; all relevant
tests pass; a fully verified canonical Schema 15 predecessor admits the update; a
new installed artifact verifies exactly; and a bounded live operation produces its
own provenance.

## Recovery-first ordered path

1. Preserve the current repository state. Read the six-file diff and recovery
   evidence. Do not reset, stash, checkout, remove, or overwrite anything.
2. Establish the canonical base from the recovery record. Verify that the exact
   copied artifact identified there is signed Schema 14. Record observed
   runtime/policy/helper hashes and CandidateCDHashFull in new evidence; compare,
   do not alter.
3. Preserve the damaged Schema 15 donor and the unverified rebuilt candidate as
   separate evidence. Do not launch either, use the unverified rebuild as a donor,
   or copy either artifact into the canonical location.
4. Determine whether every potential recovery prerequisite exists: the unchanged
   damaged-complete-copy donor, exact abb1a7f policy bytes, recorded signing identity,
   exact top-app entitlements, helper preservation checks, and the documented
   same-volume atomic-swap mechanism. If any prerequisite is absent, stop before
   artifact mutation and record the missing prerequisite. Schema 14 does not directly
   admit a Schema 16 update.
5. Only if every prerequisite is present, use the potential staged-donor recipe to
   reconstruct, independently verify, and atomically install an exact or newly
   admitted Schema 15 artifact. The unverified rebuilt candidate remains forbidden.
   Repeat direct verification after the swap.
6. Run Schema 15 preflight against that verified canonical Schema 15 artifact. It
   must prove copied/stock process closure, isolated-home containment, disposable
   library admission, and unchanged normalized normal preferences. Do not run a live
   launch merely to test recovery.

   Pre-recovery current gate: the launcher is pinned to Schema 15 and
   CandidateCDHashFull 21e99732e747821cb4aa06467b195f33247a15fad7535ea132e77609c3820b44.
   It must fail closed against the canonical Schema 14 artifact. Do not run a live
   launch and do not weaken or bypass this gate before the exact Schema 15 recovery
   artifact has been independently verified and admitted.
7. Only after canonical Schema 15 and its preflight proof exist, diagnose the Schema
   16 offline failure. It is a stale Schema 15 fragment expectation, not proof that
   Schema 16 is correct. Align source tests and launcher/update admission checks with
   the intended fail-closed Schema 16 contract.
8. Finish the six-file Schema 16 source change with exact fixed interfaces only.
   Resume must be exclusive of project-create and library-create arms; admit exactly
   one enrolled library, one default event/media project, one exact-name sequence with
   stable identity, zero owned/imported clips, and zero primary-storyline items.
   Wrong nonnil receivers must fail at a bounded stage; nil may be pending only at
   explicit editor-readiness boundaries. No automatic retry, no project creation in
   resume, no pointer/object descriptions in provenance, and no rollback claim.
9. Run source and policy tests. A required minimum is:

       /bin/zsh -n Scripts/launch-isolated-fcpcommandconsole
       /bin/zsh Scripts/tests/run-isolated-launcher-tests
       /bin/zsh plugin/tests/run-offline-tests
       make test
       make overlay-smoke
       git diff --check

   Do not progress while any test fails. Capture the exact failure text and diagnose
   it; never weaken a test merely to restore green output.

   The exact current offline blocker is:

       run-offline-tests: patcher current Schema 15 policy contract is missing: " != "15"
10. Transactionally install Schema 16 only through the copied-app updater after its
    exact predecessor admission checks accept the fully verified canonical Schema 15
    artifact. Capture new immutable provenance before and after. The damaged Schema
    15 donor and unverified rebuilt candidate remain forbidden update sources.
11. Verify the installed Schema 16 result before any launch: schema/policy structure,
   runtime/helper hashes, signature, Team, CandidateCDHashFull, stock identity,
   entitlement limits, and exact copied path must all match the new provenance.
   A mismatch is a fail-closed recovery event, not a repair invitation.
12. Run the exact Schema 16 launcher preflight. It must prove no stock or copied Final Cut
   process is running, the isolated home is used, only the disposable library is
   admitted, and normalized normal-Final-Cut preferences are unchanged.

   Before this preflight, launcher source and pins must be updated and independently
   verified for the exact installed Schema 16 artifact. If the launcher still has a
   Schema 15 pin, it must fail closed and the path stops.
13. Run at most one newly admitted disposable resume operation. It needs unique
    provenance, exact fixture hash checks, zero production-library access, bounded
    operation counts, readback, and a closed post-exit guard. Any uncertainty is
    rejected or partial_unverified, never silently retried.
14. Only after bootstrap evidence is complete, admit each workflow independently
    using the acceptance matrix. Refresh stale documentation only from fresh
    evidence.

STATUS.md and docs/PHASE1_ACCEPTANCE.md lag current progress and are not
authoritative until refreshed from verified evidence.

## Failure guide

| Symptom | Likely cause | Safe diagnostic | Required fix | Never do |
| --- | --- | --- | --- | --- |
| Policy is flattened while runtime/helper hashes look exact | Partial/corrupt Schema 15 artifact | Compare policy structure and recovery record; inspect hashes/signature without launching | Return to canonical recovered Schema 14; repair source/admission path before a new build | Treat matching runtime/helper as sufficient, launch it, or copy it over canonical artifact |
| Rebuild runtime/helper/CDHash differs from expected | Build/sign/install provenance drift | Compare each artifact identity against the new build and recovery provenance | Fail closed; locate the first divergent build/update step and rebuild from canonical base | Re-sign arbitrarily, patch hashes, or replace evidence |
| Offline suite fails Schema 15 fragment | Interrupted expectation conflicts with intended schema contract | Run suite once, preserve exact failure, inspect only cited source/test fragments | Correct the expectation and its corresponding fail-closed admission test, then rerun full suite | Delete/skip the assertion or call failure irrelevant |
| Six files are dirty | Interrupted source work | Review full diff and status before edits | Continue only the intended bounded change; keep ownership narrow | Reset, checkout, stash, or mix unrelated cleanup |
| Launcher preflight refuses to run | Process, identity, isolation, preference, or policy guard failed | Preserve preflight directory and inspect its text/JSON evidence | Resolve the named guard from source/provenance, then rerun preflight | Bypass launcher, invoke a bare host, or suppress guard checks |
| Preference comparison drifts | Isolation regression or normal preference write | Preserve before/after snapshots and recovery provenance | Stop launches; diagnose exact write path and restore containment design | Delete/edit normal preference files to fabricate equality |
| Final Cut remains running | Unexpected child/process state | Record PID and exact executable identity with lsof and launcher provenance | After exact copied-app path and lsof proof, send TERM only to that PID; prove closed guard before proceeding | killall, pkill, broad-name matching, -9, or terminating stock/SafeSight |
| Historical project path reports receiver mismatch | Fixed contract does not match runtime receiver class | Read bounded provenance stage/reason and compare fixed contracts | Add a separately admitted exact contract or reject operation; rerun only after admission | Generic dispatch, selector discovery, pointer logging, or retries |
| Fixture import/append count is nonzero but verification incomplete | Mutation uncertainty | Capture operation and postlaunch provenance; label partial_unverified | Stop and investigate before any next mutation | Claim success, auto-retry, or claim rollback not observed |
| A workflow appears in panel but controls remain disabled | Read-only shell only | Inspect panel state and transaction admission evidence | Keep disabled until its workflow row passes | Enable controls based on source tests or visual presence |
| DepthFlow/output needs external assets or service | Dependency, source, license, hash, approval, or upload boundary not met | Inspect local inputs plus exact free-source, recorded-license, and hash evidence | Use a routine free dependency only with exact source, recorded license, and hash verification; obtain explicit approval only for paid calls or media uploads; otherwise use disclosed native fallback | Use unrecorded, unlicensed, or unhashed downloads; upload media or call a paid service without explicit approval; claim generated media without evidence |
| Stock hash or copied path differs | Wrong target or mutation risk | Compare exact paths and recorded identity before touching app | Stop and restore scope to exact copied app | Patch stock app or continue with ambiguous path |

## Workflow acceptance matrix

| Workflow | Current state | Required evidence before enablement |
| --- | --- | --- |
| Targeted rotate/zoom | Typed math/static path only; native execution disabled | Exact selected clip/source/handle/revision admission; one bounded transform write/readback; validated coordinate convention; transaction provenance; native undo and exact original keyframe rollback in disposable library. |
| Native dissolve | Registry only | Exact adjacent clips, range, handles, revisions, typed duration, native transition readback, provenance, undo/rollback, and manual playback acceptance. |
| Old-TV editable composition | Registry/composition definition only | Native editable layers/effects with every parameter represented in typed plan; exact target/readback; transaction provenance; undo/rollback; manual visual acceptance. |
| Living still | Registry plus local-generation-or-explicit-native-fallback policy only | Routine free dependencies require exact source, recorded license, and hash verification; paid calls/media uploads require exact explicit approval. Then require approved local output with hashes/cost/provenance or disclosed native fallback, source preservation, native insertion/readback, undo/rollback, and manual motion/quality acceptance. |

All rows are 0/4 live accepted. A compact panel, typed plan, preview, core test, or
partial bootstrap result does not satisfy any row.

## Evidence commands for a resumed session

These commands are read-only and safe to run after orientation. Do not use a
configuration-extraction command without a specified output destination; this
handoff intentionally does not rely on such commands.

    git status --short
    git log -12 --oneline
    git diff --stat
    git diff --check
    git diff -- <the-six-interrupted-files>
    shasum -a 256 '/Applications/Final Cut Pro.app/Contents/MacOS/Final Cut Pro'
    codesign -dvvv '/Users/marcboyer/Applications/SpliceKit/FCPCommandConsole/Final Cut Pro - FCPCommandConsole.app' 2>&1
    sed -n '1,260p' /Users/marcboyer/Movies/FCPCommandConsole/provenance/recovery-20260803T063015Z-schema15-policy-flattening/outcome.txt
    sed -n '1,260p' /Users/marcboyer/Movies/FCPCommandConsole/provenance/recovery-20260803T063015Z-schema15-policy-flattening/pre-state.txt
    find /Users/marcboyer/Movies/FCPCommandConsole/provenance -maxdepth 1 -type f -name '*.json' -print | sort
    rg -n 'AppleScript|Accessibility|FCPXML|CGEvent|osascript|generic.*dispatch|partial_unverified' plugin Scripts config

For a verified next artifact, record all observed values in provenance and compare
them to its declared canonical source. Do not copy old hash values forward.

## Completion checklist

- [ ] Recovery record proves the signed Schema 14 canonical base and keeps damaged
      Schema 15/unverified rebuild candidates rejected.
- [ ] The six interrupted Schema 16 changes are fully reviewed, tested, and
      installed only through an exact admitted update from the canonical base.
- [ ] Offline suite, launcher suite, core tests, and overlay smoke pass currently.
- [ ] Installed copied app, signature, policy, runtime/helper hashes, CDHash,
      stock identity, preference comparison, and process guard are freshly proven.
- [ ] Historical partial bootstrap evidence remains preserved and does not inflate
      operation counts or workflow claims.
- [ ] Each of four workflows has independent live mutation/readback/undo/rollback/
      provenance/manual acceptance evidence.
- [ ] STATUS.md, docs/PHASE1_ACCEPTANCE.md, and this handoff reflect only current,
      verified facts.
- [ ] No hard safety rule was violated.

## Exact artifact ledger

These values are the acceptance pins for the current recovery decision. They are
not interchangeable across artifacts. A matching file hash does not cure an invalid
signature, flattened policy, wrong predecessor, or missing full verification.

| Artifact state | Policy SHA-256 | Runtime SHA-256 | Helper SHA-256 | CandidateCDHashFull | Team | Stock executable SHA-256 | Interpretation |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Canonical signed Schema 14 | 6b9a32e7f7801e62aa7b6399c881d827f8d7ede84d9f106ab63fdf5a3585ad95 | d9ef52a70e6d4467debdc89b569422b3fb5768322fbe94e373c4cd6f29186d8d | ec422b93697a4caefb730c46e1f2458052bb2d396c1053bb300bcbb200cdd961 | f53b89063f7215d1978835ded99a1f7246a997bc87606159c23b3753731e4171 | KDV9RC892F | 6d29cb4326c2f35c96fbc57f29741fba8b5156265e188b19c975bc6cefba8390 | Only current canonical recovery base. |
| Damaged Schema 15 complete-copy donor | 9643b41c44bce8800bf882318324ebefc62c6dc86741a7c0fdc4a315019a026f (flattened and bad) | 856c25f6614fe627fa8ea634f5ace0b67a01ba35319560e1d4c1d493c864b47d | ca4c63838e115f80c0657d95550bd8cc3cc09535c519ef542f3d21a8f191a299 | 21e99732e747821cb4aa06467b195f33247a15fad7535ea132e77609c3820b44 (old metadata only; signature invalid) | KDV9RC892F | 6d29cb4326c2f35c96fbc57f29741fba8b5156265e188b19c975bc6cefba8390 | Never launch/update from it; potential staged donor only under the recipe below. |
| Exact good Schema 15 policy source at abb1a7f | 081c0e15616afae5109773bf633c922662fd160f3b186aad2e21c7efeb7fd125 | not an artifact | not an artifact | not an artifact | not an artifact | not an artifact | Exact policy bytes permitted only for the potential staged recovery recipe. |
| Unverified rebuilt candidate | 081c0e15616afae5109773bf633c922662fd160f3b186aad2e21c7efeb7fd125 | 6593359fe3d1265fa475e62756e422f4a419f67eb2fc7a800b9e32b3c13da63c | 8bc03161cfda479de52d405116bbb0c8a88aa8969d47922c3e823bf38067bc7a | 82cd0f2c927db57d50389f3e685d8c5868f93cab1f0252d9e5a12463f5545dbc | KDV9RC892F | 6d29cb4326c2f35c96fbc57f29741fba8b5156265e188b19c975bc6cefba8390 | Signature is valid but this is rejected and unreviewed because runtime/helper/CDHash do not match the required artifact. |

The supported Final Cut target is version 12.3, build 450152. Any version, build,
slice UUID, ABI, method placement, type encoding, implementation offset, receipt,
or embedded-framework change is a new compatibility event. Existing pins must fail
closed rather than being generalized.

Read-only artifact comparison commands, with all paths explicit:

    app='/Users/marcboyer/Applications/SpliceKit/FCPCommandConsole/Final Cut Pro - FCPCommandConsole.app'
    root="$app/Contents/Frameworks/FCPCommandConsoleRuntime.framework/Versions/A"
    shasum -a 256 "$root/FCPCommandConsoleRuntime" "$root/Resources/FCPCCOnboardingQueryCompatibility.plist" "$root/Resources/PlannerHelperPayload/fcpcommandconsole-planner-helper"
    shasum -a 256 '/Applications/Final Cut Pro.app/Contents/MacOS/Final Cut Pro'
    codesign --verify --deep --strict --verbose=4 "$app"
    codesign -dvvv "$app" 2>&1 | rg 'TeamIdentifier=|CandidateCDHashFull|Identifier='
    plutil -convert xml1 -o - "$root/Resources/FCPCCOnboardingQueryCompatibility.plist" | sed -n '1,220p'

The final command writes only to standard output because -o - is explicit. Never
use a configuration-extraction command that omits an explicit output destination.

## Potential Schema 15 recovery recipe -- not performed or guaranteed

This is the only contemplated use of damaged-complete-copy.app. It is not a generic
update source, is never launchable, and is not a canonical artifact. The recipe may
be considered only after the recovery record, direct artifact checks, exact signing
inputs, and current source state are independently reviewed.

1. Create a new private temporary staging directory on the same volume as the copied
   app. Confirm it is absent before creation and is not a symlink.
2. Stage a full copy from damaged-complete-copy.app into that temporary directory.
   Preserve the donor unchanged. Do not stage from the unverified rebuilt candidate.
3. Replace ONLY this policy file in the staged app with the exact bytes from
   abb1a7f:

       Contents/Frameworks/FCPCommandConsoleRuntime.framework/Versions/A/Resources/FCPCCOnboardingQueryCompatibility.plist

   The source bytes must match SHA-256
   081c0e15616afae5109773bf633c922662fd160f3b186aad2e21c7efeb7fd125. Do
   not replace runtime, helper, host executable, receipt, or any unrelated embedded
   resource.

   Potential extraction and copy commands, to be used only after steps 1-2 with
   validated temporary-source and temporary-stage directories. They create no shell
   redirection target:

       temp_source=$(mktemp -d /private/tmp/fcpcc-schema15-policy.XXXXXX)
       git archive abb1a7f plugin/splicekit_minimal/Resources/FCPCCOnboardingQueryCompatibility.plist | tar -x -C "$temp_source"
       policy_rel='Contents/Frameworks/FCPCommandConsoleRuntime.framework/Versions/A/Resources/FCPCCOnboardingQueryCompatibility.plist'
       /usr/bin/ditto "$temp_source/plugin/splicekit_minimal/Resources/FCPCCOnboardingQueryCompatibility.plist" "$stage/$policy_rel"
       shasum -a 256 "$stage/$policy_rel"

   The resulting hash must be exactly the good Schema 15 policy hash in the ledger.
4. Re-sign the project framework and then the top-level staged app using the exact
   recorded signing identity, options runtime, and timestamp none. The framework has
   no invented entitlement input. Only the top-level app uses the exact recorded app
   entitlements. The intended order is framework first, top-level app second. Do not
   infer identity or app entitlements from the damaged signature; take them from the
   documented recovery record and current signing policy.

   Potential signing shape, with every variable supplied from recorded evidence and
   never guessed:

       codesign --force --sign "$recorded_identity" --options runtime --timestamp=none "$stage/Contents/Frameworks/FCPCommandConsoleRuntime.framework"
       codesign --force --sign "$recorded_identity" --entitlements "$recorded_app_entitlements" --options runtime --timestamp=none "$stage"
5. Never re-sign the nested planner helper. Prove its exact hash and signature are
   unchanged before and after framework/app signing.
6. Perform full independent verification of the staged result: every ledger hash,
   policy structure, runtime/helper path, nested helper signature, framework and app
   signatures, Team, CandidateCDHashFull, entitlement allowlist, copied path, stock
   hash, receipt, and no-extra-artifact inventory must match the recovery contract.
7. Only after all verification succeeds and Final Cut process guards prove both stock
   and copied app closed, use the reviewed same-volume atomic directory-exchange
   mechanism to swap staged result into the canonical copied-app location. Retain the
   prior canonical app as a recoverable sibling until post-swap verification passes.
8. Repeat full direct verification after the atomic swap. A pass before the swap is
   insufficient.

This recipe is potential only. It was not performed by this handoff, does not prove
that the resulting Schema 15 app will work, and does not authorize a launch. Never
repair the canonical app in place, never overwrite it file-by-file, and never use
rm/cp/mv sequences as a substitute for a reviewed atomic swap.

## Current test and repository evidence

| Item | Actual current result | Boundary |
| --- | --- | --- |
| Base HEAD | f940233 | This handoff baseline; inspect live HEAD before continuing. |
| Dirty interrupted change | 521 insertions, 47 deletions across six files | In-progress source only. Do not call it installed or complete. |
| Swift/core tests | 52 passed, rerun current at handoff | Core evidence only; no native Final Cut proof. |
| Overlay smoke | passed, rerun current at handoff | Overlay artifact evidence only. |
| Offline runtime suite | failed | Exact failure: run-offline-tests: patcher current Schema 15 policy contract is missing: " != "15". This blocks promotion. |
| Launcher zsh syntax | passed current at handoff | Syntax evidence only; it does not admit an artifact or live launch. |
| Git whitespace check | git diff --check passed current at handoff | Repository-diff hygiene only; it does not prove source or runtime behavior. |
| Launcher/policy result | must be rerun after the source test repair | Earlier results cannot certify a changed source tree. |
| Workflows | 0/4 live accepted | No exception. |

The dirty six files are exactly the six listed above; do not broaden the change set
with formatting, dependency, documentation, or cleanup work until recovery and test
gates are stable.

## Runtime subtree map and evidence retention

All runtime material belongs under /Users/marcboyer/Movies/FCPCommandConsole:

| Subtree | Purpose | Handling rule |
| --- | --- | --- |
| previews | Local visual previews | Generated; never use as proof of Final Cut insertion. |
| renders | Local rendered artifacts | Keep outside Git; preserve source/hash relationship. |
| overlays | Deterministic overlay outputs | Validate alpha/codec/readback independently. |
| depth-maps | Local depth artifacts | Routine free downloads require exact source/license/hash evidence; paid calls and media uploads require explicit approval; keep source provenance. |
| logs | Bounded local diagnostics | No secrets, pointers, or arbitrary object descriptions. |
| jobs | Local operation records | Typed, bounded, and idempotent where admitted. |
| provenance | Immutable operation/recovery/postlaunch evidence | Append/capture; do not hand-edit to change outcome. |
| usage | Cost/approval ledger | No paid operation absent explicit approval. |
| fixtures | Exact disposable inputs | Verify hash before/after every admitted operation. |
| isolated-final-cut-home | Copied-app-only HOME/CFFIXED_USER_HOME/cache area | Never substitute normal user home. |
| FCPCommandConsole Test.fcpbundle | Disposable test library only | Never point to any production library. |

## Expanded failure and recovery table

| Symptom | Likely cause | Safe diagnostic | Required fix | Never do |
| --- | --- | --- | --- | --- |
| Configuration command lacks explicit -o output | Tool may write an implicit destination or conceal output behavior | Read command/help and use explicit -o - for standard output | Rewrite diagnostic with explicit destination before use | Run plutil extraction/conversion with no explicit output target |
| Signature invalid after resource replacement | Embedded resource changed after signing | Verify framework, nested helper, and app separately | Re-sign only staged artifact in reviewed order, then independently verify | Launch, ignore nested failure, or sign canonical app in place |
| Rebuild hashes vary across runs | Nondeterministic build inputs, signing, timestamps, or stale output | Compare runtime/helper/CDHash and build logs across clean staged builds | Identify and pin divergent input before another candidate | Choose whichever hash looks convenient |
| Schema or CDHash pin is stale | Source/install changed without renewing full evidence | Compare versioned policy, code signature metadata, and provenance | Fail closed; renew only after full verification | Edit a pin to accept an unverified artifact |
| Final Cut 12.3 build 450152 or ABI drifts | Host update changed fixed contract | Compare version/build, UUIDs, ABI/encoding/offsets, receipt, and frameworks | Start a new compatibility investigation and reject old route | Reuse a selector/offset from another build |
| Blank 1024x768 workspace; New/Open Library disabled; Option/Command-1 does nothing | Copy reached an unusable startup state or UI assumption is invalid | Capture process/app evidence and policy state without input simulation | Treat as a product blocker; diagnose copied-host startup contract | Use keyboard simulation, Accessibility, coordinate clicks, or dialogs |
| Fixed receiver-class mismatch | Pinned class/implementation is not receiver at that stage | Read bounded stage/expected-class/selector/actual nil-or-class diagnostic | Add a separately admitted exact contract or reject | Generic dispatch, runtime discovery, pointers, or automatic retry |
| Duplicate project appears | Create/resume arms overlap or precondition ambiguous | Inspect operation counts and exact library/project traversal | Reject state; enforce exclusive arm and exact empty-project gate | Delete a project to hide duplicate evidence |
| partial_unverified result | Mutation/readback/postcondition remains uncertain | Preserve operation and postlaunch provenance | Stop further mutation and investigate from evidence | Call it success, retry automatically, or claim rollback |
| Normal preferences drift | Preference daemon leakage despite isolation | Preserve before/after normalized snapshots and launcher evidence | Retain __CFPREFERENCES_AVOID_DAEMON=1 plus exact normal-file denial; locate write path | Disable comparison or edit preferences to match |
| Broad process termination would be needed | PID identity is unknown or process guard was bypassed | Prove exact copied executable with PID and lsof text identity | Use exact copied PID only after proof; recapture closed guard | killall, pkill, -9, stock termination, or any SafeSight action |
| Native dissolve rejects or looks wrong at trim | Adjacent clips lack handles or range/revision stale | Validate typed adjacency, handles, range, and revisions before mutation | Reject with actionable precondition; use only eligible clips | Force a transition, extend media, or substitute FCPXML |
| Targeted transform applies to wrong clip | Selection/source/timeline revision became stale | Recapture selected identity, source identity, handles, and revision at commit point | Reject stale transaction and require a new plan | Reuse a stale handle or infer target from UI coordinates |
| Overlay loses transparency or is unreadable | Alpha pixel format, codec, duration, or geometry mismatch | Inspect deterministic output metadata and decode/readback | Correct closed overlay generator and rerun smoke | Present overlay preview as native edit evidence |
| Living-still path lacks dependencies | Local DepthFlow/runtime assets absent or incompatible | Inspect local dependency inventory, exact free source, recorded license, hash, and job prerequisites | Use a routine free download only with source/license/hash evidence; obtain explicit approval for paid calls or media uploads; otherwise disclose native fallback | Download from an unrecorded source, upload media, or call a paid service without approval |
| Provenance/rollback is incomplete | Transaction omitted prestate/readback/undo data | Compare transaction schema and operation evidence | Keep action disabled until exact provenance and rollback evidence exists | Invent rollback, delete evidence, or downgrade requirement |
| Updater audits too few embedded artifacts | Only host or framework checked; helper/resources omitted | Enumerate all fixed embedded artifacts and signatures | Expand verifier to cover runtime, policy, helper, bundle, manifest, host, receipt, entitlements | Verify only top app and call it complete |
| Source test passes but live evidence absent | Test scope was mistaken for product behavior | Read test boundary and workflow matrix | Keep status source/offline until live operation proves it | Claim a live workflow from tests or code review |
| Generated/provenance files appear in Git | Runtime subtree leaked into index | Inspect staged names and .gitignore scope | Unstage and preserve files only under runtime root | Commit generated media, logs, jobs, provenance, or copied app |
| Paid call/upload/secret appears necessary | Scope crossed approval boundary | Check approval and local fallback | Stop or obtain explicit approval; redact/rotate secret exposure | Place secrets in argv/logs or upload without approval |
| Path is noncanonical or includes symlink | Target may escape disposable scope | Resolve canonical path and reject symlink components | Require exact canonical approved path | Follow symlink, glob broad paths, or operate on parent recursively |
| SwiftPM lock/contention blocks tests | Another build holds package/build state | Inspect process and lock evidence without killing broadly | Wait for known build or use bounded project build procedure | Delete locks/artifacts blindly or terminate unknown process |
| Final Cut already running | Stock or copied process defeats isolated launch gate | Use launcher process identity checks and lsof | After exact copied executable-path and lsof proof, send TERM only to that PID; otherwise stop | Bare launch, stock interaction, or broad termination |
| Nested helper signature fails after re-sign | Framework/app signing did not preserve helper contract | Verify helper before framework then app and recheck after swap | Rebuild staged signing chain with recorded identity/entitlements/options | Trust top-level signature alone |
| Unverified rebuild looks signed | Signature validity is narrower than artifact acceptance | Compare all ledger values and policy structure | Keep rejected until every acceptance pin/provenance condition passes | Promote based on valid signature alone |
| Canonical app needs file-by-file repair | Repair would create an unproven mixed artifact | Follow potential staged donor recipe only | Build/verify separate stage then documented atomic swap | Modify canonical app in place |

## Refined safety decisions for continuation

The following refinements are intentional and must be retained:

- Bounded read-only receiver diagnostics are allowed. They may record a fixed stage,
  expected fixed class, expected fixed selector, and actual state limited to nil or
  class. They must never record pointers, object descriptions, arbitrary selectors,
  or runtime discovery output.
- An old CDHash may be repinned only after a complete new artifact has passed full
  independent verification, including policy/runtime/helper hashes, signatures,
  entitlements, Team, stock identity, copied path, embedded inventory, and recorded
  provenance. Repinning is never a way to accept an existing mismatch.
- Exact copied-app PID termination is autonomously authorized after executable-path
  and lsof proof identifies that PID as the copied app. Use only TERM on that exact
  PID, then capture a closed process guard. This never authorizes stock or SafeSight
  termination, broad names, pkill, killall, or -9.

      kill -TERM "$exact_copied_pid"

  The variable must contain one already-proven copied-app PID, never a process name,
  pattern, list, stock PID, or SafeSight PID.
- The damaged Schema 15 app is prohibited as a launch/update source but is permitted
  solely as the unchanged donor for the potential temporary staging recipe. The
  unverified rebuilt candidate is not a donor.
- Full local authority is a convenience for evidence collection and bounded repair;
  it does not authorize unsafe product behavior, destructive cleanup, or scope
  expansion.

## Next 30-60 minutes: exact order

1. Read AGENTS.md, status, the six-file diff, recovery outcome.txt, and pre-state.txt.
2. Confirm the ledger values directly against the current canonical Schema 14 copied
   app and stock executable; preserve output as new recovery evidence, not chat-only
   assertion.
3. Decide whether the potential staged Schema 15 recovery recipe has every recorded
   signing input and an available documented atomic-swap mechanism. If not, stop before
   any artifact mutation and document the missing prerequisite.
4. If all prerequisites are present, perform only the staged, policy-only, re-sign,
   independent-verify, atomic-swap recovery sequence. Re-run direct checks after it.
5. Inspect and fix the Schema 16 offline-test expectation. The first required
   source gate is removal of the exact stale Schema 15 fragment failure without
   weakening the fail-closed schema contract.
6. Run the full source/launcher/core/overlay test set listed above. Do not install
   anything until every result is current and passing.
7. Use transactional copied-app installation from the verified canonical predecessor;
   capture pre/post provenance and reject any hash, signature, entitlement, or
   inventory drift.
8. Run isolated preflight. Confirm process closure, stock immutability, disposable
   library admission, isolated home, and normal-preference equality.
9. Run one exact resume operation only. Preserve new provenance regardless of result;
   stop on rejection or partial_unverified.
10. Begin workflow admissions in order only after resume evidence is complete:
    targeted rotate/zoom, native dissolve, old-TV composition, living still. Each
    remains disabled until its separate matrix row passes.

## Phase 1 completion and Phase 2 boundary

Phase 1 is complete only when all of the following are current and independently
proven: a canonical installed copied artifact; stock unchanged; clean preference and
process guards; source/offline/launcher/core/overlay evidence; bootstrap evidence
without uncertainty; and all four workflow rows with native write/readback,
transaction provenance, native undo, exact rollback, and manual acceptance.
Documentation must then be refreshed from those facts.

Phase 2 begins only after that completion boundary. Before its work starts,
docs/NEXT_CODEX_PROMPT.md must be refreshed to focus on reusable custom FCP effects,
melt, portal, masks, segmentation, tracking, and complex external editable
compositions. Retain docs/REFERENCE_LOCK.json and all associated license records as
the evidence boundary for any continued reference use.

Phase 2 may then consider those additional effects, broader media-generation
capability, new host compatibility work, or expanded user-facing behavior. None of
those activities is implied or authorized by Phase 1 recovery, and no Phase 2 work
can retroactively count as Phase 1 acceptance.
