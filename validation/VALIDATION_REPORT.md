# Racing validation — 2026-11-01

This is the previous physics-validation baseline. See `POLISH_REPORT.md` for the current driving/audio polish, updated dealer-car benchmarks, and rerun results. Original pre-polish snapshots are retained under `pre_polish/`.

The existing Godot game now uses a coupled engine/clutch/wheel/chassis simulation. Garage, dealership, race selection, progression, saved builds, and paddle controls are preserved. The available footage supports a close calibration of one recorded run, not a claim to reproduce the original game's proprietary model.

## Findings and corrections

| Audit finding | Correction |
| --- | --- |
| RPM was moved toward a prescribed target; engine inertia/load did not determine it | Torque/inertia integration and coupled finite clutch impulses |
| Wheelspin was an indicator without a separate driven-wheel state | Driven-wheel angular velocity, bounded tire force, measurable slip |
| Neutral was not a valid drivetrain state and could move the car | Gear zero disconnects drive; sequential paddles select neutral |
| Clutch engagement, ratio RPM, and acceleration could diverge | Shared coupled solver, finite launch clutch and manual disengagement |
| Shifts used scripted RPM behavior | Fuel interruption, bounded paddle rev matching, finite clutch re-engagement and over-rev protection |
| Throttle lift/engine braking were incomplete | Engine pumping/friction losses transmit through the engaged clutch |
| Physics and garage engine updates used different timing paths | Shared 240 Hz fixed solver; gameplay physics at 120 Hz |
| Audio used a longer queue and lacked several drivetrain signals | Continuous original DSP driven by actual RPM/load/clutch/cut/boost/slip/nitrous; queue reduced to 55 ms |
| Smoothed throttle could never trigger boost-release sound | Hysteresis arms under boost and fires on gradual throttle closure |
| Cancelled touch could leave a pedal held | Cancellation releases the corresponding pointer only |
| Bots could roll before their reaction delay or shift from launch spin alone | Actual clutch hold during reaction, feedback staging pedal, road-RPM shift guard; same logic for instant finish calculation |
| Time-slip labels could imply reaction-excluded drag ET | Existing saved timing remains green-to-finish; labels now explicitly say TOTAL / GREEN and 60 FT / GREEN |

## Measured reference comparison

`LCXM2683.MP4` time slip: reaction **0.908 s**, quarter ET **18.415 s**, total **19.323 s**, trap **75 mph**. The later 83 mph HUD is rollout while the opponent finishes, not trap speed. The independent screenshot showing 18.091 s at 80 mph is a different run and is not combined with these measurements.

The table compares identical fitted hardware/input conditions in the archived and corrected models. This is calibration on the supplied run, not a held-out validation run. The fitted car is a separate approximate 1.5L FWD fixture; the stock Kaze remains its existing 2.0L turbo car.

| Measure | Reference | Previous model | Corrected model |
| --- | ---: | ---: | ---: |
| 60 ft ET | 3.028 s | 3.249 s | 3.057 s |
| Eighth-mile ET | 11.839 s | 11.616 s | 11.881 s |
| Quarter-mile ET | 18.415 s | 17.926 s | 18.444 s |
| Quarter speed | 75 mph | 77.87 mph | 74.92 mph |
| Pre-finish sampled speed RMS error | — | 3.19 mph | 0.83 mph |
| Loaded gear 2/3 RPM RMS error | — | 285 RPM | 103 RPM |
| Launch RPM RMS / maximum error | — | 618 / 991 RPM | 458 / 593 RPM |

Raw observations, before/after 20 Hz CSVs, full sample errors, original model snapshots, fitted parameters, and sweep history are included. HUD speed is quantized to integer mph and RPM to tens; the reading uncertainty is approximately 0.5 mph, 10 RPM and 0.02 s. Aggregate loaded-RPM scoring excludes the visibly decoupled sample at clock 15.517 s. Post-finish rollout samples are retained but excluded from aggregate scores.

`reference_shift_observations.json` preserves the dense shift readings. `acceleration_comparison.json` compares interval-average acceleration derived from successive 1 s HUD samples: corrected RMS error **0.448 m/s²**, including launches, shifts, and coasting. Speed quantization alone allows about ±0.447 m/s² error in an individual interval, with additional timestamp uncertainty. These are average accelerations, not measured instantaneous tire forces.

## Verification performed

- **19,501 physics assertions:** neutral revving, throttle/inertia response, clutch opening/re-engagement, all six gear relationships, every adjacent up/downshift, torque interruption, downshift protection, gear torque multiplication, wheelspin/friction limits, stable idle/limiter, engine braking, service braking, boost decay, nitrous, quarter-mile distance/time, upgrade gains, invalid-input rejection, and seeded stock/max-upgrade stress runs on all four cars. No safety clamps were needed.
- **Frame timing:** identical timestamped controls at 30/60/120/144 caller FPS produced zero measured distance difference and matching RPM. Live graphical playback recorded zero steady-state audio underruns in the 3 s samples at each of those four render caps, after a 1 s warmup. Startup/prior underruns are retained separately in the runtime JSON; this does not prove every machine is underrun-free.
- **Parameters/upgrades:** mass, tire radius, final drive and aerodynamic drag affect results. All eight upgrade categories affect their intended physical values or measured performance. Stock Kaze quarter: **13.342 s at 109.68 mph**; all upgrades: **10.025 s at 151.53 mph** under the same automated paddle strategy. These are game balance results, not reference-car claims.
- **Inputs/integration:** W/S/Q/E/Shift/Space, key-repeat suppression, mouse holds/releases outside controls, simultaneous mouse buttons, multi-finger gas/clutch/paddle, cancellation, pause/focus clearing, F3, clickable menus, real race completion, payouts, upgrades and save/load are exercised. Touch events are injected in Windows; an actual mobile device was not tested.
- **Bots:** all 15 contracts stage within the tested RPM band, remain stationary through their reaction delay, and finish through the same drivetrain without safety clamps.
- **Original audio:** deterministic output across buffer chunk sizes, telemetry alignment, finite/unclipped PCM, gradual boost-release and real shift transients, pause fade, and pitch tracking. Maximum evolving-physics pitch error was **82 RPM**; peak sample amplitude **0.624**, maximum adjacent sample change **0.273**. A deliberate instantaneous fixture jump produces a separate 510 RPM transient and is not counted as evolving-physics error. Independent WAV analysis verifies four-cylinder **100 Hz** and six-cylinder **150 Hz** firing frequency at 3000 RPM. No reference audio is shipped or reused.

Run `tools/validate_racing.ps1` with Godot 4.6 and Python. It runs imports, physics, parameters, audio, economy, frozen calibration, vehicle telemetry, graphical controls/menus/race flow and live playback, then enforces explicit regression thresholds. Results are in `suite_results.json`, individual test logs/JSONs, and `analysis_results.json`. `-HeadlessOnly` omits graphical integration checks and is labeled as such. F3 in a race enables the optional drivetrain overlay.

The packaged project was also extracted into a fresh folder without `.godot` caches: import, main-scene startup, physics assertions, and graphical controls passed again (`delivery_verification.json`).

## Remaining discrepancies and uncertainty

- Quarter ET is **0.029 s slow** and trap speed **0.076 mph low** in the fitted replay. Largest pre-finish speed sample error is **1.78 mph**, near the estimated coasting interruption. Launch RPM still differs by up to **593 RPM**; this is larger than display uncertainty and remains an identifiable gap.
- Reference manual shifts take roughly 0.4–0.7 s to finish their RPM undershoot/recovery. Automatic paddles deliberately use 160 ms stock torque interruption plus physical re-engagement, with gearbox upgrades reducing interruption to 55 ms. Paddle shifts need not duplicate the human's clutch overshoot. The exact hidden clutch position is unknown.
- Mass, torque curve, tire radius, gearing beyond observed coupled ratios, grip, inertia, drag, launch pedal levels, and the later clutch interruption are fitted/assumed. The profile and replay explicitly expose these choices. Matching this recording is not independent proof of the same behavior under unknown builds or inputs.
- Live race totals, split times and existing records retain the game's green-to-finish time basis, including driver reaction; the time slip now labels this explicitly. The comparison table subtracts the reference's measured 0.908 s reaction to compare reaction-excluded ET. Exact reference staging-beam rollout geometry is unknown and is not modeled.
- `JLTI6246.MP4` starts partway through a short run and its decoded audio is silent. It supports idle/gear/RPM observations, but not a complete launch/quarter calibration or audio match. `LCXM2683.MP4` includes mixed game audio/music, limiting isolated engine-timbre comparison. Original synthetic audio is synchronized but is still a prototype timbre; speaker latency and subjective sound fidelity remain unverified.
- No controlled reference braking, coast-down, neutral-rev, downshift, redline, nitrous, upgrade A/B or frame-rate experiment was supplied. Those systems are mechanically tested here; their exact equivalence to The Strip cannot be established from the available clips. The model's launch assistance, effective tire friction, turbo spool and paddle rev matcher are documented approximations; see `PHYSICS_MODEL.md`.
