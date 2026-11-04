# Futuristic automotive interface

Implemented directly in the local Godot project. The supplied concept guided the navy/black materials, blue diagnostic edges, orange selections, compact components, vehicle platform, and separate purchase sheet. Existing original stylized vehicle artwork is retained; this is not a photorealistic reproduction of the concept car or workshop.

## Changes

- Central GlassPalette tokens and LiquidGlass surfaces now use dark navy materials, restrained cyan borders, short illuminated corner details, tighter radii and orange action/selection treatments. Cached styles and existing reduced-motion feedback remain in use.
- Shared backgrounds use faint structural lines. Garage/dealership/customization vehicle stages have lightweight wall lighting and an elliptical illuminated platform behind the solid car.
- Upgrade overview has a dedicated vehicle presentation with actual installed-build specifications on desktop; mobile keeps the car above a compact two-column grid. All four systems and 15 categories remain accessible. Desktop uses four columns, reducing card height and separating the vehicle from purchasing.
- Garage has direct Upgrades and Customize actions alongside Change Car and Find a Race, following this request. The existing floating navigation retains all six destinations with matching blue borders and orange selection.
- Upgrade purchasing remains a separate dimmed modal: existing two-column desktop comparisons, adaptive phone sheet, fixed purchase action, optional details and Live Dyno. Background click targets are removed while open. Existing original mechanical icons remain the accurate fallback rather than introducing unrelated component imagery.
- Dyno grid uses the diagnostic blue accent; curves, peak values and previews still come from the unchanged simulation. Non-engine parts retain contextual mechanical comparisons.
- Theme changes propagate through dealership, owned cars, customization, race selection, progression, results and relevant HUD controls. Race world physics and control mappings are unchanged.

## Verification

Native Godot tests cover five window-size layout audits, modal isolation, keyboard/mouse/touch controls, all upgrade groups, preview/install parity, dealership, appearance, new-player progression, race flow and vehicle render isolation. Screenshots are in `ui_after/` and `upgrade_studio/`; these are actual native renders. Individual test logs record results.

No changes were made to physics, economy, save format, vehicle masks, body opacity, wheel anchors or cosmetic ownership. Existing vehicle rendering continues to use an opaque body modulation; transparency remains only around the cutout silhouette and intentional window/lighting layers. Existing rendering tests verify layer and simulation isolation.

Physical iPhone performance, safe areas and touch comfort still need hardware testing. The immediate-mode screens retain their existing logical-canvas responsive adapter; the navigation remains a native Control/container layout. This change does not claim to convert every screen to native containers. Effects use inexpensive line/polygon drawing, cached StyleBoxes and the pre-existing single cached modal backdrop; there is no added live bloom or per-panel blur.
