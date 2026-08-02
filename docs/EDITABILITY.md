# Editability contract

The core distinguishes an editable native representation from generated media:

| Effect | Representation | Phase 1 evidence |
| --- | --- | --- |
| `native.targeted_rotate_zoom` | native | bounded duration/scale/rotation/easing and project-space anchor equation are tested; FCP installation is unproven |
| `transition.natural_dissolve` | native | selection/boundary/handle validator is tested; FCP installation is unproven |
| `look.old_television` | generated-overlay | FFmpeg ProRes 4444 alpha metadata and SHA-256 are verified locally |
| `motion.living_still` | hybrid | optional DepthFlow status plus explicit native fallback; no model, upload, or runtime integration |

An `EditableProperty` list is part of every plan. It describes what a future
native operation would expose; it is not evidence that the installed FCP build
accepted a mutation. Generated assets remain content-addressed and replaceable,
never silently baked into source media.
