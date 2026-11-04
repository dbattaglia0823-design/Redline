# Transmission and vehicle upgrade validation

The existing game now has 21 gearbox configurations covering 2–10 forward gears, six transmission stages, and 34 purchasable mechanical parts across 20 slots. Existing cars, legacy stages, controls, wagers and saves remain compatible. The default Original 6P retains paddle shifting and its previous race balance.

## Verified results

- Coupled-physics regression: 144,353 checks passed. Stock Kaze remains 13.219266 s at 109.853 mph; the existing tier-three build remains 10.001113 s at 151.606 mph.
- Transmission/parts suite: 45,062 checks passed, including all ratios, H-gate clutch/overrev protection, paid control conversions, converter passivity and lockup, transbrake launch, foot-brake holding, strength/wear, cooling, part prerequisites, tuning bounds, gearbox-specific ownership/stages, save/load and audio telemetry. Counts include individual generated-audio sample validity checks.
- 168 matched main benchmark runs: every gearbox on two setups, calculated maps versus 6,500 / 7,000 / 7,400 RPM strategies. No safety clamps. Worst calculated-map deficit against the best tested fixed strategy: **0.0001 s**. This is competitive within the tested grid, not a proof of global optimality.
- 36 additional paired tuning runs: 3D wins 2 of 18 pairs; 10A wins 16. Gear count does not determine the winner.
- Rendered upgrade/control interaction tests passed: all 21 configurations reachable, real purchases, locked tuning, paddle conversion, H-gate keyboard and three-finger input, B transbrake and vehicle-test isolation.
- Existing audio, controls, menus, economy, rivals, race-flow and 30/60/120/144 FPS runtime suites pass. Native Windows drag playtest: 12.817 s at 114.0 mph, two automatic shifts, zero RPM clamps and zero audio underruns. Native test used gas assistance and disabled focus-out pausing only in its private harness.

## Measured performance

Each main setup holds engine, chassis, tires, final drive (3.20), stages, road, initial conditions and assisted driver constant across gearboxes. Gearbox weight, ratios, efficiency, control type, converter and shift behavior vary as installed hardware. All boxes use Pro Race internals for comparison; buying a new gearbox in the game starts it at Stock.

Street: Kaze engine/chassis, other stages zero. Drag: explicitly synthetic RWD test fixture, base torque 540 Nm, mass 1,350 kg, base grip 1.05, I6 engine and tier-three engine/turbo/tires/weight/exhaust/brakes. Both use the same final-drive kit and radiator. No nitrous. Two seconds of physical staging with a feedback pedal targeting 3,900 RPM; no forced RPM assignment. Times start when the independent bench releases staging, excluding staging/reaction time.

| Gearbox | Gears | Street ET / mph | Drag ET / mph |
| --- | ---: | ---: | ---: |
| legacy6 | 6 | 13.844 / 111.7 | 7.950 / 196.5 |
| manual3 | 3 | 14.107 / 109.2 | 9.240 / 160.5 |
| manual4 | 4 | 14.711 / 112.0 | 8.634 / 171.9 |
| manual5 | 5 | 14.042 / 111.3 | 8.413 / 183.4 |
| manual6 | 6 | 14.521 / 111.2 | 8.225 / 190.4 |
| auto3 | 3 | 14.891 / 107.4 | 8.290 / 174.2 |
| auto4 | 4 | 14.871 / 107.5 | 8.109 / 191.7 |
| seq5 | 5 | 14.163 / 114.3 | 8.194 / 171.5 |
| seq6 | 6 | 13.940 / 114.7 | 8.108 / 175.0 |
| seq7 | 7 | 13.636 / 114.4 | 8.065 / 180.3 |
| dct6 | 6 | 13.225 / 113.1 | 8.118 / 186.7 |
| dct7 | 7 | 12.696 / 114.2 | 7.863 / 200.0 |
| dct8 | 8 | 12.646 / 115.3 | 7.849 / 200.7 |
| auto6 | 6 | 13.211 / 111.9 | 7.976 / 197.0 |
| auto7 | 7 | 13.027 / 112.1 | 7.985 / 196.0 |
| auto8 | 8 | 12.737 / 114.0 | 7.888 / 198.4 |
| auto9 | 9 | 12.725 / 113.3 | 7.903 / 198.2 |
| auto10 | 10 | 12.765 / 114.6 | 7.888 / 198.4 |
| drag2 | 2 | 13.414 / 109.6 | 8.027 / 171.6 |
| drag3 | 3 | 13.095 / 113.0 | 8.030 / 171.5 |
| drag4 | 4 | 13.028 / 112.3 | 7.895 / 197.9 |

Examples where the 3-speed wins in the separate paired sweep:

- Built fixture, final drive 2.73, factory converters: 3D **9.364 s**, 10A **9.428 s**.
- Built fixture, final drive 3.00, factory converters: 3D **9.303 s**, 10A **9.348 s**.

The paired built fixture uses the Kaze base engine, all tier-three stages, base grip 0.9 and Pro Race gearbox internals. Each pair has identical final drive and radiator. Factory converters retain their transmission-specific stall characteristics; fitted converter comparisons use the same purchased kit and stall setting. Tall gearing avoids unnecessarily running the drag box against its direct-drive speed limit. Shorter gearing can reverse the result.

`transmission_summary.csv` includes 0–60/100, eighth/quarter, trap, shift count/time, wheelspin duration, engine range and temperatures. Trap here is interpolated line-crossing speed, not a separate 66-foot averaging zone. Full JSON retains per-shift timing and settled RPM, and the 42 optimized runs export 20 Hz telemetry CSVs. A null 0–100 means the vehicle did not reach that speed within 40 simulated seconds; it is not zero seconds. Shift interruption equivalent is duration weighted by the nominal torque cut, a comparison proxy rather than a measured causal elapsed-time penalty. It must not be read as the exact time recovered by an instantaneous gearbox.

## Changes and faults corrected

- Removed the old forward-gear count ceiling. Every gearbox has its own ratio set, mass, efficiency, torque rating, shift minimum and torque interruption behavior; no gear-count power multiplier.
- Kept stage progression separate from purchased assemblies. Internals stages and gearbox-specific clutch/controller/converter/ratio fitments remain owned per car and per gearbox; swapping assemblies does not transfer paid internal upgrades for free. New boxes start Stock. Reinstalling owned fitments costs nothing.
- Added a finite pump/turbine converter with stall multiplication, passive fluid impulses, slip heating and finite lockup. Corrected stale-load lockup lag, which could destabilize RPM; the locked converter shares inertia with the existing coupled solver. Brakes can hold converter creep. Optional transbrake locks output only in first near stationary.
- Replaced static-only shift scheduling with engine/gear/traction/converter calculations plus bounded full-physics candidate runs. The static approximation initially lost up to 0.23 s on some street automatics. The validated maps remove that deficit. Cache keys include vehicle, relevant stages, installed parts and tuning. Individual overrides require a purchased race controller.
- H-pattern shifting needs clutch + gear selection and retains throttle/rev-match responsibility; powered sequential/paddle conversions include an actuator. ECU-equipped H manuals allow ignition-cut flat shifting. Existing paddle queue/cancel protections remain intact. Automatic controller input cannot accidentally request a manual shift.
- Applied part effects to inertia, torque curve/flow, rotating/curb mass, fuel/torque support, boost response, rev limits, clutch capacity, final drive, tire radius/grip/inertia, weight transfer, cooling and progressive nitrous delivery. Supercharger conversions replace the turbo assembly; earlier turbo stages remain owned. Repeat configuration resets modifiers before applying parts, preventing stacked gains.
- Added thermal derating and race-local overload/heat wear; cooling changes actual temperatures. No permanent part destruction or new repair charge. RPM/tuning arrays reject nonfinite values and incompatible parts remain uninstalled. Rejected purchases do not deduct credits.
- Original synthesis now follows partial automatic/DCT combustion cuts, actual progressive nitrous flow and belt-driven supercharger tone. A supercharger does not arm the turbo blow-off effect. HUD/audio/telemetry read the same engine and drivetrain state.

## UI and controls

Basic View keeps the eight existing categories, installed stage, next purchase, affordability and a physical before/after comparison. Gearbox stages extend Stock → Stage 1 → Stage 2 → Stage 3 → Race → Pro Race; other legacy categories keep their three tiers.

Advanced tabs expose paged gearboxes and mechanical parts, part comparisons, two compact tuning pages, Street/Drag/Safe presets and an independent vehicle test. No endless parts list. Controller mode comes from installed hardware rather than a settings switch. Locked adjustments identify the required kit. Large landscape touch targets and multitouch input are retained; real-phone ergonomics remain unverified.

W gas, S brake, Q/E paddles or sequential selector, Shift manual clutch, Space nitrous, B compatible transbrake. H manuals use Shift + 1–6 or matching on-screen gates, N/0 neutral. Automatic/DCT hardware operates its own clutch; factory automatics shift themselves. Paid paddle controllers allow manual paddle operation on compatible assemblies. Mouse buttons and touch pointers release independently; pause/focus loss clears held inputs.

## Sources, approximations and remaining limits

Gear-ratio references are manufacturer publications: [Ford 10R80](https://www.fordservicecontent.com/Ford_Content/vdirsnet/OwnerManual/Home/Content?ProcUid=G1928612&Uid=G1928611&buildtype=web&countryCode=USA&div=f&languageCode=en&vFilteringEnabled=False&variantid=9584), [TCI transmission ratios](https://www.tciauto.com/gear-ratios), and [TREMEC TKX/Magnum ratios](https://tremec-blog.com/tremec-aftermarket-manual-transmission-gear-ratios/). The catalog uses Ford's listed 10R80 ratios; the drag 2D / 3D / 4D use TCI-listed 1.80/1.00, 2.10/1.40/1.00 and 2.48/1.48/1.00/0.75 sets. Other sets are original plausible configurations, not claims of specific donor fitment.

All prices, masses, efficiencies, shift timings, torque ratings, durability coefficients and conversion fitments are documented game estimates. ALL catalog fitments mean a platform-specific supplied package, not that one physical gearbox bolts into every car. Longitudinal automatic/drag packages are blocked for the FWD Nori. AWD packages assume an included suitable transfer interface. Supercharger and clutch installations assume matched supporting hardware. No original-game formulas or protected recordings are used.

The Strip footage does not identify these gearbox specifications, converter maps, durability or installed vehicle parts. Existing frozen footage calibration still passes; it remains a fitted reference fixture with estimated driver inputs, not independent verification of these new transmissions. Converter behavior is a lumped passive model, not an OEM fluid/valve-body or planetary model. No detailed clutch temperature distribution, fuel economy, detonation model, dyno-certified fitment, or permanent wear economy is claimed. Automatic schedules target this level quarter-mile benchmark; different tracks, nitrous use, throttle modulation or launch technique may favor custom points. Four bounded candidates do not establish a global optimum.

Actual Android/iOS touch ergonomics, low-end device performance, speaker latency and subjective driving/audio similarity still require human/device playtesting. The Windows/native and synthetic touch checks establish functional input routing, not those subjective or device-specific properties.

## Reproduction

Run `tools/validate_racing.ps1` with Godot 4.6 and Python 3. It isolates saves/caches, imports the existing project, runs the old and new headless/graphical suites, reproduces all 204 benchmark runs, checks reference/audio regressions and rebuilds this report. `tests/benchmark_transmissions.gd`, `tests/benchmark_drag_tuning.gd` and `scripts/vehicle_bench.gd` are reusable without the UI. Opening TEST BUILD never spends credits or updates race records.
