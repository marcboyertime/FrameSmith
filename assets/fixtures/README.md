# Synthetic fixture inputs

This directory contains only the generator contract. The generated media is
kept out of Git under:

`~/Movies/FCPCommandConsole/fixtures/`

Run `scripts/generate-fixtures` with no arguments to create `clip-a.mov`,
`clip-b.mov`, `living-still.png`, and `manifest.json` using local FFmpeg
lavfi sources. The generator is deterministic and idempotent: an unchanged
manifest and matching hashes are reported without rewriting the four named
outputs. Unexpected files in the runtime directory are preserved.
