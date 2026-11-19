# REDLINE — verification and regression watchlist

**Not a declaration of currently broken features.** Reproduce any suspected defect in the current revision before treating it as open.

| Concern to recheck when changing the subsystem | Test or source anchor |
|---|---|
| Wheel rims and tire sidewalls can vary by car art and anchor alignment | `tests/test_replacement_wheel_alignment.gd`, `tests/test_visible_tire_sidewalls.gd`, `scripts/wheel_visuals.gd` |
| New dealership categories must not mutate car ownership or credits | `tests/test_dealer_vehicle_type_tabs.gd`, `validation/DEALERSHIP_VEHICLE_TABS.md` |
| Sound must react to shifts and throttle lift without state leaking between cars | `tests/test_turbo_blowoff.gd`, `scripts/engine_audio.gd` |
| Career/skill progression must preserve existing saves | `tests/test_career_save_migration.gd`, `test_driver_skills.gd` |
| Race simulation must remain consistent with AI estimates | `scripts/race_ai.gd`, `scripts/drivetrain.gd`, `tests/test_ai_progression.gd` |

Record reproducible issues with build SHA, observed vs expected behavior, steps, test evidence and owning PR. Never label old reports as current failures without reproducing them.

## Verified regression blocker — Godot 4.6.3 shutdown in scripted UI tests (2026-11-18)

Three tests currently print passing assertions but the **Godot process exits with -6 (SIGABRT)** during shutdown: `tests/test_driver_skill_page.gd`, `tests/test_tuning_consolidation.gd` and `tests/test_dealer_vehicle_type_tabs.gd`. GDB reproduced a native SIGSEGV in `pthread_mutex_lock(0x1c0)` after the tests report PASS. These failures existed on `main` before the knowledge-base documentation changes.

- **Evidence:** [REDLINE regression run](https://github.com/dbattaglia0823-design/Redline/actions/runs/44423316134), [native debugger trace](https://github.com/dbattaglia0823-design/Redline/actions/runs/44421182301), and the PR investigation in [#15](https://github.com/dbattaglia0823-design/Redline/pull/15).
- **Plausible upstream relationship (not proven identical cause):** [Godot GDScript lifetime and shutdown issue #119799](https://github.com/godotengine/godot/issues/119799), reproducible in Godot 4.6.3.
- **Ruled out in these experiments:** changing rendering method, single-threaded scene mode, delaying audio shutdown, suppressing live audio for the UI fixtures, and simply deferring `quit()` did **not** produce clean exits. The unsuccessful workarounds were deliberately excluded from the main game.
- **Do not:** whitelist `exit=-6`, change the runner to accept `PASS` text alone, or claim these tests pass in CI.
- **Next evidence needed:** a minimal reproducer isolating surviving scripted references or verified engine-level fix under a compatible Godot build, followed by full CI and actual device quit testing. Do not upgrade the whole game engine without compatibility review.
