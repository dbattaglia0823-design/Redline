# REDLINE — validation and CI

**Status:** Commands checked against `.github/workflows/godot.yml` and `tools/run_regressions.py`; not executed to author this page.

CI uses Godot **4.6.3**, checks out the game and executes:

    python3 tools/run_regressions.py --godot "$RUNNER_TEMP/godot/Godot_v4.6.3-stable_linux.x86_64" --output .qa/ci

For a local installation on PATH, start with:

    python3 tools/run_regressions.py --godot godot --output .qa/local

The runner isolates save/user data per test and distinguishes headless and optional graphical categories. Its actual `HEADLESS` and `GRAPHICAL` lists are the authority, rather than a manually copied outdated test count. Some representative regression files:

- `tests/test_replacement_wheel_alignment.gd`, `test_visible_tire_sidewalls.gd`
- `tests/test_dealer_vehicle_type_tabs.gd`, `test_driver_skills.gd`
- `tests/test_transmissions.gd`, `test_racing_physics_audit.gd`
- `tests/test_turbo_blowoff.gd`, `test_career_save_migration.gd`

For UI changes, run appropriate graphical cases where the environment supports a display:

    python3 tools/run_regressions.py --godot godot --output .qa/graphics --graphical

Review actual runner semantics and artifacts first. CI's stored `validation/` reports may describe historical runs; inspect the current workflow conclusion and the actual report.

**Do not claim** headless success proves wheel artwork, touch-safe UI, accurate sound, or real-device performance. For save/career changes, validate existing profile compatibility and backups.

## Current CI limitation (verified 2026-11-18)

The full Godot 4.6.3 suite may report failure despite all game assertions in three UI integration tests passing: the engine aborts during shutdown (`exit=-6`). This is **not** a passing CI result. See [KNOWN_ISSUES.md](KNOWN_ISSUES.md). The runner now reports true process return codes and logs; continue requiring code 0. The roster image and tire-sidewall regression tests have been confirmed passing separately in full CI logs before merging their fixes.
