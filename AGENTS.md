# FCPCommandConsole project policy

This is a private local project. Preserve the following boundaries in every
change:

- Never modify the original App Store Final Cut Pro application at
  `/Applications/Final Cut Pro.app`, any Final Cut Pro library, or user media.
- Never use AppleScript, Accessibility APIs, keyboard/mouse simulation, or
  coordinate-based UI automation.
- A programmatic launch of the exact copied Final Cut Pro app is allowed only
  after a read-only preflight proves stock Final Cut Pro is closed and a
  reviewed isolation mechanism prevents automatic access to any production
  Final Cut Pro library. A direct process or `open` launch is permitted only
  after those guards pass; bare launch while the copy shares
  `com.apple.FinalCut` preference or library identity remains forbidden.
- Never interact with, stop, disable, unload, weaken, or bypass SafeSight.
- Do not configure or use remote Git repositories, pushes, paid calls, media
  uploads, or secrets. Keep credentials out of source, logs, shell history, and
  argv.
- Treat `reference/` as read-only snapshots. Do not edit or build from inside a
  focused reference clone as part of Stage 1/2.
- Keep generated previews, renders, overlays, depth maps, logs, jobs,
  provenance, and usage data under `~/Movies/FCPCommandConsole/`; do not commit
  runtime payloads.
- Use `apply_patch` for project file edits. Read and preserve concurrent edits;
  never reset or revert work owned by another agent.

## Sol Advisor governance

All implementation work must be routed through the installed
`$sol-advisor:orchestration` workflow. The orchestrator owns architecture and
acceptance; delegated implementation must have explicit ownership and bounded
verification; a fresh read-only Sol review is required before a completion claim.
This Stage 1/2 audit does not implement product behavior and therefore does not
claim any runtime or Final Cut Pro capability.
