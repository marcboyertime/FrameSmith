# Standalone runbook

Run commands from `/Users/marcboyer/Developer/FCPCommandConsole`.

## Build, test, install, and launch

```sh
swift build
swift test
make install-app
codesign --verify --deep --strict /Users/marcboyer/Applications/FCPCommandConsole.app
plutil -extract CFBundleIdentifier raw /Users/marcboyer/Applications/FCPCommandConsole.app/Contents/Info.plist
make launch-app
```

Expected installed identifier: `com.marcboyer.FCPCommandConsole`. The installer
builds a release app, copies registry/schema resources, ad-hoc signs the staged
bundle, verifies it before the exact-owned-bundle swap, and keeps a recoverable
backup when bytes differ. Do not replace a bundle with another identifier.

## Plan local media

1. Launch the app.
2. Enter one supported request, for example: `Give this image a slow clockwise
   rotation while zooming toward the point I select.`
3. Open or drop canonical local media. Use `primary` for one-source workflows;
   use exactly `outgoing` and `incoming` for dissolve.
4. Optionally click only within displayed media to set a target. Letterbox space
   is rejected.
5. Select **Plan**. Review schema 2.0 effect ID, representation, parameters,
   editable properties, fallback, and gate labels.
6. Source preview remains source-only. FCPXML Export must stay disabled.
7. Select **Save Local Plan Package** only to create an inert local archive.
   The output path is shown by the app. It is not FCPXML and not Final Cut
   importable.

Cancel interrupts current admission/package work; generation tokens prevent a
stale completion from changing a slot or save result.

## Inspect a package

```sh
find ~/Movies/FCPCommandConsole/exports/local-plan-packages -maxdepth 2 -type f | sort
```

For a given UUID directory, inspect `Manifest.json` for hashes and the explicit
false FCPXML/render flags. Do not rename or overwrite an operation directory.

## One manual Final Cut probe

This is a manual evidence action, not an app feature. Use only the immutable
reduced package:

`/Users/marcboyer/Movies/FCPCommandConsole/exports/roundtrip-spikes/CA7D0733-A435-498E-BD82-149CFF863FC3`

On Final Cut Pro 12.3 build 450152, import the package once, inspect the bare
dissolve, then export/read back. Stop immediately on any error, crash, alert,
missing transition/media, or normalization change. Capture the exact outcome.
Do not retry by altering the package. Success would admit only asset admission
and bare-dissolve semantics; all other contracts remain unknown.
