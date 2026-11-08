# REDLINE — Single Tuning Menu

## Navigation

**Garage → Upgrades → Tuning** is now the only tuning interface.

- The main Upgrades landing screen has a Tuning action in the native and fallback desktop/mobile layouts.
- Upgrade part popups no longer offer a second Tuning section, a scoped tuning slider list, or a separate gearbox/boost preset submenu.
- Older internal calls to `upgrade_section_tune`, `system_tuning`, and `work_tune` are redirected into the main Tuning tab rather than recreating a removed page.

## Complete controls

The existing central tuning editor remains the source of truth for all tuning controls, organized into:

- **Launch:** launch RPM, launch control, traction slip target, pedal curve
- **Power:** boost, per-gear boost caps, boost response, rev limiter
- **Gearbox:** gear count, individual ratios, final drive, upshift RPMs, shift firmness, launch gear
- **Clutch:** engagement rate
- **Grip:** tire pressure, launch damping, differential preload

The old Street / Drag / Safe quick setups are now visible at the top of the central tuning editor. The former **Reset Automatic Shift Map** action is in the central Gearbox section, under the gear adjustments. Saved custom tune slots, optimizer, test track, and telemetry remain in the existing Tuning tab.

## Obsolete requirements and valid safeguards

The former upgraded-tires requirement for tire-pressure tuning has been removed: stock and upgraded tires can both have their pressure adjusted. This change is checked by the same hardware-validation path used for saved tunes and active physics.

Other prerequisites remain only where they correspond to **existing** functioning hardware (e.g. programmable ECU for rev-limit adjustment, electronic boost control for per-gear caps, adjustable suspension for launch damping, and suitable transmission types for automatic-shift controls). These parts still exist in the current vehicle catalog. This change does not bypass race/pending-wager checks, modify purchase eligibility, or alter transmission compatibility.

## Compatibility and testing

- Vehicle profiles retain their existing `hardware.tune` dictionary and saved per-vehicle tune slots; **no save migration** is required.
- Tuning shortcuts use the existing `DriverProfile.apply_tuning_preset` logic; they are not duplicated in the upgrade UI.
- `test_tuning_consolidation.gd` verifies that all upgrade categories omit duplicate tuning sections, factory tire-pressure tuning works, real hardware prerequisites are preserved, shortcuts update the active car, shift reset works, and credits are unchanged.
- Existing upgrade and tuning UI tests now target the central Tuning editor instead of the removed per-upgrade controls.

Graphical checks should be run on desktop and portrait mobile to verify slider focus, quick-setup button sizing, scrolling, return navigation, and save/load behavior.
