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
