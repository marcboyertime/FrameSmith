# Troubleshooting

## Registry or plan errors

Use an explicit registry path in tests or run from the repository root. An
unknown alias, no-match request, ambiguity, stale revision, unknown parameter,
NaN/infinite coordinate, missing fallback, or paid cost estimate is expected to
fail closed. Recreate the selection fixture with the current revision instead
of bypassing validation.

## Overlay errors

`doctor-core` reports whether `/opt/homebrew/bin/ffmpeg` and `ffprobe` are
executable. The adapter uses a fixed filter graph and bounded resolution/fps;
it refuses overwrite and reports a verification error when ffprobe does not
show an alpha-capable `yuva*` pixel format. This is a real gap, not a reason to
label opaque output as alpha.

## Runtime boundary

No troubleshooting step launches or patches Final Cut Pro, opens a library,
uses UI automation, touches SafeSight, installs DepthFlow, uploads media, or
reads secrets. Those capabilities require a separate approved lane and Stage 4
go/no-go evidence.
