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
print(f"core audit: registry={len(effects)} schema=json-ok forbidden-patterns=0")
