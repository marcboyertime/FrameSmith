# Editability contract

> **Current-path notice (2026-08-08):** The registry mapping and disabled-
> export statements below describe the original standalone-planner checkpoint.
> Living Still v2 and Old Television v2 now use `baked_render` with one shared,
> checksum-bound connected treatment movie. Their controls are regenerable in
> FrameSmith, not native editable Final Cut effect parameters. See `STATUS.md`,
> `docs/PARAMETER_LIVENESS.md`, and
> `docs/CONNECTED_RENDERED_MOVIE_ADMISSION_PASS.md` for the current bounded
> contract.

Schema 2.0 uses these canonical representation classes:

| Representation | Meaning in a plan | Verified Final Cut editability? |
| --- | --- | --- |
| `fcpxml_native` | Intended native FCPXML-oriented representation | No |
| `layered_media` | Intended editable composition of source/layers | No |
| `motion_template` | Intended Motion-template representation | No |
| `external_editable_composition` | Intended external editable composition | No |
| `baked_render` | Intended baked-output representation | No |

Current registry mapping is targeted rotate/zoom, natural dissolve, and Living
Still → `fcpxml_native`; Old Television → `layered_media`. These labels express
typed planning intent, not an assertion that Final Cut accepted a semantic,
imported it, preserved an editable control, or exported it correctly.

Legacy values (`fcp_native`, `generated_asset_plus_fcp_native`, and
`external_render_required`) are not current representations. Schema 1.0 is
quarantined with optional suggested migration only; it must be replanned as
schema 2.0 before local preview or packaging.

Editability needs evidence per semantic contract. The dissolve import/export
pass of 2026-08-04 observed asset admission and a natively instantiated cross
dissolve at correct timing, and nothing else. It does not establish transform
keyframes, opacity keyframes, native color adjustment, connected overlay
layers, reusable template behavior, or any workflow-wide editability claim —
and observing a semantic is not the same as admitting its contract, which
remains a separate deliberate act.

The standalone app's source preview and inert package are not editability
evidence. FCPXML export remains disabled through CapabilityGate.
