# Troubleshooting

## Installed app is blank, fails to launch, or has no resources

Run `make install-app`, then:

```sh
codesign --verify --deep --strict /Users/marcboyer/Applications/FCPCommandConsole.app
plutil -extract CFBundleIdentifier raw /Users/marcboyer/Applications/FCPCommandConsole.app/Contents/Info.plist
test -f /Users/marcboyer/Applications/FCPCommandConsole.app/Contents/Resources/registry/effects/native.targeted_rotate_zoom.json
test -f /Users/marcboyer/Applications/FCPCommandConsole.app/Contents/Resources/schemas/effect-plan.schema.json
```

The ID must be `com.marcboyer.FCPCommandConsole`. The installer refuses a
different existing bundle ID, stages/signs/verifies first, and retains a
recoverable exact-owned backup on replacement.

## Media admission fails

The app accepts only canonical absolute, readable regular local movie/still
files. Choose the real file, not a directory, FIFO/device, alias/symlink, Final
Cut application/library path, or undecodable placeholder. A stale-hash failure
means source bytes changed after admission: re-admit the source and re-plan; do
not bypass hash checking. A newer admission or Cancel intentionally makes an
older worker result stale.

## Local package fails

`operation target already exists` is intentional non-overwrite behavior; create
a new plan/operation rather than deleting existing evidence. Staging is unique
and cleaned on failure. A stale/nonregular source, slot-plan mismatch, symlinked
or broad root, and Final Cut/library root all fail closed. Re-admit/re-plan with
the exact current sources and use an owned local output root.

## FCPXML button is disabled

This is expected. CapabilityGate is the authority. Local-media selections never
prove Final Cut timeline/spine/adjacency evidence; all FCPXML preview/export
actions stay blocked. For nonlocal future evidence, a partial semantic profile
also remains blocked unless it contains the exact contracts for that effect.
Never enable UI state by duplicating or bypassing gate logic.

## Reduced v2 manual probe fails

The v1 predecessor crashed during `asset-clip` import (incident
`42DFFCF1-9E45-41DA-992F-ADB212422B07`). Use the immutable v2 package exactly
once per investigation. Stop on crash, import error, missing transition/media,
or export normalization difference; record the evidence and do not mutate/retry
the package. If Final Cut version/build differs from 12.3/450152, treat all
existing manual evidence as potentially invalid until re-established.
