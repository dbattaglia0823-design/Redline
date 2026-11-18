# REDLINE — race, vehicle and progression systems

**Status:** Verified source-path survey. This page does not certify full game functionality.

## Drag-race control

- `scripts/drivetrain.gd` is the physical car/powertrain simulation used by race systems.
- `scripts/race_ai.gd` defines `RaceAI`: it prepares simulated AI contracts, batches estimate calculations across frames, and uses `Drivetrain` in race/estimate stepping. Preserve parity rather than inventing separate physics.
- `scripts/transmission_catalog.gd`, `scripts/shift_planner.gd`, `scripts/race_controls.gd`: gearbox catalog, shift recommendations and input integration.
- `scripts/run_telemetry.gd`, `scripts/race_hud.gd`: actual telemetry and race UI.

## Career, upgrades, driver skill tree

- `scripts/driver_skills.gd` contains stable-ID skill nodes with categories Launch, Shifting, Racecraft and Career.
- `scripts/profile.gd`, `career_board.gd`, `upgrade_workshop.gd`, `game_catalog.gd` own saved progression, upgrade pathways, events and opponent definitions. Inspect call sites before changing reward scaling or money limits.
- `tests/test_driver_skills.gd`, `test_career_save_migration.gd`, `test_betting_progression.gd` guard related changes.

## Vehicle catalog, ownership and previews

- `scripts/dealership_view.gd` has tabs for Cars, Bikes and Boats/Jet skis (`vehicle_type` state). The non-car categories are **preview-only**, not a playable bike/watercraft catalog; the distinction is described in [the existing validation note](../../validation/DEALERSHIP_VEHICLE_TABS.md).
- `scripts/roster_data.gd`, `game_catalog.gd`, `vehicle_parts.gd`, `vehicle_renderer.gd`: inspect before importing new cars or replacing artwork.
- `scripts/wheel_visuals.gd`, `rim_art.gd` handle wheel and rim placement; test new car models, tire sidewalls, and hub alignment across actual render sizes.
- Vehicle art/asset procedures are in `tools/ROSTER_ASSET_PIPELINE.md`, `tools/VEHICLE_ASSET_PIPELINE.md`, and `tools/PROJECT_ASSET_CLEANUP.md`.

## Dynamic induction and audio

- `scripts/engine_audio.gd` and `scripts/engine_voice.gd` manage engine voices and effects; `scripts/engine_loop_player.gd` is also part of playback.
- Keep blow-off and spool response tied to actual source state and gear shifts; avoid losing existing audio profiles when tuning a specific engine.
- Regression anchors: `tests/test_turbo_blowoff.gd`, `tests/test_dynamic_audio.gd`, `tests/test_launch_induction_audio.gd`.

## Test discipline

Run project-specific tests through `tools/run_regressions.py` before treating a modification as verified. Graphical/UI or real mobile playback checks may remain separate. See [TESTING.md](../TESTING.md).
