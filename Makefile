.PHONY: build test doctor overlay-smoke fixtures clean-runtime

build:
	swift build

test:
	swift test
	python3 scripts/audit-core.py

doctor:
	swift run fcpcommandconsole doctor-core

overlay-smoke:
	scripts/overlay-smoke.sh

fixtures:
	scripts/generate-fixtures

clean-runtime:
	@echo "Runtime cleanup is intentionally manual and scoped; no broad delete is performed."
