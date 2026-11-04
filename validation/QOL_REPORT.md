# REDLINE — 10 quality-of-life improvements

1. **Quick section switching:** Ctrl+Tab / Ctrl+Shift+Tab cycles the six main sections. Leaving an upgrade sheet remembers its selected component and option; reopening that category restores them. The Live Dyno retains modal keyboard isolation.
2. **Find your active car:** Change Car opens on the page containing the equipped vehicle instead of retaining an unrelated page.
3. **No redundant cosmetic installs:** An already installed appearance option has a disabled Installed button, matching mechanical parts.
4. **Exact affordability information:** Unaffordable parts, packages, gearbox conversions, cosmetics and vehicles say how much more cash is needed. The option lists retain full purchase prices.
5. **Correct reverse keyboard focus:** Shift+Tab with no focused control starts at the last enabled action, rather than skipping it. Both directions wrap and omit disabled controls.
6. **Mouse Back support:** The mouse's Back thumb button follows Escape: close the current sheet/dyno/details, return through menus, or pause/resume a race. It never abandons a live race outright.
7. **Faster vehicle comparisons:** Left/Right previews owned vehicles across collection pages without equipping them. Home/End jumps to the first/last filtered dealership vehicle; existing dealer arrows remain supported.
8. **Discard cosmetic preview:** A dedicated control restores the installed appearance without spending, saving a preview, removing owned parts or restoring the factory build. It is disabled when nothing changed.
9. **Clear dealership filters:** A reset control is available while filtered results are visible, as well as when none match. Reset is one action and preserves ownership.
10. **One-tap no-wager races:** No Wager clears the proposed stake, ends slider dragging and keeps standard race rewards intact. It is disabled at $0. The phone summary keeps the action above the race button and navigation.

## Validation

Native Godot interaction tests exercise the ten changes at 1200×760 and 390×844 with isolated funded QA saves. Tests include real touch events, keyboard events, mouse Back, exact shortfall calculations, nonmutating previews, disabled installed controls, navigation retention and collection-page behavior. Additional target geometry checks cover the new filtered-dealer, customization and race screens. Screenshots are in `qol/`.

The dedicated QoL test passed 1,432 assertions across both window sizes. The layout audit passed 23,882 assertions across five window sizes. Eleven affected native suites passed; the delivered ZIP is also checked from a clean extraction with isolated saves.

Existing layout, new-player, customization, dealership, upgrade, menu, gameplay-flow and desktop-control suites are rechecked for this change. Current results are recorded in `qol_ui_results.json` and their individual logs. The previous Upgrade Studio report records the preceding physics/model audit; this change does not alter vehicle physics, prices, progression or save format.

Physical-phone comfort and hardware mouse thumb-button mapping still warrant device testing. Native window tests establish dispatch and layout behavior, not physical-device ergonomics.

