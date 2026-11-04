# Gameplay and UI quality review

The game still opens directly in the garage. This pass connects and polishes the existing systems; it does not replace the coupled 240 Hz drivetrain, roster, mechanical parts, AI, original synthesized audio, purchases or save data.

## Verified improvements

- Results have separate Garage and Upgrades actions. Garage no longer returns to a stale race-board tab; rematch/next race preserve the car and build.
- New saves default to a $0 wager. Visible stakes clamp to funds and opponent limits after purchases. Invalid/unfinished runs cannot pay rewards; repeated result calls cannot pay twice.
- Portrait layouts now cover garage, collection, upgrade categories, components/stages/gearboxes/tuning, dyno, dealership, race board, driver, racing, pause and results. Desktop/landscape views remain. Both layouts use the same actions, previews and purchase rules.
- Portrait uses a 600 x 1300 canvas, compact grids and large touch controls. Safe-area fitting has matching inverse pointer mapping; rotation releases held controls.
- Basic part comparisons show actual power, weight, grip, shifts, capacity, cooling, launch or tuning effects. Detailed specifications are optional. The dyno uses the shared simulated engine curve. Mechanical Tuning remains separate from cosmetic Customize.
- Gearbox configuration opens on the selected gearbox's family/page. Filters select a visible entry. Installed/owned/locked states and affordability remain tied to actual hardware.
- Vehicle presentation uses installed appearance and mechanical tire radius in garage, collection and results; dealership previews remain factory builds.
- Staging guidance follows installed transmission hardware. Countdown lamps follow the actual countdown. Finish feedback retains interpolated crossing time and trap speed. Portrait preserves telemetry, manual clutch/gear controls, paddles, automatic hardware behavior and the finish stripe.
- Short single notifications avoid primary controls and leave currency visible. Starting a race clears stale menu messages. Menu fades do not move hit targets or delay input.
- Static menus rebuild drawing commands for relevant changes instead of continuously. Physics/audio continue independently. Race estimates run in bounded slices between rendered frames using the same AI simulation; pending estimates show Measuring.

## Tests and economy evidence

The full 27-entry regression suite passed, followed by 18 checks from a new extracted package without an editor cache or existing saves. Final targeted tests also cover late match-result cancellation, traction-limited brake previews, portrait telemetry and live menu estimate completion. Normal process exits and error-free logs are required throughout.

The final targeted `test_quality_ui.gd` run passed **4,879 checks**: a new save, keyboard-driven race, real rewards, preview/dyno/purchase, duplicate-purchase protection, earned second-car purchase, switching/reload, bounded wagers, every upgrade category, desktop/landscape/portrait, injected safe areas, H-manual clutch multitouch, paddle clicks, automatics, telemetry and pedal release outside its button. The first test race was a 5.810 s 100 m win against the simulated 6.952 s opponent. After the $700 engine upgrade, four additional paid races funded a Mika purchase. No credits were granted for that progression segment.

`test_quality_model.gd` matches sliced and synchronous AI estimates exactly across paddle/manual, DCT, automatic and drag configurations. A 100-step budget executes 100 substeps. The same assisted-driver Kaze quarter estimate improves from **13.8223 s / 110.23 mph / 284 HP** to **13.2391 s / 115.75 mph / 324 HP** with engine Stage 1. These are driver-specific estimates, not the canonical regression fixture or guaranteed human results.

Prices and rewards were retained after evaluation. The first rival pays $250 for a win or $100 for a finish at zero stake. Starting funds cover the first engine stage. Modeled career wins after that upgrade reach $3,360 / level 3 at four wins and $6,120 / level 4 at eight wins including repeats. Seven finish/loss payouts fund the $700 upgrade from zero funds. Wager risk is optional.

The full wrapper also checks physics, all transmissions and drag maps, upgrade effects, AI, economy, save/load, audio, customization, dealership, live race flow and graceful shutdown. Machine-readable suite and delivery results accompany this report. Failed development runs are rejected by exit-code/error checks.

## Reference comparison

Supplied video contact sheets and recorded shift frames were reviewed again. The reference shows approximately 6,460 to 3,320 RPM around 31 mph during a human first-to-second shift, and another shift around 58 mph. Human H-pattern/clutch delays are not imposed on the preferred paddle system or faster installed hardware.

The unchanged fitted reference fixture yields about **18.4444 s / 74.924 mph**, versus the observed **18.415 s / 75 mph** slip. Sampled speed RMSE is 0.835 mph and loaded RPM RMSE 103.5 RPM. Launch RPM RMSE remains 457.5 RPM, with maximum sampled error near 593 RPM. No dealer data or reference parameters were refitted to conceal those residuals. Parameters and inputs are estimates; this is not recovery of proprietary formulas, and the fictional Kaze is a different vehicle.

## Manual verification still needed

Physical Android/iOS ergonomics, notches/system bars, low-end GPU frame times, battery and thermal behavior remain unverified. Desktop rendering was checked at 390 x 844 portrait, 844 x 534 landscape and 1200 x 760 desktop, with extra safe-area insets and generated input events. Physical audio latency and subjective timbre still need listening/playtesting. Artwork remains original stylized static 2D art; driven wheels share the existing equivalent-axle state rather than independent suspension/ABS physics. Earlier Windows native shutdown faults prompted the existing audio-detach/graceful-close path; monitoring driver-specific behavior remains appropriate. No validation exit checks were relaxed.
