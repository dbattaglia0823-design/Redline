# REDLINE native UI modernization — 2026-11-04

Implemented in the existing local project. No gameplay architecture, vehicle
assets, physics formulas, economy, ownership or save schema was replaced.
No changes were pushed to GitHub.

## Source audit and migration boundary

The supplied GitHub `main.tscn` matches the local scene. Its `main.gd` also matches
the local starting Git revision. The scene's root is a Node2D; most menus combine
custom drawing with a centralized rectangle/action registry. The existing dock
used containers but custom-drawn, noninteractive items. Existing upgrade models,
candidate copies, transactions and category memory were suitable for reuse.

The new implementation migrates the Garage, upgrade overview and package/part
purchasing to native Controls. Vehicle art, charts and gauges remain custom
CanvasItems. Existing gearbox configuration, advanced tuning, expanded dyno,
dealership, customization, career and racing controllers are preserved. Other
menus share the bundled typography and new native navigation rather than being
rewritten simultaneously.

## Improvements delivered

1. **Reusable native UI vocabulary:** shared Theme, button roles, selection
   cards/rows, panels, stat cells, labels and mechanical icons in `AutomotiveUI`.
2. **Garage composition:** vehicle showroom region, stronger model hierarchy,
   real telemetry and one primary race action. Upgrades and Customize stay in
   the dock; Change Car and Test Track remain directly accessible.
3. **Adaptive layout:** separate portrait/desktop compositions use containers,
   margins and existing safe-area scaling. Portrait action targets are at least
   70 logical pixels high, approximately 45.5 pixels at 390-pixel width.
4. **Native grouped upgrade overview:** all 15 existing categories remain
   accessible through four system groups, with status, useful metrics and icons.
5. **Separate adaptive purchase modal:** desktop columns, stacked portrait
   content, background isolation and content-dependent sheet height. Short
   chassis comparisons no longer reserve a largely empty full-height panel.
6. **Fixed actions:** purchase/install, close, detail, dyno, sound and component
   paging stay accessible while long content scrolls.
7. **Clear ownership and spending:** installed, included, owned, selected and
   incompatible states have explicit labels and differentiated colors. Current
   funds, exact cost, shortfall and compatibility remain visible.
8. **Actual comparisons:** existing pure candidate drivetrains supply power,
   torque, mass, grip, gearing and mechanical specifications. Engine previews
   have a compact current/preview dyno; non-engine parts show relevant metrics
   and simulation-based quarter-mile estimates without invented horsepower.
9. **Complete powerband detection:** dyno visibility now compares the full
   sampled curve, fixing the prior single high-RPM test that could miss low- or
   mid-range changes.
10. **Async results update:** completed benchmark and class results invalidate
    cached presentation. Comparisons no longer remain stuck at “measuring”.
11. **Native navigation:** actual Buttons, Labels and containers replace the
    dock's drawn text/items, preserving its selection motion and all actions.
12. **Single activation path:** native pressed signals reuse the existing action
    dispatcher. Handled pointer/keyboard events cannot execute a second GUI
    purchase. Focus outlines follow keyboard traversal; clipped rows do not
    retain hit targets over fixed footer actions.
13. **Portable typography:** bundled Ubuntu regular/medium and Source Code Pro
    replace platform-dependent system fonts, including the audio test UI.
    Copyright notices and licenses are included under `assets/ui/fonts`.
14. **Lightweight feedback:** short reduced-motion-aware modal feedback,
    visible purchase notifications, restrained panel shadows and cropped
    showroom imagery. Native sheets skip the old GPU screenshot/blur capture.

## Verification

| Check | Result |
| --- | --- |
| Full `tools/validate_racing.ps1` | PASS — 56 Godot scripts, editor import and four Python analyses |
| Native workshop integration, rerun after final refinements | PASS — 164 checks |
| Five-size UI/target/modal/save audit, rerun after final refinements | PASS — 25,296 checks |
| Desktop and phone capture script | PASS; actual native renderer captures inspected |
| Purchase/install | Mouse and touch events sent through Godot's viewport pipeline; exact-once charge, disabled-repeat protection, installed/preview parity and save/load verified |
| Keyboard | Native focus and Enter activation tested without duplicate execution |
| Upgrade model | Existing stage/component, compatibility, drivetrain, dyno and non-engine regression checks pass |
| Existing gameplay | Physics, transmissions, staging, controls, audio, AI, rewards, economy, career, ownership, customization and shutdown checks pass |
| Whitespace validation | `git diff --check` passes |

The five UI audit resolutions are 1200×760, 1440×900, 390×844, 360×780 and
844×390. The full suite includes all 30 vehicle and transmission validations.
Its reference-analysis output remains a regression against a fitted replay with
estimated inputs; it is not independent recovery of the reference game's physics.

## Captures

- Pre-change baseline: `ui_before/garage_desktop.png`, `performance_desktop.png`,
  `upgrade_desktop.png`, and matching `_mobile` files.
- Final presentation: `ui_after/garage_desktop.png`, `performance_desktop.png`,
  `upgrade_desktop.png`, and matching `_mobile` files.
- Input-driven workflow evidence: `native_ui/purchase_desktop.png`,
  `purchase_phone.png`, `weight_desktop.png`, `weight_phone.png`.
- Machine-readable results: `suite_results.json`, `native_ui/results.json`,
  `glass_ui_results.json`.

## Remaining manual verification

Actual Android/iPhone notch and gesture behavior, thumb comfort, platform font
rasterization and low-end GPU performance need physical-device testing. Rendered
Windows captures and synthetic viewport touch events do not establish those.
No FPS or battery-life improvement is claimed. Visual polish is supported by
inspected captures rather than inferred solely from successful asset loading.

The remaining custom-drawn controllers are a deliberate incremental boundary,
not replacement mockups. Their buttons and mechanical workflows remain covered
by the existing regression suite. Development F6 comparison still exposes the
existing presentation without changing saves.
