#!/bin/zsh
set -euo pipefail
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/fcpcc-overlay-smoke.XXXXXX")"
trap 'rm -rf "$ROOT"' EXIT
FIXTURE="$ROOT/fixture.json"
cat > "$FIXTURE" <<JSON
{"request":{"kind":"static","width":160,"height":90,"fps":12,"durationSeconds":0.5,"seed":17},"outputRoot":"$ROOT/overlays"}
JSON
swift run fcpcommandconsole generate-overlays --fixture "$FIXTURE"
cat > "$FIXTURE" <<JSON
{"request":{"kind":"scanline","width":160,"height":90,"fps":12,"durationSeconds":0.5,"seed":17},"outputRoot":"$ROOT/overlays"}
JSON
swift run fcpcommandconsole generate-overlays --fixture "$FIXTURE"
echo "overlay smoke artifacts: $ROOT/overlays"
