# REDLINE — project knowledge index

**Repository survey:** 2026-11-18, `main` (selected code and workflows inspected; not an end-to-end game run).

| Task | Project reference | Code / validation |
|---|---|---|
| Architecture and module ownership | [ARCHITECTURE.md](ARCHITECTURE.md) | `project.godot`, `scripts/`, `scenes/main.tscn` |
| Drivetrain, race AI, transmissions, wheels | [RACE_AND_VEHICLES.md](systems/RACE_AND_VEHICLES.md) | `scripts/drivetrain.gd`, `race_ai.gd`, `transmission_catalog.gd`, `wheel_visuals.gd` |
| Toolkit UI and responsive screen contracts | [Toolkit UI integration](../tools/TOOLKIT_UI_INTEGRATION.md) | `scripts/garage_hub.gd`, `glass_palette.gd`, `dealership_view.gd` |
| Vehicle acquisition and category tabs | [Dealership category state](../validation/DEALERSHIP_VEHICLE_TABS.md) | `scripts/dealership_view.gd`, `scripts/game_catalog.gd` |
| Transmission behavior | [Transmission report](../validation/TRANSMISSION_REPORT.md) | `scripts/drivetrain.gd`, `scripts/transmission_catalog.gd` |
| Steering, traction and drag physics | [Physics model](../validation/PHYSICS_MODEL.md) | `scripts/drivetrain.gd`, `tests/test_physics.gd` |
| Wheel layers, sprite positioning and assets | [Wheel rotation](../validation/WHEEL_ROTATION_REPORT.md), [art pipeline](../tools/VEHICLE_ASSET_PIPELINE.md) | `scripts/wheel_visuals.gd`, `tests/test_replacement_wheel_alignment.gd` |
| Dynamic turbo/BOV sound | [Audio pipeline](../tools/ENGINE_AUDIO_PIPELINE.md) | `scripts/engine_audio.gd`, `engine_voice.gd`, related audio tests |
| Skills, garage, career and economy | [RACE_AND_VEHICLES.md](systems/RACE_AND_VEHICLES.md) | `scripts/driver_skills.gd`, `career_board.gd`, `profile.gd` |
| Actual CI checks | [TESTING.md](TESTING.md) | `.github/workflows/godot.yml`, `tools/run_regressions.py` |
| Decision log, known risks, next handoff | [DECISIONS.md](DECISIONS.md), [KNOWN_ISSUES.md](KNOWN_ISSUES.md), [HANDOFF.md](HANDOFF.md) | Actual PR/test results |

Shared, reusable documentation: https://github.com/dbattaglia0823-design/Game-Dev-Toolkit/tree/main/knowledge. **Do not copy the entire vault into REDLINE.** Game code and tests take priority over shared notes.
