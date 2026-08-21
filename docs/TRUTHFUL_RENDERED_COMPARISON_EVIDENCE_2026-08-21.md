# Truthful rendered comparison evidence — 2026-08-21

This worksheet separates source/test evidence, installed-binary evidence,
headless rendered-file inspection, installed UI observation, and returned Final
Cut evidence. A result in one class is not promoted into another.

## Environment and build identity

- Branch at the code checkpoint: `codex/truthful-rendered-comparison`
- Installed code commit: `a7595a8` (`Fix standalone dissolve default request`)
- macOS: 26.3 (build 25D125), Apple silicon
- Final Cut Pro: 12.3 (build 450152)
- Installed app: `/Users/marcboyer/Applications/FrameSmith.app`
- Bundle identifier: `com.marcboyer.FCPCommandConsole`
- Signature: valid ad-hoc signature; CDHash
  `58330b2385b24c26b537522c4c739090f4eaaff4`
- Installed executable SHA-256:
  `84520a762a08de2100dd3547a96f2f7dfb3793edd9eae9a098072452f0ea7926`
- The final installer reported the bundle byte-identical to the preceding
  install because commit `a7595a8` changes only the standalone CLI target.
  `make launch-app` launched the installed executable and process 90645 was
  observed running. Process IDs are not durable evidence.

The final source gate executed 387 Swift tests with zero failures. The strict
catalog/schema audit also passed with four validated cards and eleven
reference-only cards.

## Nonprivate fixtures

| Label | Local path (nonportable) | SHA-256 |
| --- | --- | --- |
| Layered still | `/Users/marcboyer/Movies/FCPCommandConsole/fixtures/living-still.png` | `170df5348f53221de630c7d7b385e6189f53a27baa2f2246ec7df4f379ed2567` |
| Movie A | `/Users/marcboyer/Movies/FCPCommandConsole/fixtures/clip-a.mov` | `cd44c0c9565c8231ec421541f4a4877f340eae7db5129fb46ffa14f0bf871444` |
| Movie B | `/Users/marcboyer/Movies/FCPCommandConsole/fixtures/clip-b.mov` | `a38a03bf0ababfedc56c6086479c34649a8fea8b2435b04c4901f3987c66f67c` |

These are synthetic FrameSmith fixtures. The committed contact sheets below
contain only those nonprivate synthetic pixels.

## Fresh current-build rendered artifacts

The standalone CLI was run after commit `a7595a8`. It uses the same explicit
prepare-then-export core route as the app: export has no renderer fallback.
These runs establish current construction, media, and byte parity; they are not
claims that the installed SwiftUI comparison cards were observed.

### Living Still v2

- Effect: `motion.living_still`
- Operation: `9E83B21E-B197-452D-8A19-3E062E8D96D2`
- Construction digest:
  `124a3e5a4a18ecd7e87960a75bd5ea3603bc7ae36de12d50cb88f1762a9fed60`
- Renderer recipe digest:
  `24307cc0aece0cad24bbdf9fa9e331dcd6a4cd218db715d4ea0105af412a4181`
- Prepared/cache movie:
  `/Users/marcboyer/Movies/FCPCommandConsole/renders/prepared/living-still-depth-24307cc0aece0cad24bbdf9fa9e331dc.mov`
- Package movie:
  `/Users/marcboyer/Movies/FCPCommandConsole/exports/standalone/9E83B21E-B197-452D-8A19-3E062E8D96D2/Media/Generated/living-still-depth-24307cc0aece0cad24bbdf9fa9e331dc.mov`
- Prepared and package movie SHA-256:
  `78f5e85e7a8f1860bdb5b58d0218088936e863dc4dc56d72e8007cbb9f6a04e8`
- FCPXML SHA-256:
  `8564523ce8b588dae4f9f726aea30543d84e3ccc9baeb0fd1e4dcc5cd175e28e`
- Stream: one video stream, ProRes 422 HQ `apch`, `yuv422p10le`,
  1920×1080, 30/1 fps, 120/120 decoded frames, 4.000000 seconds,
  no audio stream.
- Contact sheet, top source / bottom rendered, columns frames 0/60/119:
  `docs/evidence/truthful-rendered-comparison-2026-08-21/living-still-source-vs-render-f0-f60-f119.png`
- Contact-sheet SHA-256:
  `7dfb102649aae3c35e7972906f191d81604732f5c2b6c1d5bf4fa27801428afc`

The three sampled rendered frames visibly change relative element position;
the frame-zero still is not repeated as an untreated poster. This is direct
inspection of the exact generated movie. The broader accepted ten-case HQ
audit remains the visual-quality boundary for depth motion, including its
restrained-depth and low-contrast limitations.

### Old Television v2

- Effect: `look.old_television`
- Operation: `0493F319-7D76-4B32-91AD-1B26ADD2CC67`
- Construction digest:
  `7eab383d25cb2efe122011ebd55951505bfd9bcc41e85ac7ce9908489fc538a8`
- Renderer recipe digest:
  `d29e2fe32d24dfe0cab29281a0ed0895a7295b5a541b00565968dbedee9391ea`
- Prepared/cache movie:
  `/Users/marcboyer/Movies/FCPCommandConsole/renders/prepared/old-television-broadcast_mono-d29e2fe32d24dfe0cab29281a0ed0895.mov`
- Package movie:
  `/Users/marcboyer/Movies/FCPCommandConsole/exports/standalone/0493F319-7D76-4B32-91AD-1B26ADD2CC67/Media/Generated/old-television-broadcast_mono-d29e2fe32d24dfe0cab29281a0ed0895.mov`
- Prepared and package movie SHA-256:
  `a0213f69b39b719cd250480f9499ed98ccd15065a3af9d34afcd7483ce37572d`
- FCPXML SHA-256:
  `d81c112d07d6692174bb816d71ed143781d0a36cba3d35b78c0ffa366adb2b4a`
- Stream: one video stream, ProRes 422 HQ `apch`, `yuv422p10le`,
  1920×1080, 30/1 fps, 120/120 decoded frames, 4.000000 seconds,
  no audio stream.
- Contact sheet, top source / bottom rendered, columns frames 0/60/119:
  `docs/evidence/truthful-rendered-comparison-2026-08-21/old-television-source-vs-render-f0-f60-f119.png`
- Contact-sheet SHA-256:
  `6b5eae403061db20d905807ead09693cfe141b7fd486a1c8ab5b4e357ee26504`

The exact rendered frames show the sustained desaturated CRT treatment and
fine display texture at the beginning, midpoint, and final frame; there is no
fade-out/fade-in substitute. This is direct inspection of the generated movie,
not a current installed-card observation.

## Comparison and interaction evidence

Automated core coverage proves the following current contracts:

- a rendered comparison descriptor selects an exact prepared movie and cannot
  route through `EffectPoster` or an untreated source;
- a native comparison descriptor remains channel-based;
- every source/native/rendered tile resolves the same integer frame index;
- rendered artifacts reject option, structure, plan, registry/card, source
  path/hash/context, construction, recipe, file, stream, and preview-profile
  drift;
- preparation is capped at three options, content-deduplicated, serial for
  heavy work, cancellation-aware, and latest-generation safe;
- missing rendered bytes refuse before export staging and the export builder
  never invokes preparation;
- copied package bytes equal the supplied prepared movie bytes; and
- 101 slider draft ticks produce one authoritative commit. Rejected or
  discarded drafts retain the prior authoritative plan and prepared preview.

The current task did **not** obtain installed comparison-card screenshots,
manual shared-playback observation, a mixed native/rendered installed view, a
pending-state fallback check, or a manual slider-drag count. The installed
Computer Use plugin was discoverable, but its required app-scoped runtime was
not attached: `import('@oai/cua')` returned `Module not found: @oai/cua`.
Project policy forbids substituting AppleScript, System Events, global input
injection, or pointer tools. The app was installed, signed, and launched, but
those UI-only observations therefore remain blocked rather than inferred from
the source tests or rendered files.

The CLI executions above mint standalone operation IDs, not editorial option
IDs. Exact installed comparison option IDs therefore were not observed or
invented; the construction and renderer-recipe identities recorded above are
the available current-build artifact identities.

Earlier direct-preview screenshots are retained locally at:

- `/Users/marcboyer/Movies/FCPCommandConsole/provenance/installed-framesmith-living-still-v2-20260821.jpg`
- `/Users/marcboyer/Movies/FCPCommandConsole/provenance/installed-framesmith-old-television-v2-20260821.jpg`

They prove the earlier direct effect-preview route did not crash and displayed
rendered treatment pixels. They predate this comparison checkpoint and are not
used as evidence that the new A/B/C view was exercised.

## Fresh canonical 12-frame Natural Dissolve package

- Effect: `transition.natural_dissolve`
- Operation: `2A6AF0E0-BF1F-413C-B111-8A3351E359C8`
- Package:
  `/Users/marcboyer/Movies/FCPCommandConsole/exports/standalone/2A6AF0E0-BF1F-413C-B111-8A3351E359C8`
- FCPXML:
  `/Users/marcboyer/Movies/FCPCommandConsole/exports/standalone/2A6AF0E0-BF1F-413C-B111-8A3351E359C8/FrameSmith.fcpxml`
- FCPXML SHA-256:
  `7fa8777d490cdbec7ea4993032a3fd7b64fe14b649072ee866aa7224c53b9822`
- Provenance SHA-256:
  `19ace83d26d16e4ed8b1f15bc186008147dacb3d28c145664dbf3a7fb890c690`
- Source hashes: Movie A and Movie B as recorded above.
- Sequence duration: `46800/3000s` (15.6 seconds).
- Outgoing clip: offset 0, start 0, duration `23400/3000s` (7.8 seconds).
- Transition: `Cross Dissolve`, offset `22800/3000s` (7.6 seconds),
  duration `1200/3000s` (0.4 seconds / 12 frames).
- Incoming clip: offset `23400/3000s` (7.8 seconds), start
  `600/3000s` (0.2 seconds), duration `23400/3000s` (7.8 seconds).
- The emitted clips remain butt-joined at the 7.8-second edit point; the
  transition is centered six frames on either side.

The guarded isolated Final Cut preflight passed and wrote
`/Users/marcboyer/Movies/FCPCommandConsole/provenance/isolated-launch-preflight.uGmVkN`.
The one-pass package is ready for manual import using its `README.md`.
Import/export was not attempted because the approved app-scoped Computer Use
runtime was unavailable as described above. No stock or production library was
touched. There is no returned FCPXML hash, and no semantic evidence or
capability surface was broadened. This package establishes only current emitter
output and its exact geometry; it does not establish Final Cut acceptance,
returned stability, arbitrary dissolve duration, another Final Cut build, or
visual quality.

## Remaining limitations

- The central core invariant is implemented and automated: when the app has a
  ready rendered comparison artifact, the descriptor points at those exact
  checksum-bound pixels and the same bytes are eligible for export. Current
  installed A/B/C UI observation remains outstanding because of the missing
  Computer Use runtime attachment.
- The fresh 12-frame dissolve still needs the single isolated Final Cut
  import/export return described above.
- This checkpoint remains still-only for rendered comparison audio; it makes no
  level-matching or mixed-timeline audio claim.
- The current exact rendered export envelope remains Final Cut 12.3 build
  450152, FCPXML 1.14, 1920×1080 progressive, 30 fps, 120 frames, four seconds,
  and the already admitted still/movie parent contexts. It does not generalize
  beyond that evidence.
