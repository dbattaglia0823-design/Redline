# Racing environment overhaul

The three existing tracks now use distinct original panorama artwork rather than the shared geometric skyline and small bleacher tile. Dockside has sunlit port cranes, tanks, warehouses and containers; Midnight has illuminated grandstands, cyan floodlights, violet architectural lighting and a city skyline; Redline Park has golden-hour light, white cantilever roofs, glass VIP suites and a landscaped professional paddock. Redline Park is now a daylight venue; career contracts and track indices are unchanged.

## Screenshot review

These are in-game Godot renders, not concept-art mockups. Matched fixtures hold the simulation at staging (0 m), acceleration (24 m / 31 mph), and high speed (280 m / 107 mph). They demonstrate presentation and HUD clearance, not measured acceleration or elapsed times; the displayed zero clock is intentional. The separate existing strip regression exercises live driving, staging, fouls and settlement.

| Location | Staging | Acceleration | High speed |
| --- | --- | --- | --- |
| Dockside Dragway | [View](track_environments/dockside_staging.png) | [View](track_environments/dockside_acceleration.png) | [View](track_environments/dockside_high_speed.png) |
| Midnight Motorplex | [View](track_environments/midnight_staging.png) | [View](track_environments/midnight_acceleration.png) | [View](track_environments/midnight_high_speed.png) |
| Redline Park | [View](track_environments/redline_staging.png) | [View](track_environments/redline_acceleration.png) | [View](track_environments/redline_high_speed.png) |

Each location also has `_finish`, `_low`, and `_portrait` captures in [track_environments](track_environments/): 18 images total. Portrait captures use a 390 × 844 window. The fixture checks that rendering preserves drivetrain telemetry, pausing freezes presentation distance, Reduced Motion clears camera shake, and every screenshot saves successfully.

Visual review caught missing mirrored panorama tiles and split light fixtures in an early layered-sky experiment. The final rendering mirrors with an explicit canvas transform and keeps each facility/sky image intact, eliminating gaps and detached structures. Facility artwork, near walls, racing surface and drainage apron scroll at separate depth rates. The tree and timing lines remain anchored to the actual start and finish distances.

## Surface, lighting and effects

The racing surface has authored aggregate, repaired seams, laid-rubber grooves, restrained lane-edge paint and a close drainage apron. Each location has its own weathered safety-wall finish and accent color. The staging area includes lane numbers and track signage. The Christmas tree retains its existing beam/countdown/foul logic, with metal framing, recessed lenses, highlights and soft active-lamp bloom. Finish chequers and the actual timing board remain visible at the end of the strip.

Soft shared texture sprites replace hard smoke circles and per-frame shadow polygons. Low quality retains contact shadows; medium/high add restrained ground-light pools and exhaust haze. Night vehicles receive cool light with subtle variation under light banks; Redline Park uses a warm tint. Existing finite wheelspin-driven smoke budgets remain 8 / 24 / 48 particles. Reduced Motion disables camera shake and environmental speed streaks while retaining ordinary travel scrolling and physical suspension response. HUD controls render after the environment and cars.

## Validation

Godot 4.6.3, GL Compatibility renderer, Mesa llvmpipe software OpenGL, dummy audio:

| Check | Result |
| --- | --- |
| New artwork import | Passed |
| `tests/test_track_environments.gd` | Passed; 18 captures, all locations and phases, finish, Low, portrait, immutable physics, pause and Reduced Motion |
| `tests/test_strip_rendering.gd` | Passed; staging/tree, manual start, red-light outcome, burnout, power configurations, mobile and Low effects |
| `tests/test_race_distance_camera.gd` | Passed; quarter-mile contracts and proportional rival positioning on desktop/phone |
| `tests/test_visual_effects.gd` | Passed; 313 wheel/effects/quality checks |
| `tests/test_physics.gd` | Passed; 144,353 checks, zero failures |
| `tests/test_staging.gd` | Passed; 22,084 checks |
| `tests/test_career_save_migration.gd` | Passed; 13 checks |
| `tests/test_shutdown.gd` | Passed |

The model/save checks ran against an isolated copy with refreshed scripts and separate save directories. Existing strip/camera/effects checks ran on the working project with isolated save directories. The strip test reports the existing ObjectDB-at-exit warning; no script errors or assertion failures occurred. The complete Windows validation wrapper was not run. Real phones, GPU frame times, thermal behavior and subjective device/audio presentation remain unverified.

## Asset and performance notes

The three 2172 × 724 PNG panoramas are original AI-generated environment artwork created for this change, with no third-party stock images, brands or copied track logos. Keep these committed source illustrations when changing the track. `tools/generate_track_surfaces.py` deterministically authors the asphalt, three wall SVGs and shared radial sprite; run it with Python 3 to reproduce those assets. It does not regenerate the panoramas. Godot import descriptors are included.

The track renderer holds one location panorama at a time outside the vehicle texture cache. All track surface textures combined with one uncompressed panorama use about 7.5 MiB of pixel storage; this is an estimate, not a device memory profile. Panoramas use a few canvas draws; no realtime lights, blur passes, runtime image generation or per-frame texture loads are used after a location is loaded. Quality presets bound effects; Low omits pools, exhaust haze, speed streaks and drainage slot detail. Mirrored repeats remain visible as repeating architecture during long runs; they avoid abrupt texture-edge seams without creating a large unique texture for the entire quarter mile.

To capture again, import once, then run from the repository with an available local graphical display and isolated save directory:

```sh
godot --headless --path . --editor --quit
XDG_DATA_HOME=/tmp/redline-track-review godot --path . --audio-driver Dummy --script tests/test_track_environments.gd
```

A display is required because captures wait for a rendered frame. No environment configuration or publication was changed.
