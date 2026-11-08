# REDLINE tracked-asset cleanup — 2026-11-08

This cleanup intentionally deletes **verified obsolete artwork, old backup snapshots, and reproducible QA outputs**, not all assets without a literal code reference. Dynamic resource paths, JSON manifests, audio banks, customization variants, and source-art pipelines require special handling.

## Repository-wide inventory

The initial audit scanned 16,411 tracked files (including the first two audit files), totaling 1,234.96 MiB, and searched 319 script/config/document sources. Regenerate the audit with:

```
python tools/audit_repository_assets.py
```

The audit output is written to ignored `.qa/asset_inventory.json`; GitHub Actions also publishes it as an artifact.

## Removed from version control

| Classification | Files | Original size |
| --- | ---: | ---: |
| Old `checkpoints/` snapshots, retired audio renders and script copies | 1,516 | 43.35 MiB |
| Artwork for 12 retired fictional models no longer in `RosterData.IDS` | 600 | 1.57 MiB |
| Reproducible `validation/vehicle_art/` image captures | 248 | 82.68 MiB |
| Reproducible `validation/studio_roster/` image captures (retaining `.gdignore`) | 104 | 34.68 MiB |
| Reproducible `validation/track_environments/` screenshots | 18 | 11.69 MiB |
| Redundant `validation/audio_listening/` WAV copies | 18 | 17.58 MiB |
| A compiled Python cache and orphan Godot UID file | 2 | <0.01 MiB |
| **Total** | **2,506** | **191.57 MiB before re-homing audio baselines** |

Thirty historic audio comparison WAVs (7.14 MiB) have been **re-homed** from `checkpoints/audio-realism-20261104/before/` to `validation/audio_baseline/`, so the comparison script still works. **Net tracked-file reduction: about 184.43 MiB.**

Historic source versions remain recoverable from Git history.

## Kept intentionally

- All 30 current car models, paint/finish variants, masks, wheels and customization layers.
- `Replacement Vehicle Models/` and `Bike Images and Templates/` — current and future vehicle source artwork, not interchangeable with generated runtime textures.
- All active engine banks, `assets/audio/engines/bank.json`, synthesized WAV assets and their associated import settings.
- Premium source atlases, metadata and authoring inputs, and the remaining test fixtures and visual QA records.
- `RosterData.RETIRED`, historical vehicle specification IDs, and old-save migration logic. Only unused *artwork* for those IDs and manifest references were removed.

Art installers and audio bank-pruning scripts now put backups in gitignored `.qa/` instead of committed `checkpoints/`. Future generated preview screenshots and listening copies are ignored. `tests/test_asset_cleanup.gd` checks for missing active art, active audio assets, and intact retired-model migration targets.

## Validation limits

This is a static reference audit plus a targeted preservation test. It cannot prove that every unreferenced file is safe to delete because some resources are loaded by generated paths, saved IDs, build tools, or editor workflows. Uncertain assets remain in place rather than risking loss of player content or source art.
