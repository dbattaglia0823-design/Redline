# AI career difficulty pass

Career rivals now have fixed, authored builds. The prior player-class replacement pool was removed: buying upgrades or switching to a fast car no longer silently strengthens the first rival. Existing career wins, cash, wagers, distances, unlocks and reward rules are preserved.

Opening Dockside rivals:

| Rival | Car | Engine HP | Build |
| --- | --- | ---: | --- |
| Dex | Miata | 116 | Stock |
| Nia | Miata | 132 | Stage 1 engine |
| Sol | Civic Si | 193 | Engine/exhaust and street tires |
| Leo | Golf GTI VR6 | 208 | Engine/exhaust and street tires |
| Quinn | RSX Type-S | 242 | Engine/exhaust, tires and weight reduction |

Later tiers use stronger BRZ/GTI/Supra/Evo builds, followed by performance cars. Launch reaction, throttle control and shifting become more competent through the ladder. These are real input decisions through the existing drivetrain, not speed or force multipliers. The race-start reaction clamp was adjusted so novice reaction settings actually survive entry into gameplay.

Validation performed:

- All 15 contracts finish without safety clamps. Simulated quarter-mile pace improves at every ladder step; see `ai_progression.json` and `career_balance.csv`.
- Fresh starter from idle with ordinary simulated shifts: 7.762 s over 100 m against 8.841 s for the first rival.
- Native keyboard-driven first race, including staging, actual manual gear input and result settlement: after the quarter-mile distance update, starter wins 17.598 s versus 19.258 s. Correct $250 reward and first career win verified. Screenshot: `first_race_result.png`.
- Passed: test_ai_progression, test_ai_start_ui, test_career, test_rival, test_menus, test_flow, test_roster_ui, test_quality_ui, test_quality_model, test_controls, test_economy. Career analysis passed.
- Added the two new tests to tools/validate_racing.ps1.

These are automated simulations and native input tests, not a guarantee that every new player wins. Human testing should assess the manual/clutch learning curve and later-tier upgrade pacing. Player physics, saves and purchases were not reworked.

