#!/usr/bin/env bash
set -euo pipefail
# No sudo or system package changes. Logs survive in the task workspace.
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/work/blender-setup"
# Invalidate previous success before attempting initialization again.
MARKER="$ROOT/work/blender-setup/initialized.json"
rm -f -- "$MARKER"
SETUP_STARTED_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
LOG="$(mktemp "$ROOT/work/blender-setup/setup-XXXXXXXX.log")"
exec > >(tee -a "$LOG") 2>&1
echo "Setup log: $LOG"
BLENDER_BIN="${BLENDER_BIN:-blender}"
if ! command -v "$BLENDER_BIN" >/dev/null 2>&1; then
  INSTALL_DIR="${BLENDER_INSTALL_DIR:-$ROOT/work/blender-runtime}"
  BLENDER_BIN="$INSTALL_DIR/blender-4.3.2-linux-x64/blender"
  if [ ! -x "$BLENDER_BIN" ]; then
    if [ "${BLENDER_ALLOW_DOWNLOAD:-0}" != 1 ]; then
      echo 'Blender missing. Set BLENDER_BIN to an existing executable, or BLENDER_ALLOW_DOWNLOAD=1 for a user-space install (Linux x86_64).'
      exit 2
    fi
    [ "$(uname -s)/$(uname -m)" = Linux/x86_64 ] || { echo 'Download supports Linux x86_64 only'; exit 2; }
    mkdir -p "$INSTALL_DIR"
    INSTALL_DIR="$(cd "$INSTALL_DIR" && pwd)"
    BLENDER_BIN="$INSTALL_DIR/blender-4.3.2-linux-x64/blender"
    STAGE="$(mktemp -d "$INSTALL_DIR/.download-XXXXXXXX")"
    trap 'rm -rf -- "$STAGE"' EXIT
    BASE=https://download.blender.org/release/Blender4.3
    ARCHIVE=blender-4.3.2-linux-x64.tar.xz
    curl --fail --location --retry 2 --connect-timeout 15 "$BASE/$ARCHIVE" -o "$STAGE/$ARCHIVE"
    curl --fail --location --retry 2 --connect-timeout 15 "$BASE/blender-4.3.2.sha256" -o "$STAGE/checksums"
    (cd "$STAGE"; awk -v name="$ARCHIVE" '$2 == name || $2 == "*" name {print}' checksums > selected.sha256; test -s selected.sha256; sha256sum -c selected.sha256)
    tar -xJf "$STAGE/$ARCHIVE" -C "$STAGE"
    [ ! -e "$INSTALL_DIR/blender-4.3.2-linux-x64" ] || { echo 'Refusing to overwrite existing installation'; exit 2; }
    mv "$STAGE/blender-4.3.2-linux-x64" "$INSTALL_DIR/"
  fi
fi
BLENDER_BIN="$(readlink -f -- "$(command -v "$BLENDER_BIN")")"
echo "Using Blender: $BLENDER_BIN"
"$BLENDER_BIN" --background --factory-startup --python-exit-code 1 --python-expr 'import bpy; assert bpy.app.version[:3] == (4,3,2), "Expected validated Blender 4.3.2; set up a matching image or validate a new version explicitly"; bpy.ops.preferences.addon_enable(module="io_scene_fbx"); [op.get_rna_type() for op in (bpy.ops.wm.stl_export,bpy.ops.wm.obj_export,bpy.ops.export_scene.fbx)]; print("Blender automation ready:", bpy.app.version_string)'

printf 'export BLENDER_BIN=%q\n' "$BLENDER_BIN" > "$ROOT/work/blender-setup/env.sh"
BLENDER_VERSION="$("$BLENDER_BIN" --version)"
export BLENDER_VERSION BLENDER_BIN SETUP_STARTED_UTC
python3 - "$MARKER" "$ROOT" "$LOG" <<'PY'
import datetime
import json
import os
from pathlib import Path
import sys
import tempfile

marker = Path(sys.argv[1])
payload = {
    "schema_version": 1,
    "setup_started_utc": os.environ["SETUP_STARTED_UTC"],
    "completed_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "blender_version": os.environ["BLENDER_VERSION"].splitlines()[0],
    "executable_path": os.environ["BLENDER_BIN"],
    "result": "success",
    "exit_code": 0,
    "workspace": sys.argv[2],
    "setup_log": sys.argv[3],
    "boot_id": Path("/proc/sys/kernel/random/boot_id").read_text().strip(),
}
# Same-directory rename publishes a complete file, never partial JSON.
fd, temporary = tempfile.mkstemp(prefix=".initialized-", dir=marker.parent)
try:
    with os.fdopen(fd, "w") as stream:
        json.dump(payload, stream, indent=2)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, marker)
    directory_fd = os.open(marker.parent, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(directory_fd)
    finally:
        os.close(directory_fd)
finally:
    if os.path.exists(temporary):
        os.unlink(temporary)
PY
printf 'Initialization marker: %s\n' "$MARKER"
printf 'Ready. Run: bash %s/cloud-blender/test.sh\n' "$ROOT"
