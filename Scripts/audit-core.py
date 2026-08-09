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
card_properties = set(card_schema["properties"])
rule_properties = set(card_schema["definitions"]["rule"]["properties"])
risk_properties = set(card_schema["definitions"]["riskGate"]["properties"])
cards = sorted((root / "registry/editorial-techniques").glob("*.json"))
source_ids = {
    line.split(",", 1)[0].strip('" ')
    for line in (root / "docs/editorial-intelligence/sources.csv").read_text().splitlines()[1:]
    if line.strip()
}
docs_root = (root / "docs").resolve()
seen_ids = set()
statuses = {}

def reject_unknown_nested(value, schema, path):
    """Walk only closed object shapes in the technique-card schema."""
    if "$ref" in schema:
        ref = schema["$ref"]
        if not ref.startswith("#/definitions/"):
            raise SystemExit(f"unsupported technique-card schema reference at {path}: {ref}")
        schema = card_schema["definitions"][ref.rsplit("/", 1)[1]]
    if schema.get("type") == "object":
        if not isinstance(value, dict):
            raise SystemExit(f"{path} is not an object")
        properties = schema.get("properties", {})
        if schema.get("additionalProperties") is False:
            unknown = set(value) - set(properties)
            if unknown:
                raise SystemExit(f"{path} has unknown nested technique-card fields: {sorted(unknown)}")
        for key, child in properties.items():
            if key in value:
                reject_unknown_nested(value[key], child, f"{path}.{key}")
    elif schema.get("type") == "array" and isinstance(value, list):
        item_schema = schema.get("items")
        if item_schema:
            for index, item in enumerate(value):
                reject_unknown_nested(item, item_schema, f"{path}[{index}]")

for path in cards:
    card = json.loads(path.read_text())
    missing = required - set(card)
    if missing:
        raise SystemExit(f"{path.name} is missing required technique-card fields: {sorted(missing)}")
    unknown = set(card) - card_properties
    if unknown:
        raise SystemExit(f"{path.name} has unknown technique-card fields: {sorted(unknown)}")
    reject_unknown_nested(card, card_schema, path.name)
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
        source_id = entry.get("sourceId", "")
        evidence = (root / source_id).resolve()
        if source_id not in source_ids and not (source_id.startswith("docs/") and evidence.is_file() and docs_root in evidence.parents):
            raise SystemExit(f"{card['id']} cites unverified source {source_id}")
    validation = card["validation"]
    for required_field in ("refusalConditions", "safety", "expectedCost"):
        if not card.get(required_field):
            raise SystemExit(f"{card['id']} has no {required_field}")
    cost = card["expectedCost"]
    if set(cost) != {"latency", "monetary", "privacy"}:
        raise SystemExit(f"{card['id']} has incomplete expectedCost")
    for parameter in card["parameters"]:
        if not parameter.get("key") or "default" not in parameter or not parameter.get("liveness"):
            raise SystemExit(f"{card['id']} has incomplete parameter metadata")
        if parameter["type"] in {"float", "int", "duration"} and (not parameter.get("unit") or len(parameter.get("range", [])) != 2):
            raise SystemExit(f"{card['id']} parameter {parameter['key']} has no unit or bounds")
    for rule_name in ("prerequisiteRules", "refusalRules"):
        for rule in card[rule_name]:
            if set(rule) - rule_properties or "kind" not in rule:
                raise SystemExit(f"{card['id']} has malformed typed {rule_name}")
            kind = rule["kind"]
            needed = {"media_kind": "mediaKind", "required_role": "role", "role_count": "count", "audio_presence": "hasAudio"}
            if kind in needed and needed[kind] not in rule:
                raise SystemExit(f"{card['id']} typed rule {kind} lacks {needed[kind]}")
            if kind == "min_dimensions" and not (rule.get("minWidth", 0) > 0 and rule.get("minHeight", 0) > 0):
                raise SystemExit(f"{card['id']} min_dimensions rule is incomplete")
    for gate_name in ("riskGates", "safetyGates"):
        if not card[gate_name]:
            raise SystemExit(f"{card['id']} has no {gate_name}")
        for gate in card[gate_name]:
            if set(gate) != {"category", "level", "decision", "basis"} or set(gate) - risk_properties or not gate["basis"]:
                raise SystemExit(f"{card['id']} has malformed {gate_name}")
    if card["status"] == "validated" and not (validation.get("implemented") and validation.get("visuallyVerified")):
        raise SystemExit(
            f"{card['id']} claims 'validated' without implementation and visual review; "
            "a source describing a technique does not validate it"
        )
    statuses[card["status"]] = statuses.get(card["status"], 0) + 1

# TreatmentPlan's contract is a repository-owned, strict nested contract. The
# Swift admission validator checks encoded instances; this audit verifies that
# the checked-in contract itself still exposes every encoded root and effect
# field, with closed named object shapes. It intentionally does not pretend to
# be a general JSON Schema implementation.
treatment_schema = json.loads((root / "schemas/treatment-plan.schema.json").read_text())
if treatment_schema.get("$schema") != "https://json-schema.org/draft/2020-12/schema" or treatment_schema.get("x-framesmith-contract-version") != "1":
    raise SystemExit("treatment-plan contract id/version is invalid")
for name in ("intent", "effectPlan", "selectionToken", "target", "sourceIdentity", "editableProperty", "generatedAsset", "cost"):
    node = treatment_schema.get("$defs", {}).get(name, {})
    if node.get("type") != "object" or node.get("additionalProperties") is not False or not node.get("required") or not node.get("properties"):
        raise SystemExit(f"treatment-plan contract does not strictly close {name}")
root_required = set(treatment_schema.get("required", []))
root_properties = set(treatment_schema.get("properties", []))
if root_required != root_properties:
    raise SystemExit("treatment-plan contract root required/properties drifted")

summary = " ".join(f"{key}={value}" for key, value in sorted(statuses.items()))
print(f"core audit: registry={len(effects)} schema=json-ok strict-cards=valid treatment-contract=strict forbidden-patterns=0 cards={len(cards)} ({summary})")
