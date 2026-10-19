#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -z "${BLENDER_BIN:-}" ] && [ -f "$ROOT/work/blender-setup/env.sh" ]; then
  source "$ROOT/work/blender-setup/env.sh"
fi
mkdir -p "$ROOT/work/blender-tests"
RUN_DIR="$(mktemp -d "$ROOT/work/blender-tests/run-XXXXXXXX")"
printf 'Test output: %s\n' "$RUN_DIR"
"${BLENDER_BIN:-blender}" --background --factory-startup --python-exit-code 1 --python "$ROOT/cloud-blender/smoke_test.py" -- "$RUN_DIR" >"$RUN_DIR/blender.log" 2>&1 || { cat "$RUN_DIR/blender.log"; exit 1; }
cat "$RUN_DIR/report.json"

