#!/usr/bin/env bash
# External user JSON profiles must inherit from the installed system bundle in headless CLI mode.
# This mirrors the startup-profile loading path used by ORTO integration.
#
# usage: test_cli_external_user_profile_inheritance.sh <orca-slicer binary> <python3> <resources/profiles/BBL>
set -u

BIN="${1:-}"
PY="${2:-python3}"
PROFILES="${3:-}"
[ -x "$BIN" ] || { echo "SKIP: orca-slicer binary not found: $BIN"; exit 77; }
[ -d "$PROFILES" ] || { echo "FAIL: profiles directory not found: $PROFILES"; exit 1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/orca-cli-user-profile-inheritance.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/out"

"$PY" - "$PROFILES" "$WORK" <<'EOF'
import json
import os
import sys

profiles, work = sys.argv[1:]
cases = [
    ("machine/Bambu Lab H2D 0.4 nozzle.json", "user-machine.json",
     "CLI External User Machine", "printer_settings_id"),
    ("filament/Bambu PLA Basic @BBL H2D.json", "user-filament.json",
     "CLI External User Filament", "filament_settings_id"),
]
for source, target, name, id_key in cases:
    with open(os.path.join(profiles, source), encoding="utf-8") as f:
        config = json.load(f)
    config["from"] = "User"
    config["name"] = name
    if id_key == "printer_settings_id":
        config[id_key] = name
        # This key is supplied by the inherited machine parent, not by this profile.
        config.pop("default_print_profile", None)
    else:
        config[id_key] = [name]
        # These values are supplied by the inherited filament parent.
        config.pop("filament_density", None)
    with open(os.path.join(work, target), "w", encoding="utf-8") as f:
        json.dump(config, f, ensure_ascii=False, indent=2)

# A minimal closed cube is sufficient for a real CLI slice.
vertices = [(x, y, z) for z in (0, 10) for y in (0, 10) for x in (0, 10)]
triangles = ((0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4),
             (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5))
with open(os.path.join(work, "cube.stl"), "w", encoding="ascii") as f:
    f.write("solid cube\\n")
    for a, b, c, d in triangles:
        for tri in ((vertices[a], vertices[b], vertices[c]),
                    (vertices[a], vertices[c], vertices[d])):
            f.write("facet normal 0 0 0\\nouter loop\\n")
            for x, y, z in tri:
                f.write("vertex %g %g %g\\n" % (x, y, z))
            f.write("endloop\\nendfacet\\n")
    f.write("endsolid cube\\n")
EOF

timeout 300 "$BIN" --datadir "$WORK/datadir" \
    --load-settings "$WORK/user-machine.json;$PROFILES/process/0.20mm Standard @BBL H2D.json" \
    --load-filaments "$WORK/user-filament.json" \
    --slice 0 --outputdir "$WORK/out" --export-3mf out.3mf "$WORK/cube.stl" \
    > "$WORK/cli.log" 2>&1
RC=$?
if [ "$RC" -ne 0 ]; then
    echo "FAIL: CLI exited $RC while loading external user profiles"
    tail -n 80 "$WORK/cli.log"
    exit 1
fi

"$PY" - "$WORK/out/out.3mf" <<'EOF'
import json
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as archive:
    config = json.loads(archive.read("Metadata/project_settings.config"))

errors = []
if config.get("printer_settings_id") != "CLI External User Machine":
    errors.append("printer_settings_id is %r" % config.get("printer_settings_id"))
if config.get("default_print_profile") != "0.20mm Standard @BBL H2D":
    errors.append("inherited default_print_profile is %r" % config.get("default_print_profile"))
if "CLI External User Filament" not in config.get("filament_settings_id", []):
    errors.append("filament_settings_id is %r" % config.get("filament_settings_id"))
if not config.get("filament_density"):
    errors.append("inherited filament_density is missing")
if errors:
    for error in errors:
        print("FAIL: " + error)
    sys.exit(1)
EOF

echo "PASS"
