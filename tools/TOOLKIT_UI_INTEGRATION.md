# REDLINE Garage and Dealership toolkit integration

The Garage and Dealership functional templates are exported from
[Game-Dev-Toolkit](https://github.com/dbattaglia0823-design/Game-Dev-Toolkit),
`web/layout-kit/phase3-presets.js`, contract version 2. Their original layout,
action/data contracts and pre-import validation reports live in
`assets/ui/toolkit/`. The matching Godot runtime adapter is copied into
`vendor/game_dev_toolkit/ui_layout.gd`, with its MIT license beside it. Updates
are explicit local copies; the game has no network dependency on the toolkit.
The offline validator/schema in `tools/toolkit_validation/` share that license.

`ToolkitVehicleScreen` subclasses the Godot adapter to supply REDLINE's native
buttons, fonts, Liquid Glass materials, transitions, preview renderer and stats.
It retains the templates' action and binding IDs. Desktop Garage retains its
preview/details/action split; portrait reflows those regions into a vertical
studio. Dealership retains the catalog/details split with a real vehicle preview.
Short landscape layouts reserve a footer above the shared dock. Touch target
heights account for the actual canvas scaling and safe-area transform.

## Host mappings

| Toolkit action | Existing REDLINE system |
| --- | --- |
| `garage.previous`, `garage.next` | Cycle owned IDs and call `DriverProfile.select_vehicle`; refresh the existing car |
| `garage.change_vehicle` | `hub_owned`, the existing owned-car collection |
| `nav.upgrades` | `garage_upgrades` → existing upgrade catalog |
| `nav.customize` | `garage_customize` → existing customization studio |
| `dealership.select` | Class-checked stable vehicle ID → existing `dealer_*` selection |
| `dealership.purchase_request` | Existing `buy_car` / `drive_car` callbacks; existing price, unlock, balance, ownership and equip-on-purchase rules |
| `dealership.search`, `dealership.filter` | Presentation-only search and owned/unowned filtering within the selected class |
| `dealership.previous`, `dealership.next` | Select within that visible class inventory through existing vehicle callbacks |
| `nav.dealership_classes` | Existing `shop_classes` and remembered class selection |
| `dealership.details`, `dealership.equip_on_purchase` | Existing `shop_details` and `shop_equip` state |

`garage.selected.*` comes from the equipped profile, existing `Drivetrain`,
`GameCatalog`, and saved appearance. `dealership.selected.*` and
`dealership.vehicles` use the current engine class and existing factory inventory.
The toolkit does not own any inventory, balances, saves, unlocks or performance.
Specs lists are deliberately read-only; their missing action warnings are
intentional. Heading labels are static game branding and deliberately unbound.
No save schema or migration is introduced by this UI integration. Android and iOS
export presets explicitly include the runtime layout JSON and toolkit license;
contract and validation JSON remain development resources.

The dock contains exactly Garage, Race, Dealership and Profile. Upgrade, tuning,
customization and collection screens highlight their Garage parent. Entering
Dealership always opens the original six-class index; classes and their unlock
logic are unchanged. Existing controller and keyboard routing remains available.

## Verification

Run `node tools/validate_toolkit_ui.mjs` to validate the original contracts and
actual runtime layout/binding snapshots exported by `test_toolkit_vehicle_ui`.
Run that Godot graphical test for Garage switching, customized wheels, secondary
actions, class selection, filtering, browsing, purchase/equip states, exact
purchase costs, locked purchases and save/load compatibility. It captures
desktop, portrait iPhone-size and short-landscape screens with simulated safe
insets, and checks bounds, overlaps and 44-pixel touch targets.

The navigation, class dealership, upgrade workshop, customization and controller
regressions cover the surrounding flows. Screenshots and reports are under
`.qa/toolkit-ui/`. Physical iPhone safe-area reporting, touch latency, virtual
keyboard occlusion and device GPU behavior require physical-device testing;
simulated window sizes are not device certification.
