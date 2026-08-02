# Machine report

Captured 2026-08-02 on the local machine. This report records command output
and source inspection only; it is not an installation or live-runtime claim.

## Host inventory

| Item | Observed value | Command/evidence |
| --- | --- | --- |
| OS | macOS 26.3 (build 25D125), Darwin 25.3.0 | `sw_vers`; `system_profiler SPSoftwareDataType` |
| Model/chip | MacBookPro18,2; Apple M1 Max; 10 cores (8 performance + 2 efficiency) | `sysctl -n hw.model`; `system_profiler SPHardwareDataType` |
| Unified memory | 64 GB (`hw.memsize=68719476736`) | `sysctl -n hw.memsize`; `system_profiler SPHardwareDataType` |
| Root disk | APFS, 994.7 GB device; `df -h /`: 926 GiB volume, 11 GiB used, 345 GiB available (4%) | `diskutil info /`; `df -h /` |
| Final Cut Pro | 11.1.1 (bundle build 440111) at `/Applications/Final Cut Pro.app` | `find /Applications ... -name 'Final Cut Pro.app'`; `plutil -p .../Contents/Info.plist`; `defaults read ... CFBundle*` |
| Xcode / Swift | Xcode 26.6 (17F113); Apple Swift 6.3.3; arm64-apple-macosx26.0 target | `xcode-select -p`; `xcodebuild -version`; `swift --version` |
| Python | Python 3.14.5 at `/opt/homebrew/bin/python3` | `python3 --version`; `command -v python3` |
| Homebrew | 6.0.14-38-g1f3abf4 at `/opt/homebrew/bin/brew` | `brew --version`; `command -v brew` |
| ffmpeg / ffprobe | FFmpeg/ffprobe 8.1.1 at `/opt/homebrew/bin/{ffmpeg,ffprobe}`; build enables videotoolbox | `ffmpeg -version`; `ffprobe -version` |
| ProRes encoders | `prores`, `prores_ks`, and `prores_videotoolbox` are listed; software `prores_ks` supports yuv422p10le/yuv444p10le/yuva444p10le; VideoToolbox encoder is listed with hardware device capability | `ffmpeg -hide_banner -encoders`; `ffmpeg -h encoder=prores_ks`; `ffmpeg -h encoder=prores_videotoolbox` |

## SpliceKit compatibility assessment

Inspected snapshot: `reference/elliotttate/SpliceKit` at commit
`f4f6618121309a69b66272b441f34cf8ad57f306`.

Observed facts:

- `patcher/patch_fcp.sh` discovers `/Applications/Final Cut Pro.app`, reads
  `CFBundleShortVersionString`, and states that it copies the app to a separate
  destination before signing/injecting. The source app is therefore a plausible
  input path for a future, separately authorized compatibility experiment.
- `mcp/server.py` defines a local MCP client for a JSON-RPC bridge on
  `127.0.0.1:9876`; it explicitly describes in-process control and no
  AppleScript/UI automation. `Sources/SpliceKitServer.m` implements the TCP
  listener and private-ObjC dispatch, and includes FCPXML import/export handlers.
- The checked-in FCPXML reference documents versions 1.9 through 1.11 and says
  FCPXML is interchange rather than a native library archive. The checked-out
  MCP generator emits `fcpxml version="1.14"`, so the exact FCPXML version and
  acceptance behavior for installed FCP 11.1.1 remain to be tested.

Bounded result: **source-level candidate only**. There is no evidence here that
SpliceKit builds, patches, launches, connects to, or safely edits this machine's
Final Cut Pro 11.1.1. The patcher was not run, no application copy was made, no
code signing/injection was attempted, and no Final Cut library was opened.

## Reproducible probe summary

The audit ran these read-only probes (full values above):

```text
sw_vers
sysctl -n hw.model
sysctl -n hw.memsize
diskutil info /
df -h /
system_profiler SPHardwareDataType SPSoftwareDataType
find /Applications /Users/marcboyer/Applications -maxdepth 2 -type d -name 'Final Cut Pro.app'
plutil -p '/Applications/Final Cut Pro.app/Contents/Info.plist'
xcode-select -p
xcodebuild -version
swift --version
python3 --version
brew --version
ffmpeg -version
ffprobe -version
ffmpeg -hide_banner -encoders
ffmpeg -hide_banner -h encoder=prores_ks
ffmpeg -hide_banner -h encoder=prores_videotoolbox
```

No network service, application process, Final Cut library, or SafeSight service
was changed by these probes.
