# Native UI migration boundary

`AutomotiveUI` is the shared native Control vocabulary and cached Theme. It owns
typography, button variants, selection rows/cards, panels, technical icons and
stat cells. Screen layouts should compose these components with containers;
do not add another independent upgrade model or purchase handler.

`WorkshopScreen` currently owns the Garage, upgrade overview and package/part
purchasing sheet. Desktop uses columns; portrait uses stacked content, a
scrollable comparison area and fixed actions. The root inherits `main.gd`'s
existing safe-area transform and logical canvas size.

Vehicles stay in `VehicleRenderer`, rendered by a small Node2D inside a clipped
native preview region. Paint, wheels, proportions and opaque body assets remain
unchanged. The compact dyno is custom drawing from actual drivetrain torque.

## Input and state

Every native Button publishes its current, scroll-clipped bounds into the
existing action map. `main.activate_at` emits its `pressed` signal and consumes
that pointer press before Godot's GUI can execute it again. This preserves the
existing press-to-act semantics, touch behavior and automated test helpers.
Keyboard traversal uses the same action map with native focus outlines; handled
Enter/Space/Tab presses are consumed to prevent duplicate GUI activation.
The floating dock also uses native Buttons, Labels and containers through this
same adapter, on both migrated and existing menus.

Do not independently connect another purchase callback to `_gui_input`.
Purchases still run through `DriverProfile` / `UpgradeWorkshop`; previews remain
copies. `UpgradeStudio` supplies installed states, compatibility, metrics and
candidate drivetrains. Per-category selections retain the existing memory.

Controls rebuild only when their configuration changes. Deferred container
layout refreshes action bounds separately. Async class/benchmark results are
included in the presentation signature so measuring states resolve correctly.

## Deliberately retained

Gearbox configuration, advanced tuning/testing, expanded dyno, owned-car,
dealership, customization, career and racing keep their existing controllers.
They share bundled fonts and the native dock. Their custom charts, gauges,
vehicles and gameplay are not rewritten. Future migrations should reuse the
above boundary one screen at a time. F6 in a development build still switches
to the existing presentation for comparison; it does not change save data.

## Validation

Run `tests/test_native_workshop.gd` using the native Godot renderer. It pushes
real viewport mouse, touch and keyboard events, verifies purchases once,
preview/install parity, disabled actions, persistence and navigation at desktop
and phone sizes. It is registered in both validation runners.

`tests/test_glass_ui.gd` audits targets across five viewport sizes, every upgrade
category, modal isolation, affordability, preview purity and save compatibility.
`tests/capture_ui.gd` writes desktop/phone captures to `validation/ui_after`.
The same script with `-- --before` produced the pre-migration baseline.
