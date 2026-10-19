#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# Read evidence only: testing must never create or repair initialization markers.
python3 - "$ROOT/work/blender-setup/initialized.json" "$ROOT" <<'PY'
import json
from pathlib import Path
import sys

marker = Path(sys.argv[1])
if not marker.exists():
    print("Initialization: UNVERIFIED (marker absent; installed Blender is not proof)")
else:
    try:
        data = json.loads(marker.read_text())
        required = ("setup_started_utc", "completed_utc", "blender_version",
                    "executable_path", "workspace", "boot_id")
        assert data["schema_version"] == 1
        assert data["result"] == "success" and data["exit_code"] == 0
        assert all(isinstance(data[key], str) and data[key] for key in required)
        assert data["workspace"] == sys.argv[2], "workspace mismatch"
        assert data["boot_id"] == Path("/proc/sys/kernel/random/boot_id").read_text().strip(), "boot mismatch"
        print("Initialization: success marker found; compare timestamps with the platform task start before claiming automatic initialization")
        print(json.dumps(data, indent=2))
    except (ValueError, KeyError, AssertionError, OSError) as error:
        print(f"Initialization: UNVERIFIED (invalid or stale marker: {error})")
PY

if [ -z "${BLENDER_BIN:-}" ] && [ -f "$ROOT/work/blender-setup/env.sh" ]; then
  source "$ROOT/work/blender-setup/env.sh"
fi
mkdir -p "$ROOT/work/blender-tests"
RUN_DIR="$(mktemp -d "$ROOT/work/blender-tests/run-XXXXXXXX")"
printf 'Test output: %s\n' "$RUN_DIR"
"${BLENDER_BIN:-blender}" --background --factory-startup --python-exit-code 1 --python "$ROOT/cloud-blender/smoke_test.py" -- "$RUN_DIR" >"$RUN_DIR/blender.log" 2>&1 || { cat "$RUN_DIR/blender.log"; exit 1; }
cat "$RUN_DIR/report.json"

