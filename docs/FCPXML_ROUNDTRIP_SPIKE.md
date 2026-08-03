# FCPXML 1.13 Dissolve Admission Probe

`fcpcommandconsole-roundtrip-spike` creates one self-contained, non-overwriting
package from the disposable fixtures. It is intentionally a narrow interchange
gate: it does not launch, automate, modify, or otherwise interact with Final
Cut Pro or any Final Cut library.

Run it with the disposable fixtures and a new operation identifier:

```sh
swift run fcpcommandconsole-roundtrip-spike --fixture-root /Users/marcboyer/Movies/FCPCommandConsole/fixtures --export-root /Users/marcboyer/Movies/FCPCommandConsole/exports/roundtrip-spikes --operation-id 11111111-2222-3333-4444-555555555555
```

Revision 2 contains exactly two copied movie fixtures, a 1.13 DTD-validated
FCPXML source, typed plan/provenance/manifest/evidence JSON, an empty
`Returned/` directory, and an in-package README. Every `media-rep` URL points to
the package copy rather than a source fixture. It deliberately contains no
still, transform, opacity, color, filter, parameter, keyframe, or effect UID.

The generator accepts only actual regular fixture/DTD/media files: symlinks,
directories, FIFOs, sockets, and devices are rejected. Export roots must be a
strict descendant of `~/Movies/FCPCommandConsole/exports/` or a canonical system
temporary root (`NSTemporaryDirectory()` or `/tmp`); custom CLI paths remain
supported only inside those bounds. It rejects symlink export roots, lexical path
traversal, broad output roots, Final Cut application/library locations, and
existing operation directories. DTD validation uses only local `/usr/bin/xmllint`
with `--nonet` and a ten-second timeout before atomic publication. The timeout
path is intentionally bounded by inspection rather than a deliberately hostile
slow DTD test, because the production validator accepts only the supplied local
DTD and never dereferences network resources.

Revision 1 (`A78B1B9D-60D7-4CD8-960B-FA9104C301E7`) failed during Final Cut Pro
12.3 build 450152 import before native semantics were observed. Revision 2
records incident `42DFFCF1-9E45-41DA-992F-ADB212422B07` as predecessor failure
metadata and does not reuse, alter, or retry its source package.

Import revision 2 only into the disposable **FCPCommandConsole Test** library.
It creates one event/project named **FCPCommandConsole Dissolve Admission
Probe**, with two browser clips and a bare one-second transition. Verify that
import completes without an error or crash, inspect whether the transition
appears, then export the event/project into `Returned/`. If Final Cut errors or
crashes, stop and report immediately. Do not apply color or inspect transforms
in this revision.

DTD validation proves only source syntax. Asset admission, transition semantics,
transition timing/handles, and returned-FCPXML round trip remain `unknown` until
manual import/export evidence exists.
