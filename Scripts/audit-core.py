#!/usr/bin/env python3
"""Cheap source-only audits used by `make test`; no network or FCP calls."""
from pathlib import Path
import json, re, sys

root = Path(__file__).resolve().parents[1]
effects = sorted((root / "registry/effects").glob("*.json"))
if len(effects) != 4:
    raise SystemExit(f"expected 4 registry definitions, got {len(effects)}")
ids = [json.loads(path.read_text())["identifier"] for path in effects]
if len(set(ids)) != 4:
    raise SystemExit("registry identifiers are not unique")
json.loads((root / "schemas/effect-plan.schema.json").read_text())
for path in [root / "service/OverlayAdapter.swift", root / "Sources/FCPCommandConsole/main.swift"]:
    text = path.read_text()
    if "/bin/sh" in text or "ProcessInfo.processInfo.environment[\"SHELL\"]" in text:
        raise SystemExit(f"forbidden shell execution pattern in {path}")

# Technique cards. `jsonschema` is not a dependency here, so this checks the
# structural invariants that actually matter rather than the whole schema:
# unique ids, required keys, claim-level provenance, and — the one that guards
# against overclaim — that nothing calls itself validated without having been
# implemented and visually reviewed.
card_schema = json.loads((root / "schemas/technique-card.schema.json").read_text())
required = set(card_schema["required"])
cards = sorted((root / "registry/editorial-techniques").glob("*.json"))
seen_ids = set()
statuses = {}
for path in cards:
    card = json.loads(path.read_text())
    missing = required - set(card)
    if missing:
        raise SystemExit(f"{path.name} is missing required technique-card fields: {sorted(missing)}")
    if card["id"] in seen_ids:
        raise SystemExit(f"duplicate technique card id: {card['id']}")
    seen_ids.add(card["id"])
    if not re.match(r"^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+\.v[0-9]+$", card["id"]):
        raise SystemExit(f"technique card id is not a versioned dotted identifier: {card['id']}")
    if card["status"] not in {"validated", "experimental", "reference_only", "unsupported"}:
        raise SystemExit(f"{card['id']} has an unknown status: {card['status']}")
    if not card["provenance"]:
        raise SystemExit(f"{card['id']} has no provenance")
    for entry in card["provenance"]:
        if not entry.get("claim"):
            raise SystemExit(f"{card['id']} cites {entry.get('sourceId')} without a specific claim")
    validation = card["validation"]
    if card["status"] == "validated" and not (validation.get("implemented") and validation.get("visuallyVerified")):
        raise SystemExit(
            f"{card['id']} claims 'validated' without implementation and visual review; "
            "a source describing a technique does not validate it"
        )
    statuses[card["status"]] = statuses.get(card["status"], 0) + 1

summary = " ".join(f"{key}={value}" for key, value in sorted(statuses.items()))
print(f"core audit: registry={len(effects)} schema=json-ok forbidden-patterns=0 cards={len(cards)} ({summary})")
