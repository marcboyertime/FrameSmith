# FCPXML 1.13 Round-Trip Spike

`fcpcommandconsole-roundtrip-spike` creates one self-contained, non-overwriting
package from the disposable fixtures. It is intentionally a narrow interchange
gate: it does not launch, automate, modify, or otherwise interact with Final
Cut Pro or any Final Cut library.

Run it with the disposable fixtures and a new operation identifier:

```sh
swift run fcpcommandconsole-roundtrip-spike --fixture-root /Users/marcboyer/Movies/FCPCommandConsole/fixtures --export-root /Users/marcboyer/Movies/FCPCommandConsole/exports/roundtrip-spikes --operation-id 11111111-2222-3333-4444-555555555555
```

The package contains copied media, a 1.13 DTD-validated FCPXML file, typed plan,
provenance, manifest, and evidence JSON, an empty `Returned/` directory, and an
in-package README with the manual steps. Every `media-rep` URL points to the
package copy rather than a source fixture.

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

Import only into the disposable **FCPCommandConsole Test** Final Cut library.
The three projects are a bare one-second transition probe, targeted-transform
keyframe hypothesis, and four-second living-still transform/opacity hypothesis.
After import, manually apply Final Cut's native monochrome/desaturation plus
modest contrast to the clearly designated living-still clip, then export the
event or projects as FCPXML into `Returned/`.

DTD validation proves only source syntax. The transition, parameter names,
keys, units, native transform/opacity behavior, and manual color adjustment all
remain `unknown` until the returned FCPXML is inspected. No effect UID is
generated or embedded.
