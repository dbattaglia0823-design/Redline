# Rotating wheel restoration

- Removed the lighting-only race wheel path, rim reflection arcs, and motion-trail highlights.
- Races now use the same body-with-wheel-cutouts and independently rotating authored stock-wheel textures as other vehicle views. Installed custom designs remain visible through the existing custom-wheel renderer.
- Centers and radii use each vehicle manifest's wheel anchors. Tire-size changes retain ground alignment.
- Driven wheels use simulated wheel angular speed/phase; non-driven wheels use accumulated rolling phase. Every quality preset preserves rotation. No change to traction, gearing, saves, or audio.
- Added checkpoints/.gdignore so archived scripts cannot shadow active Godot class definitions.

Validation: test_rim_rendering, test_visual_effects (313 checks), test_visual_rendering, test_customization_ui, and physical phase checks in test_rim_reflections all passed after import. Native image comparisons covered Miata, GTI VR6, GT-R, Demon, and SF90: changed pixels remained inside their wheel bounds, stationary images stayed unchanged, custom wheels remained visible, and rendering did not mutate telemetry. Inspected the captured Miata render for placement and duplicate wheels. Other vehicles' alignment is covered by bounds tests, not a full manual visual review of all 30 cars.

Captures: validation/rim_motion/*.png and 24 burnout frames. Historical WHEEL_REFLECTIONS_REPORT.md describes the superseded effect.
