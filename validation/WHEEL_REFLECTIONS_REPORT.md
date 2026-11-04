> Historical report: superseded by the rotating-wheel restoration. Runtime no longer draws rim-reflection arcs or uses integrated race bodies. See WHEEL_ROTATION_REPORT.md.

# Integrated wheel artwork and rim reflections

## Reference observations

Inspected LCXM2683.MP4 directly using timestamped extraction at 2, 4, 8.20–8.44 (40 ms spacing), 15 and 23 seconds. The cropped sequence is under `validation/wheel_reference/wheel_sequence.png`. Early and later race frames retain recognizable wheel faces with small changing silver/white rim reflections. These small recorded wheels and video compression do not establish the original game's rendering technique. Burnout/braking lighting behavior could not be isolated confidently from this sampled reference; those cases were validated against REDLINE's simulation instead.

## Implementation

- The asset pipeline now writes integrated `race_body_*` variants with the original authored wheels retained in the vehicle image. No new replacement wheel sprites are drawn in that race path. Existing body variants, independent stock-wheel assets, menu/customization renderer and saves remain intact.
- Race rendering overlays only narrow white-silver reflection arcs. No replacement tire, hub, spokes or brake disc is drawn. Soft shoulders, a faint secondary reflection and an optional short shutter trail are bounded inside each configured rim.
- Driven-wheel phase comes directly from accumulated `wheel_angle` and actual `wheel_omega`. The non-driven axle now has an accumulated rolling phase integrated in physics substeps, avoiding phase jumps when tire radius changes. No timer-based visual rotation or speed multiplier is used.
- RWD/FWD/AWD select the correct driven axle using existing vehicle data. The current solver has one equivalent driven-axle angular speed, so left/right or front/rear AWD differential speed differences are not individually simulated.
- All 30 models define integrated race textures, wheel anchors and rim radii. Reflections follow the artwork's rim dimensions, not an enlarged tire mask that would leak onto bodywork. Tire upgrades still change real tire radius/grip and wheel speed; the authored race artwork retains its original tire silhouette.
- Aftermarket wheel design/color/caliper/sidewall selections remain owned, saved and visible in the existing garage/customization presentation. Races deliberately show each car's authored wheel design instead of substituting the generic custom-wheel graphics. Wheel design modestly varies reflection strength; it does not draw different spokes.
- At rest reflection strength is zero. Darkness reduces strength. Low quality omits shoulders, secondary highlights and shutter trails. No fullscreen shader, material per vehicle, particles or blur pass was added.

## Verification

- `test_rim_reflections`: 200 checks covering all 30 configurations, integrated wheel centers, asset validity, rim bounds, stationary states, signed phase handling, quality, night intensity, 30/60/120/144 Hz consistency, tire-radius phase continuity, shifts and stationary-road burnout separation.
- `test_rim_rendering`: native Godot pixel comparisons on Miata, GTI VR6, GT-R, Demon and SF90. Altering phase at zero speed leaves the image identical; moving highlights alter pixels only inside the rim annuli. Different saved procedural wheel choices do not draw duplicate wheels over race art. Rendering leaves simulation telemetry unchanged.
- Passed existing physics, wheel-effects/burnout/braking, customization, roster model, visual rendering, roster UI/mobile navigation and keyboard-driven first-race tests.
- Native screenshots: `validation/rim_motion/`; actual race screenshot: `.qa/effects_burnout_high.png`. Short 60 Hz physics-stepped burnout clip: `validation/rim_motion/burnout_reflections.mp4`.

Reverse driving is not supported by the current racing physics. The reflection helper preserves signed phase and speed magnitude, but no end-to-end reverse-drive claim is made. Exact reference shader behavior, subjective shimmer at very high RPM, and low-end physical-phone GPU performance require further human/device review.

Final runtime checks also passed: keyboard/mouse/multitouch controls and live audio/physics at 30, 60, 120 and 144 FPS caps. No steady-state audio underruns or physics safety clamps were recorded in those runtime samples (one startup/prior underrun was excluded by the existing warmup protocol). These desktop caps do not establish iPhone performance.

