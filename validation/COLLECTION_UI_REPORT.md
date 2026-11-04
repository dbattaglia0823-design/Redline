# REDLINE — Native UI modernization, phase 2

Implemented locally in the existing project on November 4, 2026. No push,
replacement project, save migration or new visual theme was introduced.

## Architecture and delivered screens

- `CollectionScreen` extends the existing native `WorkshopScreen` lifecycle,
  action registry, header, notification and focus handling. The original
  DealershipView, CustomizationView, GarageHub, DriverProfile and pricing models
  remain responsible for all transactions, ownership and selections.
- Shared `VehiclePreview` now handles Garage, showroom, collection and option
  previews using VehicleRenderer and original vehicle-specific artwork. It
  preserves opaque bodies, authored wheel anchors, physical tire configurations,
  paint and saved appearance. Thumbnails use the same renderer as the hero.
- AutomotiveUI gained content cards, vehicle cards and real-value comparison
  rows. CosmeticSwatch uses actual authored stock wheels or WheelVisuals for
  custom designs; body changes use small configured vehicle previews.
- F6 development comparison still exposes the original presentation. Default
  navigation renders one native interface, without duplicate menus or handlers.

### Dealership

Six native class cards show actual factory class inventories, representative
vehicles, available purchase prices and ownership counts. Entering a class
opens a showroom with a large vehicle, compact selection cards, stock specs,
transmission, simulated quarter-mile estimate and comparisons with the active
installed build. Hybrid combustion output and electrical assistance are
identified separately. Purchase, owned, equipped, locked and unaffordable states
use the existing rules. Equip-on-purchase remains optional.

Technical specifications open in the same responsive detail area. Purchase
actions remain outside the details scroller. Redundant page controls disappear
when the inventory fits on one page; individual-car browsing remains available.

### Change Car

The collection shows only owned cars, with their actual upgrades, tuning,
appearance, current classes and performance. Desktop uses a compact browsing
column alongside the larger preview; portrait stacks the preview and grid.
Class filtering, performance sorting and paging retain their existing actions.
One primary Drive This Car action changes the active vehicle.

### Customization

Supported categories come directly from each vehicle's appearance definition;
unsupported lights, accessories or other features are not invented. Color and
finish swatches, accurate wheel thumbnails and configured body previews replace
text-only options. Installed and selected appearances, ownership, price,
comparison view, discard, factory restore and purchase/install are connected to
the original controller. Previewing does not modify currency, physics or saves.

Vehicle changes use a brief position transition; details use a brief text reveal.
Both honor reduced motion. Vehicle opacity is never animated.

## Problems corrected during rendered review

- Hidden inventory cards no longer retain click targets when details hide them.
- Short preview regions reserve wheel/shadow clearance instead of applying a
  constant downward offset that could clip tires.
- Wrapped mechanical labels now have usable minimum heights. A rendered capture
  exposed this issue despite the existing button tests passing; regression
  assertions now inspect specification-label geometry.
- Prices and unlock levels use integer formatting rather than trailing `.0`.
- Factory-wheel labels match the renderer's actual stock-wheel conditions.
- Current appearance and proposed choices have distinct, concise labels.
- Unnecessary pagination is removed for small inventories and collections.
- Collection phone space expands the vehicle presentation rather than leaving
  a large blank gap above the equip action.

## Verification performed

**19 relevant automated test scripts passed**, plus editor import and the
dedicated capture script. This was a targeted regression run, not another full
57-script suite run.

| Coverage | Tests / evidence |
| --- | --- |
| Native dealership, collection, customization | test_collection_ui — 11,320 checks |
| Shared layout, clipping, target bounds, popup isolation | test_glass_ui — 25,471 checks |
| Existing Garage / Upgrade Studio native integration | test_native_workshop |
| Class browsing, back/keyboard, purchases | test_dealer_classes_ui, test_dealership |
| All 30 vehicles' customization and rendering paths | test_customization_ui, test_vehicle_presentation |
| Other rendering / wheel regressions | test_visual_rendering, test_rim_rendering |
| Owned builds and menu usability | test_garage_hub, test_qol_ui, test_quality_ui |
| Physics and mechanical model | test_physics, test_upgrade_model, test_customization, test_roster |
| Racing input, rewards, saves and shutdown | test_controls, test_flow, test_shutdown |

The new test pushes mouse/touch events through Godot's viewport at 1200×760,
390×844, 360×780 and 844×390. It checks all six dealer classes, native target
geometry, details labels, exact purchase price, purchase without equipping,
owned-car paging/equipping, cosmetic preview isolation, disabled repeat purchase,
free reinstallation, restore/discard, persistence, per-car appearance retention,
and locked/unaffordable purchase protection.

The source contains no physics, save-schema, price, unlock or asset changes.
`git diff --check` also passes.

## Captures and results

- `collection_before/`: desktop and phone baselines for the four major screens.
- `collection_after/`: class overview, showroom, details, collection, paint,
  wheels and finish previews at desktop and phone resolutions.
- `collection_flow/`: input-driven captures and machine-readable results.
- `collection_phase2_results.json`: scoped test-run summary.

Rendered captures were inspected for composition, solid vehicles, wheel
placement, specification visibility, option artwork and fixed action access.
Automated asset loading alone was not treated as visual completion.

## Remaining manual checks

Physical iPhone/Android notch behavior, thumb reach, touch scrolling, font
rasterization and GPU/battery performance need device testing. Windows native
rendering and synthetic viewport touch do not verify those. No measured FPS or
mobile performance gain is claimed. Existing vehicle art quality differences
are retained; this phase improves presentation rather than replacing artwork.
