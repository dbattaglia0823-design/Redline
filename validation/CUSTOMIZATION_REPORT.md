# Modular vehicle customization validation

The existing project now has one Customize screen, reached from Garage or the existing navigation tab. Mechanical upgrades remain in Upgrades. All 12 existing fictional vehicles use the same layered renderer and option catalog.

## Implemented

- Six existing paint colors, gloss/matte/metallic finishes, three wheel designs and existing silver/bronze/graphite colors.
- Blackwall, white ring, and rotating track sidewall marks; four caliper colors; three tint levels; factory/lowered/raised body presentation.
- Factory spoiler, clean deck, and a rear-anchored track wing; factory/ice/amber headlights, factory/ruby/smoked tail lights; clean, side stripes, and original number 71 livery.
- Large live preview, installed-versus-preview comparison, prices, installed/owned states, purchase/install, and factory restoration. Category changes discard uninstalled previews. Previously purchased choices remain owned per car.
- Portrait Customize layout with three-column categories and options, 68+ logical-pixel touch targets on a 600 x 1300 canvas; desktop and landscape retain the compact two-row category grid. Other game screens retain their existing landscape layout.
- All appearance choices are cosmetic. Ride height moves the body within a restrained visual range; it does not tune suspension. Sidewall artwork and wheel spoke design do not change tire dimensions, grip, mass, gearing, horsepower, or torque. Performance tires and suspension remain mechanical parts.

## Rendering and effects

`VehicleAppearance` supplies the stable option IDs, ownership defaults, normalization, asset definition, and a bounded 32-texture cache. `VehicleRenderer` draws body/finish, clipped livery, glass/tint, lamps, spoiler, exhaust, and independent layered wheels. Tires, rotors, fixed calipers, rotating spokes, rim highlights and blur are procedural. Existing wheel angular velocity, smoke, engine state, pitch, and body compression remain the sources of motion; no appearance setting writes physics.

The original six-color SVG bodies are preserved as source artwork. New layered derivatives separate glass, lamps, and factory spoiler. Body variants bake the finish and metallic flecks; there is no runtime shader, full-screen blur, or new 3D system. A white paint mask with window cutouts is supplied for each vehicle. Layers use the existing 1000 x 360 artwork space and share anchors with the smoke effects. Installed mechanical tire radius scales the wheel and raises its center/body so its contact patch stays on the ground. Stance moves only the body.

The simulation still has one equivalent driven axle. Both driven wheels on AWD share this angular state; undriven wheels assume rolling. These are presentation limits inherited from the drivetrain, not independent four-wheel or suspension simulation.

## Save and economy behavior

Appearance and cosmetic ownership are additive fields in each existing garage entry. Legacy paint/rim colors and upgrades migrate without a reset. The old top-level paint/wheels fields remain synchronized for compatibility. Installing the same part twice, restoring factory appearance, or reinstalling an owned part does not charge again. Insufficient funds, invalid IDs, unsupported options, and a committed wager prevent installation. Preview and comparison do not save, spend, or change the installed car. Currency and appearance use the existing atomic save operation.

## Validation

Final verification: all 25 entries in the complete validation suite passed with normal process exits, followed by 16 clean-package checks from a new extracted project without an editor cache or existing saves. The stock regression remains 13.2193 s at 109.8525 mph; the existing upgraded fixture remains 10.0011 s at 151.6064 mph. Appearance changes did not alter those results. Live audio checks at 30/60/120/144 render caps recorded zero steady-state underruns (14 startup/prior underruns); caps are not measured phone frame rates.

- `test_customization.gd`: 510 asset/compatibility/economy/migration checks, independent cars, ownership after reset/reload, invalid/insufficient-funds/race-locked choices, bad anchors/missing layers/unsupported accessories, and drivetrain invariance.
- `test_customization_ui.gd`: mouse and touch category/preview/install/compare flow, no preview writes, every category, all 12 car renders, bounded cache, desktop control bounds/overlaps, 844 x 534 landscape and 390 x 844 portrait rendering, portrait touch targets and purchases, garage and burnout race rendering without physics mutation.
- `test_shutdown.gd`: normal window-close path saves a purchased appearance, detaches the audio generator and stops playback before quitting. Three consecutive isolated checks passed during refinement.
- Existing physics, wheel motion, input, transmission, dealership, garage, unified upgrades, race/career, audio and economy suites are included in `tools/validate_racing.ps1`.
- Screenshots were inspected for body/wheel alignment, clipped decals, glass, brake layering and layout, including extreme combinations and roof-mounted versus deck-mounted track wings. Hatchback wing anchors and the Hammer/Aurora deck anchors were corrected during inspection. This is desktop rendering and generated InputEvent testing, not human phone playtesting.

Real device GPU time, battery use, touch feel and display readability remain unverified. Low/Medium/High visual presets and the smoke budgets are preserved. A transient Windows WASAPI output-device invalidation occurred during an initial menu regression run; that run was rejected by the validator despite its interaction assertions passing, and the subsequent menu run completed cleanly.

Some initial graphical tests also reproduced the previously observed Windows native exit code 0xC0000005 after printing passing assertions. These runs were rejected. Diagnostic runs reproduced an exit fault with WASAPI while all four Dummy-audio runs exited normally, suggesting the native audio path but not proving its cause. Shared presentation textures now release while the rendering server is alive. Window close saves first, stops/detaches the generator, and allows a 120 ms native callback grace interval before quitting; graphical test teardown follows the same audio cleanup. Repeated customization, garage, upgrade and input runs subsequently exited normally. The new tests check scene-shutdown cleanup and the real close-request path. This does not establish that every possible Windows driver/engine shutdown fault has been eliminated; continue monitoring real-device and native shutdown behavior.
