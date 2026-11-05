# Vehicle motion and racing effects

Cars now use a damped sprung-body response driven by solver acceleration, vehicle mass, drivetrain and installed suspension. Acceleration lifts the nose and compresses the rear; braking reverses the transfer. Loaded shifts and traction recovery excite a small settling response. Street suspension responds more quickly; the drag package has greater transfer and a slower response. Weight changes affect response speed. The body alone moves; tire centers and the original vehicle/wheel artwork stay on the road.

The response is a bounded presentation approximation, not a new suspension-force solver. Pitch is limited to 0.006 radians (about 0.34 degrees). Existing acceleration, traction, gear ratios, performance, economy and save formats are unchanged.

## Visual review

Four classes: light RWD Miata, FWD Civic Si, AWD GT-R and heavy RWD Demon. The images are captured in the actual game renderer. Launch, low-grip brake-held burnout, braking and nitrous delivery advance the existing drivetrain solver at 120 Hz. Fast entry uses a controlled 40 m/s initial condition. The upgraded shift fixture sets a hot, loaded shift boundary deliberately so its brief backfire can be reviewed reliably. They are presentation tests, not acceleration benchmarks or race completion tests. The zero HUD clock comes from the practice staging/release state being held for capture.

| Vehicle | Launch | Burnout | Braking | Upgraded shift | Nitrous | Motion clip |
| --- | --- | --- | --- | --- | --- | --- |
| Miata | [Image](vehicle_motion/miata_launch.png) | [Image](vehicle_motion/miata_burnout.png) | [Image](vehicle_motion/miata_braking.png) | [Image](vehicle_motion/miata_upgraded_shift.png) | [Image](vehicle_motion/miata_nitrous.png) | [MP4](vehicle_motion/miata_motion.mp4) |
| Civic Si | [Image](vehicle_motion/civic_si_launch.png) | [Image](vehicle_motion/civic_si_burnout.png) | [Image](vehicle_motion/civic_si_braking.png) | [Image](vehicle_motion/civic_si_upgraded_shift.png) | [Image](vehicle_motion/civic_si_nitrous.png) | [MP4](vehicle_motion/civic_si_motion.mp4) |
| GT-R | [Image](vehicle_motion/gtr_launch.png) | [Image](vehicle_motion/gtr_burnout.png) | [Image](vehicle_motion/gtr_braking.png) | [Image](vehicle_motion/gtr_upgraded_shift.png) | [Image](vehicle_motion/gtr_nitrous.png) | [MP4](vehicle_motion/gtr_motion.mp4) |
| Demon | [Image](vehicle_motion/demon_launch.png) | [Image](vehicle_motion/demon_burnout.png) | [Image](vehicle_motion/demon_braking.png) | [Image](vehicle_motion/demon_upgraded_shift.png) | [Image](vehicle_motion/demon_nitrous.png) | [MP4](vehicle_motion/demon_motion.mp4) |

There are 32 screenshots total, including `_high_speed`, `_burnout_low` and `_portrait` for every model. [results.json](vehicle_motion/results.json) records speed, body pitch, axle travel estimates, smoke count and effect state at capture. The silent MP4 clips contain 60 rendered frames at 30 fps: continued acceleration from the launch, assisted upshifts when ready, then braking. They were encoded from fixed-step gameplay captures, not a wall-clock performance recording.

Review refinements reduced excessive smoke stacking, enlarged and softened puff expansion, and extended its drift. The automatic Demon's nitrous capture waits for actual delivery between shifts rather than assuming a fixed frame is always spraying.

## Effects and mechanical inputs

- Tire smoke originates at the manifest's actual driven-wheel coordinates: front on FWD, rear on RWD, alternating axles on AWD. Installed tire radius determines the contact height. Slip speed and wheelspin govern density; puffs expand with smooth easing, fade in and out, rise and trail behind the car. Desktop and portrait use their actual scrolling scales.
- Stock wheel images are never rotated or replaced. Actual axle phase drives short metallic highlights inside the rim; High adds two very faint speed-dependent exposure arcs. Medium reduces reflection work and Low omits these overlays. Wheelspin can animate the driven axle with the car stationary; free wheels follow road motion.
- Exhaust pulses follow RPM and cylinder count at the authored outlet. Engine/exhaust upgrades affect the plume and backfire strength. Boost adds restrained heat-haze intensity and width; active nitrous delivery gives a subtle cooler tint. Nitrous alone no longer creates a sustained flame.
- Backfires are short, cooled-down events on eligible upgraded exhaust/ECU builds, at hot loaded shifts or a high-RPM throttle lift. Stock shifts stay clean. This is an explicitly limited presentation heuristic, not an AFR or exhaust-combustion simulation.
- Hard launches, loaded shifts and real acceleration feed restrained camera movement. Existing environment streaks remain speed-dependent. Reduced Motion disables the camera shake and speed streaks; pausing freezes particles and suspension. Reset clears spring velocity, particles and exhaust events.

## Validation

Godot 4.6.3, GL Compatibility, Mesa llvmpipe software rendering, dummy audio:

| Check | Result |
| --- | --- |
| `tests/test_motion_feedback.gd` | Passed: 98 checks across four classes; launch/braking signs, settling, 30/60/120/144 Hz stability, axle smoke, quality caps, stock/upgraded shift and gradual-lift backfires, boost/nitrous, pause/reset, Reduced Motion, mass and suspension differences |
| `tests/test_motion_rendering.gd -- --record` | Passed: four classes, actual solver scenarios, 32 images and 240 source recording frames |
| `tests/test_rim_rendering.gd` | Passed across the roster: stationary art, wheel-phase changes, wheel-bound overlays, custom wheels and unchanged drivetrain telemetry |
| `tests/test_visual_effects.gd` | Passed: 313 checks |
| `tests/test_strip_rendering.gd` | Passed: staging, tree, manual start, red-light outcome, power builds, mobile and Low effects |
| `tests/test_physics.gd` | Passed: 144,353 checks |
| `tests/test_staging.gd` | Passed: 22,084 checks |
| `tests/test_career_save_migration.gd` | Passed: 13 checks |
| `tests/test_shutdown.gd` | Passed |

Model/save and full-roster rim checks used a disposable copy refreshed from the working scripts, keeping their generated reports outside the checkout. Save directories were isolated. Existing ObjectDB-at-exit warnings occurred in shutdown/strip runs without assertion or script errors. The complete Windows suite was not run.

Mobile constraints: smoke retains strict 8 / 24 / 48 caps; spring integration has small bounded substeps; existing pooled sprites are reused; there are no new screen-space blur passes or realtime lights. Low omits exhaust haze and rim overlays. Portrait and quality behavior are tested in the software renderer. Actual phone frame time, thermal cost and subjective motion/audio still require device testing; these captures do not establish a device FPS budget.

To reproduce from the repository with an available graphical display and isolated user-data directories:

```sh
godot --headless --path . --editor --quit
XDG_DATA_HOME=/tmp/redline-motion-model godot --headless --path . --script tests/test_motion_feedback.gd
XDG_DATA_HOME=/tmp/redline-motion-render godot --path . --audio-driver Dummy --script tests/test_motion_rendering.gd -- --record
```

Recording source frames are written to ignored `.qa/motion_frames`. Encode them with ffmpeg at 30 fps using each `<model>_%03d.png` sequence. Committed clips use H.264/yuv420p. No environment configuration or publication was changed.
