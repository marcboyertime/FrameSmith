# FCPCommandConsole / FrameSmith project policy

Private local project. **FrameSmith** is the product name; `FCPCommandConsole`
remains the repository, bundle, and command identifier.

## The product relationship

**The user is the director and picture editor. FrameSmith is the craft partner.**

The user owns clip selection, inclusion, order, edit points, durations, sync,
narration, and music structure. FrameSmith owns motion, transitions around locked
edit points, compositing, color, texture, typography, object-aware treatment, and
sound finishing.

Understanding the story gives FrameSmith context for a treatment. It never grants
authority to restructure the edit. Any creative feature must read
`docs/editorial-intelligence/DIRECTOR_CONTROL_CONTRACT.md` before it plans
anything, and must hold the editorial-structure lock across preview and export.

"Surprise Me" means *preserve my clips and timing, show me different treatments*.
It does not mean "make the edit for me".

## Priorities, in order

1. faithfulness to the user's creative intent and editorial control
2. visual and sonic quality
3. ease and speed
4. reliability
5. useful revision and history
6. Final Cut editability where useful
7. implementation purity

Native Final Cut construction is valuable but does not outrank the picture. A
rendered, ML-assisted, composited, or generative construction is allowed when it
looks meaningfully better **and** FrameSmith retains the source, plan,
parameters, provenance, and regeneration path. The failure mode is
*unrepeatable*, not *rendered*.

## Hard boundaries

- Never modify the App Store Final Cut Pro at `/Applications/Final Cut Pro.app`,
  any production Final Cut library, or user source media.
- Never interact with, stop, disable, unload, weaken, or bypass SafeSight.
- Keep generated previews, renders, overlays, depth maps, logs, jobs, provenance,
  and usage data under `~/Movies/FCPCommandConsole/`. Do not commit runtime
  payloads.
- Treat `reference/` as read-only snapshots.
- Read and preserve concurrent edits; never revert work owned by another agent.
- No paid call or private-media upload without naming the provider, the estimated
  cost, and the privacy boundary, and receiving approval.
- Keep credentials out of source, logs, shell history, and argv.

## Automation and remote git — updated

These two rules changed after earlier revisions of this file, and stale copies
caused a real documentation defect: `STATUS.md` claimed "project policy forbids
scripted UI control" long after that stopped being true.

- **GUI automation of the isolated Final Cut copy and of the reviewed
  FrameSmith app is permitted** (authorized 2026-08-05). Every Phase 1 admission
  and editability pass was driven that way. A programmatic launch of the copied
  Final Cut app still requires the read-only preflight proving stock Final Cut is
  closed and the isolation mechanism is in place.
  - Never record a refusal as a finding without a screenshot of the UI state that
    refused it. A missed click and a greyed-out control both produce "the value
    didn't change".
- **Pushing to `origin` is permitted** (authorized 2026-08-06). No force-push to
  a shared branch, no history rewriting, no destructive remote operations
  unasked. Individual task prompts may still say "do not push" for a given
  milestone; honour that when it is stated.

## Evidence discipline

This is what caught five silently-wrong emitters, including a position error that
panned 10.8× too far *and imported cleanly*. It does not trade against quality.

- **DTD validity is not Final Cut acceptance.** Neither is a passing test, a
  source preview, or a generated package.
- A Final Cut semantic claim requires returned evidence from a real import,
  captured through the isolated process, and stays scoped to the tested build
  (currently 12.3 / 450152).
- A control is **editable** only when the emitted construction has a verified
  mapping. Invariants and unsupported controls stay read-only. See
  `docs/PARAMETER_LIVENESS.md`.
- **Preview and export must share one admitted construction.** A preview
  computed separately from the export can disagree, and only Final Cut would
  notice.
- Technique cards carry claim-level provenance. A card is not `validated`
  because a source describes the technique — only because the construction was
  implemented and visually verified.
- Visual features require representative visual review, not only automated tests.
  Manual testing has already found two bugs the suite could not.

## Where the detail lives

Keep this file short. The long-form doctrine is referenced, not embedded:

| Topic | File |
| --- | --- |
| Editorial authority and preservation checks | `docs/editorial-intelligence/DIRECTOR_CONTROL_CONTRACT.md` |
| Craft principles | `docs/editorial-intelligence/EDITORIAL_PLAYBOOK.md` |
| Intent → treatment decisions | `docs/editorial-intelligence/EFFECT_DECISION_SYSTEM.md` |
| Three-option generation rules | `docs/editorial-intelligence/SURPRISE_ME_DESIGN.md` |
| Visual/sonic/honesty gates | `docs/editorial-intelligence/QUALITY_RUBRIC.md` |
| Technique-card format | `docs/editorial-intelligence/TECHNIQUE_CARD_SCHEMA.md` |
| Source hierarchy (153 curated sources) | `docs/editorial-intelligence/SOURCE_ATLAS.md`, `sources.csv` |
| Which parameters are live | `docs/PARAMETER_LIVENESS.md` |
| Final Cut semantics already admitted | `service/FinalCutSemanticProfile.swift` |
| Project status | `STATUS.md` |

The source catalog is a **retrieval map**, not a runtime dependency and not a
claim of expertise. Do not bulk download, scrape, or commit the linked tutorials,
books, videos, or PDFs. Retrieve only what a specific card needs, obey access and
license terms, summarize in original language, and record claim-level provenance.

## Sol Advisor governance

Implementation work should follow the `$sol-advisor:orchestration` pattern:
the orchestrator owns architecture and acceptance, delegated implementation has
explicit ownership and bounded verification, and a fresh read-only review
precedes any completion claim.

**As of 2026-08-07 the workflow is not installed** — `reference/DannyMac180/sol-advisor`
is a read-only snapshot, not an executable plugin. Apply the substance directly:
bound each change, verify it, and re-read the result critically before claiming
it works. Do not claim the workflow was invoked when it was not.
