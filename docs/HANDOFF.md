# FCPCommandConsole Phase 1 living handoff

Purpose: operational continuation record for the full Phase 1 goal. Evidence rules
are strict: a named command or artifact proves only its stated result. A source
diff, an offline test, an installed signature, or a launch never proves an
unobserved Final Cut mutation. Update this document with any change to these facts.

## Goal and non-negotiables

Phase 1 is a local-first private assistant with a compact Final Cut panel, typed
registry-driven plans, provenance, undo/rollback, and cost controls. It completes
only when exactly these four live editable workflows have individually passed
acceptance, tests/manual acceptance/docs are current, and a fresh Sol final reviewer
returns ship:

1. native.targeted_rotate_zoom
2. look.old_television
3. transition.natural_dissolve
4. motion.living_still (DepthFlow or explicit native fallback)

Absolute bans: no AppleScript, Accessibility API, simulated keyboard/mouse,
coordinate UI automation, responder/dialog fallback, FCPXML fallback, generic
method/selector dispatch, production library, user media, source overwrite, stock
app mutation, remote Git, paid call, or media upload without explicit approval. No
mocked completion and no claim based on unobserved behavior. Never touch SafeSight.

Stock Final Cut is immutable at /Applications/Final Cut Pro.app. Never build inside
or patch it. reference/ is read-only. Runtime payloads, fixtures, renders, jobs,
and provenance stay outside Git.

## Paths and live orientation

| Item | Exact path |
| --- | --- |
| Repository | /Users/marcboyer/Developer/FCPCommandConsole |
| Runtime root | /Users/marcboyer/Movies/FCPCommandConsole |
| Copied app only | /Users/marcboyer/Applications/SpliceKit/FCPCommandConsole/Final Cut Pro - FCPCommandConsole.app |
| Stock app | /Applications/Final Cut Pro.app |
| Isolated launcher | Scripts/launch-isolated-fcpcommandconsole |
| Read-only baseline capture | Scripts/capture-disposable-fcp-baseline |
| Offline runtime suite | plugin/tests/run-offline-tests |
| Launcher suite | Scripts/tests/run-isolated-launcher-tests |

At the start of a resumed session:

    cd /Users/marcboyer/Developer/FCPCommandConsole
    sed -n '1,260p' AGENTS.md
    git status --short
    git log -12 --oneline
    git diff --stat
    git diff --check

A dirty worktree may be intentional: a current Terra lane owns plugin/**. Preserve
it. Never reset, checkout, stash, or overwrite another agent's changes.

## Sol Advisor governance and preflight

Repository policy requires $sol-advisor:orchestration for all implementation.
Installed governing version is 0.3.0: primary architect Sol/High; sole implementation
lane Terra/High; fresh final reviewer Sol/High. Historical 0.2.0/Luna workers and
claims are evidence only, never an allowed current routing.

Before every delegation, run the non-mutating exactness check and require the exact
spawn types sol_advisor_terra_implementer and sol_advisor_sol_reviewer:

    skill_dir=/Users/marcboyer/.codex/plugins/cache/sol-advisor/sol-advisor/0.3.0/skills/orchestration
    installer="$skill_dir/../../scripts/install-agents.sh"
    sh "$installer" --check

Current recorded output: CHECK PASSED: Terra and Sol exactly match
.../0.3.0/agents; no legacy Luna file remains.

Observe native routing metadata and accept only Terra/High or Sol/High. Do not pass
model or effort overrides. If public metadata omits pin evidence:

    runtime_inspector="$skill_dir/../../scripts/inspect-agent-runtime.sh"
    sh "$runtime_inspector" <native-subagent-thread-id>

For final review record the observed sandbox and permission profile; requested
read-only is OS-enforced only if the observed sandbox type is read-only. If any
fix follows review, discard its verdict and obtain a new fresh Sol review.

## Current Git and installed-artifact facts

At document creation HEAD is 48a85bd Contain isolated Final Cut preference writes.
Inspect the live log before relying on that claim. Relevant predecessor chain:

    abb1a7f Pin isolated launcher to Schema 15 copy
    3db1cc0 Contain project bootstrap Audio Unit validation
    9bd136d Capture immutable Final Cut launch baselines
    2066331 Pin installed Schema 14 copy
    648340f Embed signed bounded planner helper bridge

Installed copy remains Schema 15 unless separately proven otherwise. Exact installed
evidence:

| Field | Exact value |
| --- | --- |
| Runtime SHA-256 | 856c25f6614fe627fa8ea634f5ace0b67a01ba35319560e1d4c1d493c864b47d |
| Policy SHA-256 | 081c0e15616afae5109773bf633c922662fd160f3b186aad2e21c7efeb7fd125 |
| Planner helper SHA-256 | ca4c63838e115f80c0657d95550bd8cc3cc09535c519ef542f3d21a8f191a299 |
| CandidateCDHashFull | 21e99732e747821cb4aa06467b195f33247a15fad7535ea132e77609c3820b44 |
| Team | KDV9RC892F |
| Verifier provenance | /Users/marcboyer/Movies/FCPCommandConsole/provenance/patch-20260803T053233Z-verify-56034 |

Read-only recheck. The helper is under PlannerHelperPayload, not beside the policy:

    app='/Users/marcboyer/Applications/SpliceKit/FCPCommandConsole/Final Cut Pro - FCPCommandConsole.app'
    root="$app/Contents/Frameworks/FCPCommandConsoleRuntime.framework/Versions/A"
    shasum -a 256 "$root/FCPCommandConsoleRuntime" "$root/Resources/FCPCCOnboardingQueryCompatibility.plist" "$root/Resources/PlannerHelperPayload/fcpcommandconsole-planner-helper"
    codesign -dvvv "$app" 2>&1 | rg 'TeamIdentifier=|CandidateCDHashFull'
    plutil -extract SchemaVersion raw "$root/Resources/FCPCCOnboardingQueryCompatibility.plist"

## Evidence-backed completed foundation

| Evidence class | Proven result | Boundary |
| --- | --- | --- |
| Source/offline | Four registry definitions, parser, schema, policy, math, deterministic overlay generator, panel shell, planner-helper package/bridge | Never proves a Final Cut mutation. |
| Tests | 52 Swift tests previously passed; make test, overlay smoke, planner-helper packaging/bridge, offline suite, and launcher tests previously passed | Rerun after relevant changes; source tests do not upgrade live acceptance. |
| Architecture | Earlier fresh Sol ship approved foundation architecture | Not the final Phase 1 ship. |
| Stock safety | Stock hash was captured unchanged; no paid calls/uploads | Recheck before copied-app update/launch. |
| Panel | Compact panel is a read-only shell; Apply/Undo and planner binding disabled | No editable workflow accepted. |
| Transform | Typed rotate/zoom math/static contract exists; native execution deliberately disabled | Handles/source identity incomplete; no native write, undo, or rollback proof. |

Do not promote any row because compilation, a static contract, generated artifact,
signature, or process launch succeeded.

## Live chronology and critical blocker

Schema 15 created one real native disposable project, then stopped before fixture
import/append. Authoritative evidence:
 /Users/marcboyer/Movies/FCPCommandConsole/provenance/disposable-project-bootstrap-B42DFA39-B63E-4050-9CDD-B4E2B00DACBA.json

It records project_creation_invocation_count=1, import_invocation_count=0,
append_invocation_count=0, observation_turns=2, unchanged fixture hashes,
status=partial_unverified, and rollback=not_attempted_no_rollback_claimed. Stop
reason: fcp_12_3_fixed_contract_receiver_class_mismatch. This is safe partial live
evidence, not evidence for import, append, or any workflow.

Postlaunch baseline:
 /Users/marcboyer/Movies/FCPCommandConsole/provenance/postlaunch-schema15-partial-20260803T054100Z

Its summary.json reports status=pass and process guard closed. Inspect with:

    jq . /Users/marcboyer/Movies/FCPCommandConsole/provenance/postlaunch-schema15-partial-20260803T054100Z/summary.json

Normal Final Cut preferences were logically restored; the reported current normalized
comparison hash is 8745c02afdeaf5b89e7fbd822bf526dc8902d106e7dff70f8e70c1a27f78e6dc.
Commit 48a85bd adds __CFPREFERENCES_AVOID_DAEMON=1 plus exact sandbox denial of
normal preference files. The parent reran launcher syntax, launcher tests, and real
--preflight-only successfully. This is containment evidence only: every next live
launch must freshly prove normalized preferences unchanged.

## Active Schema 16 lane: recovery and inspection

Current Terra/High lane: /root/schema16_resume_adapter_v2, native thread
019fc637-bf6a-7951-97d3-3f73a641f051. It owns uncommitted plugin/** work for a
distinct exact resume arm, empty-project admission, stage-specific receiver
diagnostics, exact Schema15-to-16 admission, and offline tests.

It is in progress. It is not installed and cannot alter the installed Schema 15
facts above. Never say Schema 16 or a live workflow is complete from this dirty
diff or source tests. Inspect it:

    git status --short
    git diff --stat
    git diff -- plugin/patcher/update-copied-runtime plugin/scripts/build-minimal-runtime plugin/splicekit_minimal/Resources/FCPCCOnboardingQueryCompatibility.plist plugin/splicekit_minimal/Sources/FCPCommandConsoleRuntime.m plugin/tests/MutationStubTests.m plugin/tests/run-offline-tests
    git diff --check

Obtain the Terra report, then parent-verify it before considering a narrow commit.
It must retain these exact constraints: resume is exclusive of create and
library-create arms; admission is one enrolled library, one default event/media
project, one exact-name stable sequence, zero owned/imported clips, zero primary
storyline items; nonnil wrong receivers fail at a bounded stage; nil is pending
only at stated editor-readiness boundaries; resume never creates a project;
fixture paths/hashes/order remain exact; no automatic retry and no rollback claim.

If the lane disappeared, do not improvise a replacement role. Run the Sol preflight,
then give the exact Terra/High role a corrected five-part specification owning only
the current dirty plugin/** file set and preserving new concurrent edits.

## Ordered continuation gates

1. Orient: read AGENTS.md, inspect Git state, and rely on the launcher's own
   no-Final-Cut preflight. Run Sol Advisor --check before a new lane.
2. Finish Schema 16 source and parent-verify. At minimum:

       /bin/zsh -n Scripts/launch-isolated-fcpcommandconsole
       /bin/zsh Scripts/tests/run-isolated-launcher-tests
       /bin/zsh plugin/tests/run-offline-tests
       make test
       make overlay-smoke
       git diff --check

   Update source/launcher tests for Schema 16; tests pinning Schema 15 are not
   proof for a Schema 16 contract.
3. Commit only reviewed, passing Schema 16 source/tests and this handoff. No runtime
   provenance, copied app content, fixtures, or unrelated concurrent work.
4. Admit an installed Schema 16 copy only via reviewed
   plugin/patcher/update-copied-runtime and plugin/patcher/verify-copied-fcp.
   Preserve stock/copy identity, receipt, Team, entitlements, input provenance,
   and exact predecessor admission. Capture new provenance and hashes.
5. Rerun full offline and launcher suites plus
   Scripts/launch-isolated-fcpcommandconsole --preflight-only. The copied policy
   must report Schema 16; launcher admission must be exact, never arbitrary.
6. Do one bounded Schema 16 resume only after all gates. Use exact copied app,
   exact resume arm, enrolled disposable library, and a new provenance directory.
   Accept neither mutation nor workflow behavior without exact preconditions,
   fixture hashes, ordered import/append/readback, actual project format, zero
   project-create count, and closed post-exit guard. On uncertainty stop and
   preserve rejected/partial_unverified evidence; never auto-retry.
7. Admit workflow contracts separately, each with target identity/revision,
   main-thread atomic mutation, readback, UUID transaction provenance, undo, and
   exact rollback proof.
8. Refresh docs only from current evidence. STATUS.md and docs/PHASE1_ACCEPTANCE.md
   lag current progress and are not authoritative until refreshed.
9. Rerun all final checks, form the packet below, and obtain a fresh Sol/High review.
   Phase 1 completes only on VERDICT: ship.

## Four-workflow acceptance matrix

| Workflow | Current state | Required live acceptance before enablement |
| --- | --- | --- |
| Targeted rotate/zoom | Typed math/static contract; execution disabled | Exact selected clip/source/handle/revision admission; one bounded transform write/readback; known coordinate convention; transaction provenance; native undo and exact original keyframe rollback in disposable library. |
| Old-TV editable composition | Registry/model only | Native editable layers/effects, typed parameters, exact target/readback, transaction provenance, undo/rollback, and manual visual acceptance. |
| Native dissolve | Registry only | Exact adjacent clips/range/handles/revisions, typed duration, native transition readback, provenance, undo/rollback, and manual playback acceptance. |
| Living still | Registry and DepthFlow-or-native-fallback policy/model; no live workflow | No model/download/upload without approval. Approved local DepthFlow output with hash/cost/provenance or explicit native fallback; source preservation, native insertion/readback, undo/rollback, and manual motion/quality acceptance. |

All four are not live accepted. Disabled panel controls or planner output satisfy none.

## Test and evidence matrix

| Layer | Command/artifact | Scope |
| --- | --- | --- |
| Swift core | make test | Planner/policy only; no Final Cut runtime proof. |
| CLI core | make doctor | Local core health only. |
| Overlay | make overlay-smoke | Generated overlay only. |
| Runtime source | /bin/zsh plugin/tests/run-offline-tests | Static/offline containment only. |
| Launcher | /bin/zsh Scripts/tests/run-isolated-launcher-tests | Policy/installed identity only; not an edit. |
| Launch gate | Scripts/launch-isolated-fcpcommandconsole --preflight-only | Exact app/containment/no-running-Final-Cut and preference comparison then. |
| Live mutation | New operation provenance + postlaunch baseline | Proves only exact recorded operation, subject to workflow row. |
| Stock safety | Fresh stock/copy identity capture | Stock unchanged, not copied behavior. |

Run git diff --check before every commit and final review.

## Preference containment and safe process recovery

sandbox-exec is deprecated; containment relies on isolated environment plus exact
denial of normal Final Cut preference files. The launcher snapshots normalized
preferences before/after and fails on drift. Never suppress the comparison or alter
its paths. On drift: stop launch work, preserve preflight provenance, capture a new
read-only baseline, compare it with known baseline, and investigate under a fresh
Terra specification. Never delete or hand-edit preference files to manufacture a
match.

Launcher process guards must prove Final Cut closed before and after launch. If an
unexpected Final Cut process remains, first preserve PID and executable identity via
launcher/provenance checks. Do not use broad names, killall, pkill, or -9. Never
terminate stock Final Cut. Only with explicit operator authorization and lsof proof
that one PID is the exact copied executable may the operator run:

    kill -TERM <exact-copied-pid>

Then recapture a closed guard before any further work. Never apply termination to
SafeSight.

## Commit discipline, final packet, completion

Before a local commit:

    git status --short
    git diff --check
    git diff -- <owned-files>
    git add -- <owned-files>
    git commit -m '<evidence-backed change>'
    git status --short

No remote/push or source overwrite. Do not commit copied-app contents, runtime data,
media, provenance, credentials, or unfinished work owned by another agent.

Fresh Sol final packet must contain: the full goal/four workflows/paths/prohibitions;
base/head, complete diff/status, allowed file list; actual final source/offline/
launcher/preflight outputs; installed schema/hash/CDHash/Team proof; every live
provenance and postlaunch baseline including rejected/partial_unverified attempts;
manual workflow evidence plus undo/rollback/provenance/cost approval proof; current
docs superseding stale STATUS.md and docs/PHASE1_ACCEPTANCE.md; and observed reviewer
role/model/effort/sandbox/permission. Instruct behavioral read-only review and demand
exactly ship, fix-first, or rethink.

- [ ] Four workflows individually pass their live acceptance rows.
- [ ] Panel binds only typed plans and truthfully shows failure/cost/approval state.
- [ ] Every mutation has source identity/revision, readback, provenance, undo, exact rollback.
- [ ] No prohibited shortcut, stock mutation, production media/library, paid call, or upload occurred.
- [ ] Stock/copy identity, preference snapshots, and process guard are freshly clean.
- [ ] Current tests, preflight, manual evidence, and runtime provenance are retained.
- [ ] STATUS.md, docs/PHASE1_ACCEPTANCE.md, and this handoff state only current evidence.
- [ ] Fresh Sol/High final review returns ship; later edits require rerun and new review.
