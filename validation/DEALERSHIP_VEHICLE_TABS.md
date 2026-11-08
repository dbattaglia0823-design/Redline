# Dealership vehicle-category tabs

The class-selection landing page now offers **Cars**, **Bikes**, and **Boats/Jet skis**.

Each category displays six E–S class cards. The category is UI state only and does not change vehicle ownership, installed parts, engine classes, progression, wallet, or save data.

- **Cars:** fully operational existing car classes and dealership, including ownership, purchase, rendering, and the detailed vehicle screen.
- **Bikes:** six **illustrative previews** sourced from the existing `Bike Images and Templates/` art. These are preview-only. No motorcycle physics, purchasable motorcycle catalog, class balancing, or playable bike entries are being introduced by this change.
- **Boats/Jet skis:** E–C class cards use stylized jet-ski silhouettes, B–S show boat silhouettes. These are preview-only placeholders until watercraft art and gameplay systems are created.

Selecting an unreleased Bikes or Boats/Jet skis class shows a coming-soon message and remains on the class-selection screen. Selecting a Cars class opens the original working car dealership.

## Future catalog integration

`scripts/dealership_view.gd` owns the `vehicle_type` state, display names, preview references, and type selection. The placeholder categories deliberately do **not** reuse `GameCatalog.CAR_IDS`. When real motorcycles/watercraft are supported, add separate typed catalogs (IDs, performance metrics, class assignments, art, acquisition, ownership, and race compatibility) rather than treating bike and boat IDs as car IDs.

The current E–S preview choices do not imply final performance classes or real pricing. Class placement must be determined once dedicated motorcycle and watercraft physics are implemented.

The category tabs share the six-card desktop and portrait layout. Reopening Dealership from the global navigation defaults to Cars. Existing car purchase logic is unchanged.

## Validation

`tests/test_dealer_vehicle_type_tabs.gd` verifies tab state, existing bike preview resources, six class identifiers, safety isolation from car saves/credits, and reopening behavior under Godot headless CI. `tests/test_dealer_classes_ui.gd` also tests tap interactions and car purchases on desktop and portrait layouts when graphical tests are run.
