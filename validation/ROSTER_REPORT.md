# REDLINE roster recovery and validation — 2026-11-02

## Recovery checkpoint

Work continued in the existing Car Game project. This folder has no Git repository, so Git cannot identify committed versus uncommitted changes. Existing implementation was inspected in place; it was not reset or replaced. A pre-roster project snapshot exists at `checkpoints/pre-roster-20261102/project.zip`.

## Implemented and retained

- Thirty individually configured cars with original detailed 2D illustrations, independent wheels, vehicle-specific anchors, paint variants, and physics-driven effects. Existing garage, dealership, race, and customization renderers are reused.
- Factory gearboxes and ratios, drivetrain layouts, engine curves, and engine/audio profiles; existing 2–10-speed conversions remain available where compatible.
- Separate energy-limited electric assistance for the SF90. Engine dyno/output labels refer to combustion power; electric assistance is stated separately in dealership details.
- Quarter-mile-derived factory and installed-build classes, cached by mechanical configuration. The cache signature now includes throttle response. Benchmarks were regenerated after the throttle-response correction.
- Dealership class/make/drivetrain filters, owned-collection class/performance sorting, class-based race contracts, and build measurement before race entry.
- Deterministic retired-ID migration, preserved build archives, currency/career preservation, and collision compensation. First migration backs up the old save before writing; no claim is made that an actual player save was migrated during isolated tests.
- Corrected benchmark/planner vehicle-ID propagation, S2000 primary reduction, Golf R effective gearing, factory gearbox mass accounting, and supercharger/turbo replacement compatibility.

## Recovery fixes and validation changes

- Updated old-roster test fixtures to the new starter, prices, ownership IDs, gearboxes, and number of vehicles.
- Control checks now allow the new starter's natural free-rev response and request legal downshifts; over-rev protection remains enabled.
- Fresh-player testing earns the actual selected car's price rather than using the retired roster's lower price.
- The live estimate test checks the same profile-aware opponent contract as the menu.
- Runtime rendering/audio tests run graphically; waiting for a rendered frame in headless mode had caused a timeout.
- Standard validation includes roster benchmarks, model checks, and graphical roster checks.

## Measurement method

`tests/benchmark_roster.gd` uses the real VehicleBench/Drivetrain simulation, consistent track conditions, competent launch/clutch management, optimized shift maps, zero reaction delay, and no nitrous. Class thresholds: E ≥15 s; D 14–<15; C 13–<14; B 12–<13; A 10.5–<12; S <10.5. No elapsed-time override or horsepower-only class assignment is used.

`validation/roster_benchmarks.csv` contains all 30 factory configurations, eighth-mile and quarter-mile times, trap speed, derived class, requested class, and comparison targets. `validation/roster_results.json` also records upgraded-build times and classes. Repeatable potential, rather than player race execution, determines installed class.

## Important remaining limitations

- Manufacturer output ratings are sourced in `assets/data/roster.json`. Many masses, tires, and gearing fields still need individual provenance review. Torque curves are reconstructed estimates, not measured dyno traces. Aero, grip, inertia, efficiency, gearbox capacity and shift timing include engineering/gameplay approximations.
- The reference ET target column is a working calibration aid; not every target has a verified instrumented-test citation and identical conditions. Its deltas are not proof of accuracy.
- Largest current target differences include 350Z 13.170 s vs 14.1 s target, Miata 16.073 vs 16.8, and Demon 170 9.479 vs the prepared-track 8.91 claim. The Demon comparison also differs in track/launch conditions. These require calibration and stronger comparable evidence; they were not hidden by forcing times or classes.
- Actual classes are not five cars per group: RSX/BRZ are D, S2000/GR86/350Z are C, M3 is B, and Mustang/Camaro are A in this benchmark. This is intentional reporting of the simulation, not a claim that calibration is finished.
- Class matchmaking currently selects factory-build opponents. Very highly upgraded/open builds need a broader, benchmarked tuned-opponent pool. AI and benchmark launch drivers are not perfectly identical.
- Illustrations are original and distinct, but exact production-car geometry, all paint/window masks, extreme ride-height combinations, and wheel cutout edges still require artistic review. Factory spoilers are baked in; unsupported replacement spoiler choices are hidden while ownership is retained.
- Manufacturer names remain configurable; public-release branding/licensing decisions are outstanding.
- No new quantitative extraction of the supplied reference racing videos was performed during this recovery pass. Subjective engine tone, real touchscreen comfort, and performance on physical iPhones still require human/device testing.

## Test evidence

The final automated recovery result is recorded in `validation/roster_regression_results.json`; individual native Godot logs are under `validation/`. Screenshots of all 30 dealership cars are under `validation/roster_art/`; the contact sheet is `validation/roster_contact_sheet.png`. Test saves are isolated from player data.

### Final recovery results

All 36 native checks/benchmark/export runs passed. The menu test passed on a targeted rerun after fixing its retired-weight fixture and asynchronous benchmark setup; this rerun is marked in the aggregate JSON. Roster model validation: 405 checks. Roster graphical validation: 641 checks. Fresh-save gameplay UI validation: 4,488 checks, including 13 recovery races to fund the selected second car. The 204-run transmission analysis, career analysis, dealership analysis, and existing fitted-reference/audio analysis passed. The fitted legacy reference replay is a regression check, not independent verification of all 30 new cars.

Rendered screenshots and the regenerated contact sheet were inspected. Some production-model details and small wheel-cutout/edge artifacts need further artistic refinement; the roster is usable, but this report does not certify final art or complete factory-data accuracy. Low-end device performance and human driving/audio feel remain unverified.
