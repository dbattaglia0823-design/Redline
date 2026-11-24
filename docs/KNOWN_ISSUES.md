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

## 2026-11-24 follow-up: shutdown crash confirmed; fixture workarounds not effective

The three UI integration tests still print passing assertions yet abort with code `-6` on Godot 4.6.3. The original strict CI check remains **failed** and must not accept the printed `PASS` alone.

- [Baseline workflow](https://github.com/dbattaglia0823-design/Redline/actions/runs/45450398746): failure on the same three tests before new fixture attempts.
- [Synchronous scene and controller reference cleanup](https://github.com/dbattaglia0823-design/Redline/actions/runs/45453662230): failure, exit `-6`.
- [Running fixtures as ordinary Node scenes](https://github.com/dbattaglia0823-design/Redline/actions/runs/45454367770): failure, exit `-6`.
- [Clearing known script, UI and audio caches during scene exit](https://github.com/dbattaglia0823-design/Redline/actions/runs/45455941057): failure, exit `-6`.
- [Deep uncached PackedScene fixture loading](https://github.com/dbattaglia0823-design/Redline/actions/runs/45456587888): failure, exit `-6`.

The failing assertions are **not** the cause: their output still reports success. The failure occurs during native engine shutdown. This behavior resembles [Godot engine #119279](https://github.com/godotengine/godot/issues/119279) and [#119799](https://github.com/godotengine/godot/issues/119799), but the exact retained REDLINE resource has **not** been identified. The engine fix linked from #119279 targets the 4.8 release line and does not justify moving production to a prerelease engine without full compatibility testing.

Unsuccessful fixture and runtime experiments were **not merged into** the active PR. The regression runner, production game, profile saves and engine version remain unchanged. Next: isolate a concrete minimal reproducer or verify a compatible stable engine fix using real process exit codes, then rerun all required CI and mobile/graphical checks before declaring resolution.
