# Racing HUD refinement

Implemented in the existing game. RaceHUD is a shared read-only immediate-mode dashboard; gameplay actions still use main.gd and RaceControls. No drivetrain, AI, vehicle art, or engine-audio algorithms were replaced.

## Changes

1. One reusable HUD replaces duplicate desktop/portrait dashboards; its colors use GlassPalette and its cached glass styles remain bounded.
2. Desktop track visibility increases from approximately 466 to 516 logical pixels vertically. The dashboard is shallower and the top header is shorter.
3. Wide landscape windows use their full aspect ratio for the race instead of being restricted to the old 1200-wide canvas. Existing safe-area mapping remains in use.
4. A central numbered tachometer uses the existing 22 ms presentation smoothing for its needle, actual RPM for its digital readout, the engine's real redline, and limiter state.
5. Nine progressive shift lights derive their target from the installed build's per-gear shift map. Top gear and neutral suppress upshift guidance. Rejection, engagement, and queued-shift feedback use real drivetrain state.
6. Gear and speed have separate compact readouts. Tapping speed or using Pause > Units toggles MPH/KM/H. The preference saves with backward-compatible default MPH.
7. Pedals and paddles have distinct glass shapes, orange throttle/shift accents, immediate held-state feedback, analog-state fill indicators, and brief press feedback respecting reduced motion.
8. H-pattern, sequential, paddle, DCT, modern auto, and drag-auto layouts expose the existing hardware's permitted controls. The H gate retains direct gear selection; automatics omit manual shifting. Compatible transbrakes remain available.
9. Nitrous shows real remaining delivery time and actual active state; an empty supply disables its touch target. The existing base nitrous capability remains usable.
10. Compact actual pre-stage/stage indicators and hardware-specific launch hints replace the broad staging banner. Christmas-tree logic and beam timing are unchanged.
11. Pause isolates race targets and provides Units, Guide, and Effects actions. Debug telemetry controls and rendering are hidden in release builds.
12. Portrait and short landscape layouts provide approximately 44-pixel minimum race touch targets at tested sizes. Automatic/DCT layouts use the former clutch space for larger brake controls.

## Verification

Native rendered captures and automated mouse/touch events cover 1200x760, 1920x1080, 844x390, 667x375, and 390x844, across eight installed gearbox configurations. HUD tests check target bounds/overlap/size, simultaneous pedals, H-gate and paddle input, hardware visibility, nitrous disablement, unit conversion and persistence, pause isolation, shift-map readings, neutral/reverse display fallbacks, and rendering isolation from physics. Reverse label support does not add reverse driving to the solver.

Before/after captures and transmission-specific screenshots are in validation/race_hud/. Visual review caught and corrected clutch/H-gate overlap and clutch/gauge overlap on narrow landscape screens.

The targeted controls, staging, transmission, physics, race-camera, rendered track, race/save/reward flow, and visual tests passed. Live audio/physics tests passed at 30/60/120/144 FPS caps with aligned audio telemetry and no steady underruns. All 46 registered suite checks and all four post-run analyses passed. The portrait telemetry access check initially failed; after adding the development-only Pause > Data action, the failed flow and remaining checks passed. Results are recorded in suite_results.json.

Physical iPhone playtesting, notch/safe-area behavior on device, prolonged thumb comfort, and subjective engine/HUD timing still require human verification. Desktop windows at phone dimensions exercise layout and synthetic touchscreen events, not an iOS export.
