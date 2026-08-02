# Core runbook

1. Run `scripts/bootstrap` to create only the eight scoped Movies runtime
   directories and build the package.
2. Run `scripts/doctor` (or `swift run fcpcommandconsole doctor-core`) to
   inspect registry/schema/runtime roots and local FFmpeg tools.
3. Prepare a `SelectionToken` fixture with an explicit revision. Run `fcpcommandconsole plan --request ... --selection-fixture ...` and review the JSON.
4. Run `fcpcommandconsole validate-plan <path>` before handing a plan to a
   future executor.
5. Run `make overlay-smoke` for isolated static/scanline assets. Outputs are
   content-addressed and never overwrite existing files.
6. Run `scripts/generate-fixtures` to create deterministic synthetic inputs at
   `~/Movies/FCPCommandConsole/fixtures/`: two 8-second ProRes/PCM clips and a
   marked 1920x1080 still. The command emits `manifest.json`, is idempotent on
   matching hashes, and preserves unexpected files. Audit with
   `python3 scripts/audit-fixtures.py`.

`start-service` only builds the future panel target; there is no daemon in Phase
1. `stop-service` is a safe no-op. `uninstall-or-disable` refuses to act until a
specific copied-app manifest and explicit plugin-lane approval exist.
