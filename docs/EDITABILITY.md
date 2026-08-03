# Editability contract

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

Editability needs evidence per semantic contract. A future successful bare
dissolve import/export may establish asset admission and bare dissolve only. It
does not establish transform keyframes, opacity keyframes, native color
adjustment, connected overlay layers, reusable template behavior, or any
workflow-wide editability claim.

The standalone app's source preview and inert package are not editability
evidence. FCPXML export remains disabled through CapabilityGate.
