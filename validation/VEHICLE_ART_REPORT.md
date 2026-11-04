# Vehicle artwork and rendering validation

Implemented locally in the existing REDLINE project. No physics/audio, purchase,
save, progression or transmission architecture was replaced.

## Delivered

- New original Miata NA, Supra A80 and Mustang GT source artwork with 2000x720
  runtime variants. The first incorrect Miata attempt was rejected.
- All 30 cars rebuilt with opaque paint interiors, antialiased silhouettes,
  distinct finish shading, protected lamps, connected glazing masks and
  body-clipped number/stripe liveries. The other 27 retain their original bodies;
  this is not a claim that 30 newly drawn factory-perfect cars are complete.
- Original factory wheels remain stationary artwork, with short neutral rim
  reflections following actual driven/rolling axle phase and angular speed.
  No generic spinning factory wheel or tire-outline effect is layered over them.
- Wheels render behind the sprung body, preserving their ground position under
  stance and pitch. Corrected wheel texture gutter scaling and night modulation.
- Original workshop backdrop, restrained platform edge, contact shadows and
  improved label contrast. No real-time blur, extra particles or 3D system.
- LRU vehicle texture cache limited to 32 entries and 32 MiB estimated persistent
  RGBA residency. Redundant glass/lamp/empty-wing full-canvas draws removed.
- Reusable importer, authored crop/axle/glass/fixture data, integrity validator,
  source/provenance manifest, guarded legacy importer and pre-change archive.

## Verified

All 30 pass asset integrity checks. All 30 have native captures in garage,
upgrades, collection, dealership, customization, appearance preview and racing.
The three reference cars additionally have 390x844, 844x390 and 667x375 captures.
The rendering test uses controlled fixture states; these screenshots alone are
not evidence of correct launch physics. Separate existing runtime/control tests
were run for that purpose.

The 198-check presentation run includes preview isolation and cache-budget
stress. Wheel rendering checks cover all 30 models. The 405-check roster suite,
978-check customization suite, 4726-check fresh-player flow and 3210-check HUD
suite passed during this pass, alongside controls, customization UI, roster UI,
visual isolation and runtime audio/physics at 30/60/120/144 render caps.
Final presentation, rim, visual-isolation, customization UI and integrity checks
were repeated after the last mask correction. The entire 53-check registered
project suite was not rerun; this report covers the selected checks listed in
vehicle_art_results.json.

Compared every roster field with the pre-change archive: no non-art mechanical
field changed. Only wheel drawing anchors/radius metadata changed. No player save
was reset; automated tests used isolated save directories. Existing cosmetic
ownership/switching/persistence tests passed.

## Visual review and remaining limits

All 30 were reviewed in contact sheets; the three references and affected VW
hatchbacks were also inspected at full screen. Corrections from visual review
included painted Miata glazing, body-colored white lamp lenses, a misplaced VR6
lamp mask and glazing leaking onto a door reflection. A regression check protects
that door paint region.

This is a substantial rendering/layer pass, not completed factory-likeness
certification for every model. Precise proportions, OEM wheel trim, optional body
packages and some lamp contours still require model-by-model photographic art
review. Direct local photo downloads were unavailable; source/image searches and
manufacturer archive lookups were used, with their access limits recorded in the
asset manifest. No reference-game asset was reused.

Factory spoilers are baked into the bodies. Unsupported spoiler/lamp replacement
choices remain hidden; stored ownership survives. Caliper/sidewall changes retain
the existing custom-wheel path. Separate brake repainting behind factory spokes
requires authored gap masks. Physical iPhone performance/touch comfort and human
judgment of the rim-motion illusion remain unverified.

## Roster checklist

Every row has seven native screen captures and passes numeric layer/anchor
validation. "Reviewed" means the rendered presentation was inspected; it does
not mean exact factory accuracy is approved.

| Vehicle | Source | Render review | Remaining art review |
|---|---|---|---|
| 1990 Mazda MX-5 Miata | New original | Reviewed | NA nose corrected; exact overhangs and factory wheel trim still need art review. |
| 1999 Honda Civic Si | Retained; layers refined | Reviewed | Model-year proportions, factory trim and lighting contours. |
| 1997 Volkswagen Golf GTI VR6 | Retained; layers refined | Reviewed | Model-year proportions, factory trim and lighting contours. |
| 2003 Acura RSX Type-S | Retained; layers refined | Reviewed | Model-year proportions, factory trim and lighting contours. |
| 2013 Subaru BRZ | Retained; layers refined | Reviewed | Verify original-year bumper and lamp detailing. |
| 1997 Acura Integra Type R | Retained; layers refined | Reviewed | Model-year proportions, factory trim and lighting contours. |
| 2012 Volkswagen Golf GTI | Retained; layers refined | Reviewed | Model-year proportions, factory trim and lighting contours. |
| 2004 Honda S2000 | Retained; layers refined | Reviewed | Model-year proportions, factory trim and lighting contours. |
| 2022 Toyota GR86 | Retained; layers refined | Reviewed | Model-year proportions, factory trim and lighting contours. |
| 2003 Nissan 350Z | Retained; layers refined | Reviewed | Model-year proportions, factory trim and lighting contours. |
| 1998 Toyota Supra Turbo | New original | Reviewed | A80 body and wing; exact lamp/wing contours still need trim review. |
| 2001 BMW M3 E46 | Retained; layers refined | Reviewed | Model-year proportions, factory trim and lighting contours. |
| 2004 Subaru WRX STI | Retained; layers refined | Reviewed | Model-year proportions, factory trim and lighting contours. |
| 2003 Mitsubishi Lancer Evolution VIII | Retained; layers refined | Reviewed | Model-year proportions, factory trim and lighting contours. |
| 2019 Honda Civic Type R | Retained; layers refined | Reviewed | Model-year proportions, factory trim and lighting contours. |
| 2024 Ford Mustang GT | New original | Reviewed | S650 body and black multi-spoke wheel art; exact factory option/trim review pending. |
| 2020 Toyota GR Supra 3.0 | Retained; layers refined | Reviewed | Model-year proportions, factory trim and lighting contours. |
| 2016 Chevrolet Camaro SS | Retained; layers refined | Reviewed | Model-year proportions, factory trim and lighting contours. |
| 2019 Volkswagen Golf R | Retained; layers refined | Reviewed | Model-year proportions, factory trim and lighting contours. |
| 2023 Nissan Z Performance | Retained; layers refined | Reviewed | Model-year proportions, factory trim and lighting contours. |
| 2023 Chevrolet Corvette Z06 | Retained; layers refined | Reviewed | Model-year proportions, factory trim and lighting contours. |
| 2020 Nissan GT-R NISMO | Retained; layers refined | Reviewed | Model-year proportions, factory trim and lighting contours. |
| 2020 Audi R8 V10 Performance | Retained; layers refined | Reviewed | Model-year proportions, factory trim and lighting contours. |
| 2020 Ford Mustang Shelby GT500 | Retained; layers refined | Reviewed | Model-year proportions, factory trim and lighting contours. |
| 2019 Dodge Challenger SRT Hellcat Redeye | Retained; layers refined | Reviewed | Model-year proportions, factory trim and lighting contours. |
| 2021 Porsche 911 Turbo S | Retained; layers refined | Reviewed | Verify Turbo S rear wing shape against factory specification. |
| 2021 McLaren 765LT | Retained; layers refined | Reviewed | Model-year proportions, factory trim and lighting contours. |
| 2020 Ferrari SF90 Stradale | Retained; layers refined | Reviewed | Verify SF90 nose and blade lamp contours. |
| 2023 Dodge Challenger SRT Demon 170 | Retained; layers refined | Reviewed | Verify Demon 170 front/rear tire and body-package details. |
| 2018 Bugatti Chiron | Retained; layers refined | Reviewed | Verify C-line and factory wheel design. |

## Artifacts

- `validation/vehicle_art/sheet_garage.jpg` and six other rendered contact sheets.
- `validation/vehicle_art/<id>/`: individual screens and reference-car phone views.
- `validation/vehicle_art/before/`: pre-change reference-car screenshots.
- `validation/vehicle_visual_checklist.json`: all-30 capture checklist.
- `validation/vehicle_art_integrity.json`: numeric layer validation.
- `validation/vehicle_art_results.json`: tests and mechanical preservation check.
- `tools/PREMIUM_VEHICLE_ART_PIPELINE.md`: import and authoring requirements.
- `assets/vehicles/source_premium/asset_manifest.json`: sources and access limits.
