#!/usr/bin/env python3
"""Report tracked REDLINE assets and references without deleting anything.

Static reference checks are evidence, not proof of runtime disuse: Godot assets
may be loaded by ID, path format strings, manifests and build/QA tools.
"""
from __future__ import annotations
import collections
import json
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
paths = [p.decode("utf-8") for p in subprocess.check_output(
    ["git", "ls-files", "-z"], cwd=ROOT).split(b"\0") if p]
sizes = {p: (ROOT / p).stat().st_size for p in paths}
source_ext = {".gd", ".py", ".json", ".tscn", ".tres", ".cfg", ".md",
              ".yml", ".yaml", ".ps1", ".bat", ".js", ".mjs", ".cs"}
text = {}
for p in paths:
    if p.startswith(("checkpoints/", "validation/")) or p.endswith((".import", ".uid")):
        continue
    if pathlib.Path(p).suffix.lower() in source_ext:
        try:
            text[p] = (ROOT / p).read_text(encoding="utf8", errors="replace")
        except OSError:
            continue

def refs(prefix):
    # Entire folder, not just its name, to catch quoted dynamic asset roots.
    return sorted(p for p, body in text.items() if prefix in body)

def folder_stats(prefix):
    matched = [p for p in paths if p.startswith(prefix)]
    return {"files": len(matched), "bytes": sum(sizes[p] for p in matched),
            "refs": refs(prefix)}

prefixes = ["checkpoints/", "validation/", "Replacement Vehicle Models/",
            "Bike Images and Templates/", "assets/vehicles/source_atlases/",
            "assets/vehicles/source_premium/", "assets/audio/engines/",
            "assets/audio/asset_manifest.json",
            "assets/vehicles/atlas_geometry."]
old = ["kaze", "nori", "aster", "vanta", "mika", "brindle",
       "comet", "rikka", "velora", "solenne", "aurora", "hammer"]
for id in old:
    prefixes.append(f"assets/vehicles/{id}/")
for p in paths:
    if p.startswith("validation/"):
        parts = p.split("/")
        if len(parts) >= 3 and parts[1] not in ("",):
            prefix = "validation/" + parts[1] + "/"
            if prefix not in prefixes:
                prefixes.append(prefix)
for p in paths:
    if p.startswith("checkpoints/"):
        prefix = "/".join(p.split("/")[:2]) + "/"
        if prefix not in prefixes:
            prefixes.append(prefix)
stats = {p: folder_stats(p) for p in prefixes}
orphans = []
for p in paths:
    if p.endswith(".import") and p[:-7] not in sizes:
        orphans.append(p)
    if p.endswith(".gd.uid") and p[:-4] not in sizes:
        orphans.append(p)
caches = [p for p in paths if "/__pycache__/" in p or p.endswith(".pyc")]
import_count = len([p for p in paths if p.endswith(".import")])
content_count = len([p for p in paths if p.endswith(".gd.uid")])
direct = set()
for p, body in text.items():
    for found in re.findall(r"res://([^\s\"'\)<>]+)", body):
        direct.add(found)
direct_missing = sorted(p for p in direct if "%" not in p and "{" not in p
                        and p not in sizes and not p.startswith(".qa/")
                        and (ROOT / p).exists() is False)
result = {
    "tracked_files": len(paths),
    "total_bytes": sum(sizes.values()),
    "text_sources_scanned": len(text),
    "folders": stats,
    "orphan_import_or_uid": orphans,
    "cached_bytecode": caches,
    "import_metadata_count": import_count,
    "godot_uid_count": content_count,
    "missing_literal_res_paths": direct_missing[:150],
}
out = ROOT / ".qa" / "asset_inventory.json"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(result, indent=2) + "\n", encoding="utf8")
print("ASSET INVENTORY: %s tracked, %.1f MiB, %s source files scanned" %
      (len(paths), sum(sizes.values()) / 1048576, len(text)))
for prefix, data in sorted(stats.items(), key=lambda item: -item[1]["bytes"]):
    print("%-62s %6d files %8.1f MiB %2d references %s" %
          (prefix, data["files"], data["bytes"] / 1048576,
           len(data["refs"]), ", ".join(data["refs"][:6])))
print("ORPHAN_IMPORT_UID", len(orphans))
print("CACHED_BYTECODE", caches)
