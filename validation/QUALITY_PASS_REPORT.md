# REDLINE — quality improvement pass

Changes are in the existing local Car Game project. No physics architecture, vehicle artwork, purchase pricing, or save format was replaced.

## Eleven implemented improvements

1. **Trustworthy vehicle testing:** The benchmark records the tested vehicle/build identity. Changing parts, stages, tuning or car clears obsolete results and cancels the obsolete worker. Starting another test while one runs is blocked, including in the action handler.
2. **Honest tuning controls:** Launch RPM, converter stall, nitrous ramp, shift firmness and final-drive steppers disable at their real hardware limits. The highest gear has no upshift-RPM control. RPM, pressure, time and gear ratios use appropriate units/precision rather than every value showing two decimals.
3. **Useful presets:** Presets disable when the current category has no eligible installed tuning hardware. Feedback distinguishes an actual tuning change from an already-matching or unsupported configuration.
4. **A readable dyno:** The last visible HP/torque curve cannot be switched off. Either curve can still be viewed individually, and toggles retain their selection.
5. **Accurate collection thumbnails:** Phone Change Car thumbnails now receive each vehicle's saved appearance, including paint, wheels and accessories, rather than showing the default look for every car.
6. **Popup affordability context:** Desktop upgrade modals show the player's current currency alongside the existing price and exact cash shortfall; players no longer need to close the sheet to check their balance.
7. **Actionable locked-part lists:** Component cards show the actual compatibility requirement instead of just Locked. Text fits the card; detailed specifications and restrictions remain available in the comparison panel.
8. **Consistent cosmetic Back:** Escape/mouse Back uses the same cleanup path as the visible Garage button, discarding an uninstalled cosmetic preview without changing installed appearance or ownership.
9. **Affordable race entry:** A proposed wager is clamped against both opponent limits and current cash at race entry. Money spent since selecting a wager no longer produces a preventable dead end. The displayed wager and charged stake agree.
10. **No hidden wager dragging:** Switching sections ends wager-slider dragging, so mouse/touch movement in another menu cannot alter the hidden stake.
11. **Stable dealership details:** Vehicle browsing shortcuts cannot silently change the selected car behind an open desktop Details panel. Close Details before browsing; the existing return button and Escape still work.

## Verification

`test_quality_pass.gd` exercises benchmark identity/restart protection, tuning limits, unavailable presets/reset, nonblank dyno, details browsing protection, slider cleanup, cosmetic Back and affordable race entry. It uses an isolated QA save and actual key/action dispatch. The existing native suites cover saved appearance, all categories, preview/install parity, dyno math, touchscreen and desktop input, responsive bounds, purchases and navigation.

The full validation wrapper includes the new focused test alongside existing physics, transmission, AI, audio, staging, economy, progression, save, rendering and new-player tests. Individual logs and JSON files record actual outcomes; `suite_results.json` is written only after the wrapper completes successfully. Updated rendered screens are in `ui_after/` and `upgrade_studio/`.

The supplied concept remains the visual direction; no extra redesign was introduced. Opaque modular cars, separate purchase modals, cached glass styling and restrained effects remain intact.

Existing reference measurements are documented in `new_reference_observations.csv` and `UPGRADE_STUDIO_REPORT.md`. This pass does not claim a new frame-by-frame or audio review of the source recordings. Sparse reference samples and unknown installed reference builds cannot establish exact physics equivalence. The Game folder's earlier missing walkthrough remains unverified.

Final result: the complete **34-entry suite passed**, plus native screenshot capture. The focused test passed 11 regression assertions; upgrade-model checks passed 4,672 assertions. All 204 transmission comparison runs, 15 career opponents and 12 dealership vehicles passed the existing analyses. Reference acceptance uses a fitted replay with estimated inputs and is a regression check, not independent recovery of The Strip's formulas or exact hardware/audio behavior.

Physical iPhone performance/safe areas, subjective driving/audio feel, and prolonged human usability testing remain manual work. Native phone-sized windows verify layout and event handling, not physical-device ergonomics.
