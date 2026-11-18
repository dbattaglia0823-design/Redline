# REDLINE — architecture map

**Status:** File-level and selected source-path review on 2026-11-18. Current runtime behavior has not been tested in this documentation PR.

| Area | Actual implementation | Validation / contract |
|---|---|---|
| Entry scene | `project.godot`, `scenes/main.tscn`, `scripts/main.gd` | `tests/test_runtime.gd`, `tests/test_flow.gd` |
| Vehicle physics, gearbox and tuning | `scripts/drivetrain.gd`, `transmission_catalog.gd`, `tuning_setup.gd`, `gearbox_tuning_panel.gd` | `tests/test_physics.gd`, `test_transmissions.gd` |
| AI rivals and time estimates | `scripts/race_ai.gd`, `game_catalog.gd` | `tests/test_ai_progression.gd` |
| Driver skills / profile | `scripts/driver_skills.gd`, `profile.gd`, `career_board.gd` | `tests/test_driver_skills.gd`, `test_career_save_migration.gd` |
| Garage, dealership and customization | `scripts/garage_hub.gd`, `dealership_view.gd`, `customization_view.gd`, `vehicle_appearance.gd` | `tests/test_dealership.gd`, `test_customization.gd` |
| Art and wheel alignment | `scripts/vehicle_renderer.gd`, `wheel_visuals.gd`, `rim_art.gd`, `assets/`, `Replacement Vehicle Models/` | `tests/test_replacement_wheel_alignment.gd`, art pipeline docs |
| Sound synthesis and effects | `scripts/engine_audio.gd`, `engine_voice.gd`, `engine_loop_player.gd`, `engine_audio_profile.gd` | `tests/test_turbo_blowoff.gd`, `test_launch_induction_audio.gd` |
| Mobile/UI layout and race HUD | `scripts/mobile_view.gd`, `glass_dock.gd`, `race_hud.gd`, `garage_view.gd` | `tools/TOOLKIT_UI_INTEGRATION.md`, UI tests |
| Testing / assets | `tools/run_regressions.py`, `.github/workflows/godot.yml`, `validation/` | Distinguish archived reports from current CI results |

## Important constraints

The main scene is `res://scenes/main.tscn`; Godot project config requests 4.6 GL Compatibility and 120 physics ticks per second. CI downloads Godot 4.6.3.

Drivetrain is the shared simulation for player and AI behaviors. Profile, upgrade hardware and saved race results have existing compatibility requirements. Different gearbox types and vehicle visuals must retain their current contracts.

`validation/` contains prior audit artifacts, screenshots and data. They are **reference evidence**, not proof that the latest revision has passed tests. Check actual current sources and CI before claiming a feature is working.

## Focused study

For race mechanics and vehicle art, start at [Race and vehicle systems](systems/RACE_AND_VEHICLES.md). For gameplay-specific verification, follow [TESTING.md](TESTING.md).
