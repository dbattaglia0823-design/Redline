# REDLINE racing physics audit

Measured with Godot 4.6.3, using the existing `Drivetrain` at 240 Hz. The
`before.json` snapshot was captured before the physics changes; `after.json`
uses the same 18 vehicle/build fixtures. Full configurations, sampled RPM/speed/
traction/load/boost curves, individual shift RPM and duration, and diagnostics
are in those JSON files. `measurements.csv` contains both phases.

## Method and timing

- Standing start after two seconds of staging; no reaction delay is added.
- 0–60 and 60–130 are interpolated speed crossings from rest. This is **not**
  a separate stabilized rolling-start 60–130 pull.
- Eighth- and quarter-mile times in the tables start at the launch command and
  include clutch take-up and initial rollout. Speeds are instantaneous speeds at the distance
  marker, matching REDLINE's current timing system, rather than a real drag
  strip's final speed-trap interval average.
- JSON also retains the existing beam-release ET (`quarter_et_s`,
  `eighth_et_s`) and reaction/rollout measurements separately.
- Runs continue until both the quarter and 130 mph, or 40 simulated seconds.
  `unreached` means the speed was not reached in that window; it is not zero
  or a claimed top-speed result.
- Wheelspin in the table counts samples over 10% slip up to the quarter,
  at 0.05-second sampling resolution. Other whole-run diagnostics can extend
  beyond the quarter. Shift events record their own RPM and commanded delay.
- The benchmark driver uses full throttle, the existing launch-clutch helper,
  configured shift maps, and nitrous when a kit is installed. It is repeatable,
  not a claim about every player's driving. Each built fixture specifies its
  actual parts/tune in JSON; it is not a new player build preset.
- No engine ratings, vehicle mass, tire coefficients, class assignments, costs,
  or aerodynamic coefficients were changed to reach a target elapsed time.

## Acceleration, before → after

Times are seconds. The vehicle label includes build level or transmission.

| Vehicle / configuration | Drive | 0–60 | 60–130 | Quarter | Quarter change |
| --- | --- | ---: | ---: | ---: | ---: |
| miata / stock | RWD | 7.857 → 7.857 | unreached → unreached | 16.059 → 16.059 | +0.000 |
| civic_si / stock | FWD | 7.476 → 7.476 | unreached → unreached | 15.913 → 15.913 | +0.000 |
| gti / stock | FWD | 5.719 → 5.727 | 24.938 → 25.187 | 14.448 → 14.455 | +0.008 |
| mustang / stock | RWD | 3.389 → 3.392 | 9.175 → 9.175 | 11.546 → 11.547 | +0.001 |
| gtr / stock | AWD | 2.805 → 2.809 | 7.443 → 7.444 | 10.741 → 10.743 | +0.003 |
| gt500 / stock | RWD | 2.720 → 2.720 | 6.064 → 6.064 | 10.339 → 10.339 | +0.000 |
| demon / stock | RWD | 1.992 → 1.990 | 4.679 → 4.678 | 9.274 → 9.272 | -0.001 |
| sf90 / stock | AWD | 2.422 → 2.422 | 4.055 → 4.056 | 9.385 → 9.386 | +0.001 |
| chiron / stock | AWD | 2.421 → 2.421 | 3.356 → 3.380 | 9.065 → 9.076 | +0.012 |
| civic_si / built | FWD | 2.620 → 2.595 | 5.077 → 5.089 | 9.989 → 9.979 | -0.010 |
| mustang / built | RWD | 1.240 → 1.269 | 1.917 → 1.933 | 7.091 → 7.129 | +0.038 |
| gtr / built | AWD | 1.263 → 1.248 | 1.732 → 1.734 | 6.958 → 6.951 | -0.008 |
| mustang / manual6 | RWD | 3.016 → 3.016 | 7.591 → 7.591 | 10.999 → 10.999 | +0.000 |
| mustang / seq7 | RWD | 3.080 → 3.080 | 6.960 → 6.960 | 10.869 → 10.869 | +0.000 |
| mustang / dct8 | RWD | 3.014 → 3.014 | 6.993 → 6.993 | 10.813 → 10.813 | +0.000 |
| mustang / auto10 | RWD | 3.017 → 3.017 | 7.257 → 7.258 | 10.900 → 10.900 | -0.000 |
| mustang / drag2 | RWD | 3.331 → 3.544 | 7.702 → 7.722 | 11.161 → 11.313 | +0.152 |
| mustang / drag4 | RWD | 3.090 → 3.188 | 7.440 → 7.417 | 10.951 → 11.014 | +0.063 |

## Distance splits and traction, before → after

Each split is seconds / mph. Wheelspin is seconds through the quarter.

| Vehicle / configuration | Eighth | Quarter | Wheelspin |
| --- | ---: | ---: | ---: |
| miata / stock | 10.413 / 70.6 → 10.413 / 70.6 | 16.059 / 87.1 → 16.059 / 87.1 | 0.00 → 0.00 |
| civic_si / stock | 10.413 / 71.8 → 10.413 / 71.8 | 15.913 / 89.6 → 15.913 / 89.6 | 0.15 → 0.15 |
| gti / stock | 9.373 / 79.1 → 9.379 / 79.1 | 14.448 / 97.9 → 14.455 / 97.8 | 1.95 → 1.90 |
| mustang / stock | 7.561 / 99.8 → 7.562 / 99.7 | 11.546 / 124.7 → 11.547 / 124.7 | 1.95 → 1.95 |
| gtr / stock | 7.005 / 106.2 → 7.007 / 106.2 | 10.741 / 132.9 → 10.743 / 132.9 | 1.25 → 1.15 |
| gt500 / stock | 6.829 / 113.3 → 6.829 / 113.3 | 10.339 / 141.9 → 10.339 / 141.9 | 2.15 → 2.15 |
| demon / stock | 6.049 / 122.9 → 6.048 / 122.9 | 9.274 / 153.8 → 9.272 / 153.8 | 1.00 → 1.00 |
| sf90 / stock | 6.275 / 127.5 → 6.275 / 127.5 | 9.385 / 159.9 → 9.386 / 159.9 | 2.70 → 2.70 |
| chiron / stock | 6.142 / 135.4 → 6.146 / 135.0 | 9.065 / 169.6 → 9.076 / 169.1 | 3.40 → 3.40 |
| civic_si / built | 6.698 / 119.4 → 6.689 / 119.5 | 9.989 / 151.7 → 9.979 / 151.7 | 0.10 → 0.05 |
| mustang / built | 4.663 / 165.3 → 4.697 / 164.9 | 7.091 / 202.5 → 7.129 / 202.2 | 1.45 → 1.20 |
| gtr / built | 4.605 / 170.5 → 4.594 / 170.2 | 6.958 / 207.7 → 6.951 / 207.8 | 0.80 → 0.80 |
| mustang / manual6 | 7.258 / 105.6 → 7.258 / 105.6 | 10.999 / 132.3 → 10.999 / 132.3 | 2.60 → 2.60 |
| mustang / seq7 | 7.190 / 108.3 → 7.190 / 108.3 | 10.869 / 134.9 → 10.869 / 134.9 | 2.75 → 2.75 |
| mustang / dct8 | 7.142 / 108.5 → 7.142 / 108.5 | 10.813 / 135.2 → 10.813 / 135.2 | 2.65 → 2.65 |
| mustang / auto10 | 7.189 / 107.3 → 7.189 / 107.3 | 10.900 / 133.8 → 10.900 / 133.8 | 2.45 → 2.45 |
| mustang / drag2 | 7.357 / 105.0 → 7.488 / 104.2 | 11.161 / 130.8 → 11.313 / 130.3 | 1.45 → 1.10 |
| mustang / drag4 | 7.224 / 106.7 → 7.283 / 106.5 | 10.951 / 132.5 → 11.014 / 132.4 | 2.30 → 1.60 |

## Shift and coupling diagnostics after the changes

These diagnostics cover the entire run, which can continue beyond the quarter.
Short coupling saturation during launch/re-engagement is distinct from
sustained slipping. Raw per-shift events are preserved in `after.json`.

| Vehicle / configuration | Shifts | Shift RPM range | Commanded delay range | Clutch / gearbox slip seconds | Safety clamps |
| --- | ---: | ---: | ---: | ---: | ---: |
| miata / stock | 4 | 7100–7105 | 240–240 ms | 0.158 / 0.000 | 0 |
| civic_si / stock | 4 | 7900–7904 | 240–240 ms | 0.196 / 0.000 | 0 |
| gti / stock | 4 | 6700–6704 | 240–240 ms | 0.208 / 0.000 | 0 |
| mustang / stock | 5 | 7400–7430 | 160–160 ms | 0.000 / 0.033 | 0 |
| gtr / stock | 4 | 7051–7061 | 90–90 ms | 0.133 / 0.000 | 0 |
| gt500 / stock | 3 | 7450–7488 | 90–90 ms | 0.033 / 0.000 | 0 |
| demon / stock | 5 | 6400–6422 | 160–160 ms | 0.000 / 0.025 | 0 |
| sf90 / stock | 4 | 7900–7909 | 90–90 ms | 0.004 / 0.000 | 0 |
| chiron / stock | 4 | 7025–7064 | 90–90 ms | 0.000 / 0.000 | 0 |
| civic_si / built | 4 | 7902–7915 | 140–140 ms | 0.000 / 0.000 | 0 |
| mustang / built | 7 | 7401–7495 | 50–50 ms | 0.000 / 0.000 | 0 |
| gtr / built | 5 | 7051–7126 | 35–35 ms | 0.000 / 0.000 | 0 |
| mustang / manual6 | 3 | 7449–7451 | 186–186 ms | 0.000 / 0.000 | 0 |
| mustang / seq7 | 5 | 7400–7466 | 68–68 ms | 0.000 / 0.000 | 0 |
| mustang / dct8 | 4 | 7447–7453 | 53–53 ms | 0.000 / 0.000 | 0 |
| mustang / auto10 | 6 | 7401–7409 | 105–105 ms | 0.000 / 0.000 | 0 |
| mustang / drag2 | 1 | 7402–7402 | 53–53 ms | 0.000 / 0.000 | 0 |
| mustang / drag4 | 2 | 7400–7402 | 50–50 ms | 0.000 / 0.000 | 0 |

## Audit findings and changes

| System | Finding and disposition |
| --- | --- |
| Torque / horsepower | Existing vehicle-specific torque tables already reproduce rated ICE output; retained. HP is derived from torque × angular velocity, rather than an acceleration multiplier. Hybrid system HP remains separate. |
| Idle / redline / inertia | Retained the existing idle governor, hysteretic fuel-cut limiter, engine inertia and fixed solver. Regression checks cover stable idle, finite RPM, mechanical downshift protection and frame-rate equivalence. No assigned RPM drop was introduced. |
| Throttle / engine load | Retained response lag and load telemetry. Turbo pressure now responds to load; unloaded free revving produces limited pressure, with a separate launch-control allowance. Full-load rating and boost tuning envelopes remain unchanged. Roots and centrifugal behavior remains mechanically distinct. |
| Clutch / input capacity | Removed engine torque clipping at gearbox input rating. The finite clutch/pack impulse now limits transmitted torque while the engine can flare under overload. Existing overload/wear and warnings remain. Updated the old feedback test to check transmitted coupling torque rather than crankshaft torque. |
| Road automatic | Fixed missing light-throttle upshifts. Shift targets interpolate with throttle; kickdown compares useful lower-gear torque and keeps hysteresis below the upshift boundary. Full-load schedules still use the engine's performance curve. |
| Converter | Default capacity is sized from installed full-load torque at stall, including induction and engine upgrades. The old unboosted base-torque sizing could overload the converter and send stronger builds toward the limiter. Passive fluid-energy bounds and finite lockup capacity remain. Normal fluid slip is distinct from internal pack overload. |
| Manual / sequential / DCT / drag | Retained existing controls and type/upgrade shift delays, 2–10 gears, manual clutch checks, paddle queue, rev matching, DCT retention and drag multiplication. Drag automatics retain full-load schedules even at partial throttle. |
| Ratios / efficiency | Retained actual OEM ratios, per-type gear count and tuning, final drive, tire radius and efficiency. Tests verify gear selection cannot directly change speed/RPM, and wheel torque is limited through the coupled solver. |
| Shift planner duplication | Quasi-static force integrals remain a search heuristic, validated with the actual solver. They now respect clutch capacity and the current launch-grip envelope. Trial launches now use the same vehicle-specific launch RPM, clutch helper and installed nitrous as the benchmark driver, rather than a fixed 3900-RPM launch with a different clutch procedure and no spray. |
| Traction / suspension | Existing calibrated FWD/RWD/AWD grip, acceleration load transfer, pressure, launch bite, hop damping, wheel inertia and traction impulse are retained. No instant speed-based grip restoration or launch acceleration multiplier was added. Regression tests cover weak tires versus slicks, suspension, pressure and recovery with upgraded power. |
| Nitrous | Retained kit-only activation, finite bottle duration, torque addition and mechanical/fuel capacity limits. No stock nitrous, bypass of tire grip, or power while disengaged is introduced. |
| Hybrid assist | Fixed final-step battery overdraw: available electrical energy is now reduced by conversion efficiency before limiting wheel power. Electric axle torque still passes through tire traction. |
| Mass / aero / brakes / distance | Retained curb mass, weight/brake upgrades, quadratic drag, rolling resistance, braking cap and trapezoidal distance integration. Tests cover energy loss when coasting and stopping without reversing. |
| Class / economy / saves / UI | Fixed engine classes and player state remain independent of elapsed time. No UI redesign, prices, rewards, ownership or save schema changes. |

The original championship regression already failed its elapsed-time class
assertion on the original solver (`class_D_4`, verified in an isolated copy).
That obsolete check now validates the authored event division and a finished,
finite run. Player engine-class entry checks remain. All adjacent rivals must
still become faster in normalized quarter-mile and same-distance comparisons;
the former arbitrary 35 ms minimum gap was replaced with strict ordering above
1 ms numerical tolerance. The corrected solver produces gaps of 16 ms and
27 ms for two pairs. Boss difficulty-step and legal-player beatability checks
remain intact. No rival contracts or driver attributes were adjusted to fit
old target times.

## Physical model limits

This remains REDLINE's existing one-dimensional game simulation. Grip values
are calibrated whole-vehicle effective coefficients, not measured per-tire
friction curves. Axle transfer and hybrid torque allocation are lumped models;
there is no lateral/combined-slip tire solver, detailed differential, tire
temperature model, or full hydrodynamic converter map. Shift-retention factors,
thermal protection, and anti-stall clutch assistance remain game estimates.
The benchmark covers factory, tuned and extreme builds, but does not certify
manufacturer acceleration figures or every possible saved tune.

## Reproduce

Use Godot 4.6.3 and isolated save directories as provided by the runner:

```
python tools/run_regressions.py --godot C:/Godot/godot.exe --output .qa/physics-audit/regressions
python tools/report_physics_audit.py
```

The headless runner includes the focused audit and all 18 after measurements.
The immutable before snapshot should not be regenerated from the new solver.
For just the measured after runs, use `--headless --path . --script
tests/benchmark_physics_audit.gd`. The existing factory benchmark generator is
`tests/benchmark_roster.gd`.

## Verification evidence

`regressions.json` records the latest passing results from 18 headless suites,
the Godot import, and two graphical suites. The focused audit checks 4,628
conditions, including 30/60/144 Hz input replay, every supported gear count,
traction impulse bounds, passive coast energy, converter stall behavior,
overload, load-sensitive boost, launch control and depleted hybrid energy.
The existing tests also cover rated output across all 30 cars, the full
60-race economy route, transmission purchasing/tuning/save round trips,
nitrous, traction upgrades, max-power gearbox support and race controls.
The new frame-rate test required a float annotation fix; its successful
targeted rerun is recorded alongside the original batch results.

The retained drag calculation follows [NASA's drag equation](https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/drag-equation/):
force is proportional to density, drag area and speed squared. The coupled
impulse solver and passivity tests, rather than time targets, determine the
resulting acceleration.
