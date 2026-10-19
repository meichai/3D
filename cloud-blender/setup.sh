#!/usr/bin/env bash
set -euo pipefail
# Debian 13 baseline. Does not touch models or user preferences.
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BLENDER_BIN="${BLENDER_BIN:-blender}"
if ! command -v "$BLENDER_BIN" >/dev/null 2>&1; then
  if [ "$(id -u)" = 0 ]; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends blender
  elif command -v sudo >/dev/null && sudo -n true 2>/dev/null; then
    sudo -n apt-get update
    sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends blender
  else
    echo 'Blender missing. Use a Debian 13 image with blender installed, or install it as administrator. Alternatively set BLENDER_BIN to an installed Blender 4.3.2 executable.' >&2
    exit 2
  fi
fi
"$BLENDER_BIN" --background --factory-startup --python-exit-code 1 --python-expr 'import bpy; assert bpy.app.version[:3] == (4,3,2), "Expected validated Blender 4.3.2; set up a matching image or validate a new version explicitly"; bpy.ops.preferences.addon_enable(module="io_scene_fbx"); [op.get_rna_type() for op in (bpy.ops.wm.stl_export,bpy.ops.wm.obj_export,bpy.ops.export_scene.fbx)]; print("Blender automation ready:", bpy.app.version_string)'
printf 'Ready. Run: bash %s/cloud-blender/test.sh\n' "$ROOT"
