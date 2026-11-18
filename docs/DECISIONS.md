# REDLINE — current architecture decisions

These are **observed existing policies** backed by code and project reports, not newly invented historical rationales.

| Choice | Evidence | Change implication |
|---|---|---|
| Godot 4.6 / fixed 120 Hz physics and GL Compatibility | `project.godot`, `.github/workflows/godot.yml` | Keep tested runtime parity |
| Player and AI share simulation foundation | `scripts/race_ai.gd`, `scripts/drivetrain.gd` | Never make AI estimates use a different invented physics model |
| Driver progression uses stable-ID skill nodes | `scripts/driver_skills.gd` | Retain ranks and migration semantics |
| Cars are playable; bike/boat class tabs are previews | `scripts/dealership_view.gd`, `validation/DEALERSHIP_VEHICLE_TABS.md` | New vehicle types need dedicated physics/catalog/saves, not car ID substitution |
| Wheel art and engine sound have dedicated pipelines | `tools/VEHICLE_ASSET_PIPELINE.md`, `tools/ENGINE_AUDIO_PIPELINE.md` | Inspect asset lineage and tests before cleanup |
| Share reusable methods centrally, keep exact game mechanics local | This knowledge integration | Retrieve shared notes selectively |

For new major decisions, add the date, competing options, reason, PR link, tests, and any save-migration risk; mark obsolete policies as superseded.
