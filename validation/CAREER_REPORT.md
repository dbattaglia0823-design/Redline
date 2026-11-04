# Racing loop and AI validation

Current career balancing is documented in AI_DIFFICULTY_REPORT.md. The earlier implementation notes below are historical; the latest calibration table reflects the new fixed-build ladder.

The existing race board, staging lights, physical races, finish coast, time slips, payouts, garage and career ladders remain the gameplay loop. This phase connects opponents to their own purchased-style hardware builds, adds useful race estimates/matchmaking, and improves save commits. No speed multipliers, rubber-banding or predetermined winners are used.

## Changes

- All 15 opponents configure the same Drivetrain used by the player, including their engine stages, gearbox ratios, efficiency, torque rating, clutch/converter and shift map. Their builds cover H manuals, sequential, paddle, DCT, modern and drag automatics.
- RaceAI manages reaction, staging throttle, wheelspin recovery, manual clutch/lift shifts, paddle requests and installed automatic controllers. Skill changes inputs and small reproducible mistakes. Race attempts vary the driver seed and reaction by up to 20 ms; this does not alter vehicle forces or select a winner.
- Modern converter AI holds neutral through reaction and physically selects Drive afterward; drag builds install and hold a compatible transbrake instead. Testing initially caught converter creep when the manual clutch input was incorrectly relied on; the correction prevents early movement without freezing road speed.
- The race board displays real configured horsepower, simulated quarter-mile estimates, skill/difficulty and a Find Match action. Matching compares the player's installed build with unlocked opponents over that event's actual distance. Estimates use the same AI controller and shared physics; they are assisted driving estimates, not guaranteed human times or win probabilities.
- Existing 100 m challenges, eighth-mile and quarter-mile events remain available through the career ladder. Existing optional matching fictional-credit stakes, loss/forfeit rules, zero-stake recovery races, base pay and XP remain intact. Higher career tiers and rivals pay more. There are no real-money transactions.
- Time slips add player launch-input reaction beside shift quality; the main clock remains explicitly measured from green, including reaction. Reaction excludes time spent holding the brake, transbrake or manual clutch. Staging/countdown and finish-coast feedback remain connected to the existing presentation.
- First Win, Five Wins and City Champion badges are derived from saved wins/career progress, preventing duplicate milestone state. Existing level 3/5 race-tier unlocks remain; dealership purchases remain credit-based and previously available cars are not newly locked.
- Saves flush a temporary file and rename it into place, committing credits, XP, wager and career fields together. Existing duplicate-entry/reward guards and interrupted-wager forfeiture remain. This reduces partial-write risk; it does not promise protection against deliberate save-file editing or all storage failures.

## Verification

The all-opponent test configures real hardware, stages the engine, verifies no movement before reaction, simulates event finishes, and records every opponent's quarter-mile estimate, horsepower, gearbox and RPM safety clamps in `rival_test_results.json`. Calibration spans approximately 14.7 to 9.4 seconds across the career; different race distances and transmission tradeoffs can produce close or non-monotonic neighboring quarter-mile times. Final-tier bosses are verified faster than the first final-tier rival through actual simulation.

`test_career.gd` checks unlocked-only matchmaking, actual AI upgrade effects, repeatable estimates, career/milestone persistence, temporary-file save commits, duplicate entries and zero-stake recovery access. Existing economy, UI, keyboard/mouse/multitouch, garage, race-flow, physics, audio, and 204 transmission comparison runs remain part of `tools/validate_racing.ps1`.

Graphical race-flow tests play the shared simulation through finish, payout and reload. The changes preserve the existing player physics and reference calibration. Numerical estimates are not human balance validation. Physical-phone usability, subjective difficulty/feel and broad player-economy tuning still need playtesting. Opponent audio and art were not rebuilt, and no proprietary reference formulas or recordings were copied.


Windows runtime limitation: an intermittent native access violation (0xC0000005) can occur during process shutdown after graphical tests print PASS. Explicit audio stop and orderly node cleanup were added; the full suite subsequently passed, but a fresh-extraction flow test still reproduced the shutdown fault. This remains unresolved and is not counted as a passing clean-process exit. Core assertions and the fresh import/physics/transmission/controls/garage/AI/career checks passed before that failure. It is distinct from the corrected early-launch bug, and should be investigated before release.

## Calibration table

Fixed base driver seeds, two seconds of staging, 240 Hz engine solver, reaction included. Actual attempts add small driver variation. Trap is line-crossing speed. These are simulation results, not footage measurements.

| Tier / rival | Gearbox | HP | Quarter seconds | Line mph |
| --- | --- | ---: | ---: | ---: |
| 1 / 1 | oem_miata | 116 | 19.255 | 77.5 |
| 1 / 2 | oem_miata | 132 | 17.633 | 83.8 |
| 1 / 3 | oem_civic_si | 193 | 16.608 | 90.2 |
| 1 / 4 | oem_gti_vr6 | 208 | 15.038 | 97.4 |
| 1 / 5 | oem_rsx | 242 | 14.315 | 104.0 |
| 2 / 1 | oem_brz | 271 | 13.531 | 107.9 |
| 2 / 2 | oem_gti | 296 | 13.495 | 110.7 |
| 2 / 3 | oem_supra | 421 | 12.155 | 120.8 |
| 2 / 4 | oem_evo | 400 | 11.827 | 120.1 |
| 2 / 5 | seq6 | 472 | 11.148 | 132.2 |
| 3 / 1 | oem_mustang | 580 | 11.146 | 132.8 |
| 3 / 2 | drag3 | 652 | 10.545 | 141.0 |
| 3 / 3 | oem_gtr | 886 | 9.820 | 152.7 |
| 3 / 4 | oem_mclaren | 992 | 9.230 | 172.5 |
| 3 / 5 | oem_chiron | 2306 | 8.409 | 194.8 |
