.PHONY: build test doctor overlay-smoke fixtures acquire-depth-model install-app launch-app clean-runtime

build:
	swift build

test:
	swift test
	python3 Scripts/audit-core.py

doctor:
	swift run fcpcommandconsole doctor-core

overlay-smoke:
	Scripts/overlay-smoke.sh

fixtures:
	Scripts/generate-fixtures

acquire-depth-model:
	Scripts/acquire-depth-model

install-app:
	Scripts/install-app

launch-app:
	Scripts/launch-app

clean-runtime:
	@echo "Runtime cleanup is intentionally manual and scoped; no broad delete is performed."
