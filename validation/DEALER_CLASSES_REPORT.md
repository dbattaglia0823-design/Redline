# Dealership class entry

The Dealer navigation now opens six clickable class cards (E–S) rather than filter selectors. Each card uses measured factory classes and shows a representative car, inventory count, starting price and quarter-mile band. Selecting one opens the existing dealership with only that class's cars. Purchases, ownership states, comparisons, details and equip-on-purchase are retained.

Class selection remembers the last viewed car per class during the session. Classes/back and Escape return through details → class inventory → class cards → garage. Arrow/Home/End navigation stays inside the selected class. Legacy make/price/drivetrain/filter controls were removed.

Desktop and portrait native screenshots were inspected under validation/dealer_classes/. A multi-car rendering issue was found and fixed: texture resources are pinned through their drawing frame even when the bounded persistent cache evicts them. The persistent 32-texture cache limit is unchanged.

Passed native checks: test_dealer_classes_ui (all six classes, mouse/touch input, in-class keyboard browsing, remembered selection, details/back, purchase/save, bounds and white-texture regression), test_dealership (30 configurations/purchases), test_menus, test_roster_ui, test_qol_ui, test_quality_ui, test_customization_ui and test_quality_pass. The new UI check is included in tools/validate_racing.ps1. No vehicle physics, economy prices or save format changes were made.
