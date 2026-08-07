# Technique Card Schema

The source atlas is too large to load into every planning request. Convert
relevant knowledge into compact technique cards and retrieve them on demand.

## Recommended record

```json
{
  "id": "transition.object_wipe.foreground_occluder.v1",
  "name": "Foreground object wipe",
  "domain": "transition",
  "status": "validated|experimental|reference_only|unsupported",
  "summary": "Use a tracked foreground occluder to hide the cut.",
  "creative_jobs": ["energetic spatial bridge", "invisible location change"],
  "intent_tags": ["physical", "motivated", "seamless"],
  "media_prerequisites": [
    "outgoing or incoming frame contains a trackable foreground occluder",
    "matte can cover the full frame at the locked edit point"
  ],
  "editorial_permissions": ["treatment_only"],
  "locked_structure_effect": "none",
  "construction": {
    "preferred_backends": ["metal", "motion_template", "baked_render"],
    "fallback_backends": ["native_mask_if_supported"],
    "required_capabilities": ["mask", "tracking", "compositing"],
    "preview_fidelity": "shared_construction"
  },
  "parameters": [
    {"key": "feather", "type": "float", "unit": "px", "range": [0, 80]},
    {"key": "motionBlur", "type": "float", "range": [0, 1]}
  ],
  "quality_checks": [
    "matte fully covers frame at edit",
    "edge softness matches source focus",
    "motion blur matches occluder velocity",
    "locked edit point unchanged"
  ],
  "failure_modes": [
    "occluder never covers frame",
    "tracking slip",
    "alpha fringe",
    "direction mismatch"
  ],
  "safety": [],
  "editability": ["framesmith_regeneration", "source_composition"],
  "provenance": [
    {
      "source_id": "APPLE-FCP-TRANSITIONS-02",
      "url": "https://support.apple.com/guide/final-cut-pro/adjust-transitions-in-the-timeline-vercf3c662c/mac",
      "claim": "Final Cut transition movement depends on available media handles"
    }
  ],
  "validated_on": [],
  "notes": "Do not offer if the matte cannot hide the locked cut."
}
```

## Required fields

- stable ID and version;
- domain and creative jobs;
- prerequisites and refusal conditions;
- exact impact on locked editorial structure;
- current capability status;
- construction/backends;
- parameters and units;
- quality checks and failure modes;
- editability layer;
- provenance with claim-level source references;
- validation evidence.

## Source roles

Distinguish:

- `technical_authority` — official manuals, standards, captured Final Cut
  evidence;
- `craft_authority` — respected editors/designers/training institutions;
- `implementation_reference` — code, research papers, technical tutorials;
- `inspiration_reference` — examples useful for taste, not technical truth;
- `safety_or_legal` — standards and official guidance.

Never let an inspiration source establish a low-level Final Cut semantic claim.

## Contradictions and uncertainty

Technique cards should support:

- multiple source claims;
- conflicts;
- version scope;
- confidence;
- approximate mappings;
- superseded guidance.

When sources disagree, preserve the disagreement and prefer direct evidence for
the actual environment. Do not flatten uncertainty into a fake rule.

## Retrieval

Retrieve cards by intent, domain, prerequisites, capability status, and risk.
Return a small set. The planner should not ingest the whole atlas for every edit.

## Lifecycle

1. propose card from source material;
2. review citations and copyright-safe summary;
3. implement or map to capability;
4. validate on representative media;
5. mark experimental or validated;
6. revisit when Final Cut, a backend, or a source version changes.

