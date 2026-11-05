# REDLINE — Phase 2 final visual and functional review

The dealership, owned collection and customization now use the existing
native Control foundation at the requested desktop and phone sizes. The
follow-up preserves all gameplay models and data. The source diff has no
vehicle assets/specifications, class calculations, prices, unlock rules,
ownership transactions, drivetrain formulas or save-schema changes.

## What the render review changed

The original 844×390 result rendered a 615×390 viewport inside the window,
shrinking the desktop controls to about 24 pixels high. The three migrated
menus now use the existing wide-canvas convention at that size. The native
renderer fills the 844×390 viewport; primary controls are approximately 44 px
high and the navigation targets approximately 45 px high before device insets.

- **Dealership:** side-by-side showroom and compact car cards, readable stock
  specifications and fixed purchase controls. The larger car and stronger
  label hierarchy were checked against the pre-migration desktop/phone captures.
- **Change Car:** a large opaque preview of the actual saved build, with the
  collection beside it in landscape and below it in portrait. Class, gearing,
  performance and equipped state remain visible. Small collections avoid
  unnecessary page controls.
- **Customization:** full vehicle preview beside a compact landscape category
  grid and scrollable swatch strip. Portrait retains its full-width preview.
  The selected option stays in view, and purchase/discard/restore stay outside
  the scroller. A touch swipe scrolls without changing the preview or balance.

I inspected the rendered vehicle bounds, wheel placement, labels, contrast,
selection states, action spacing and available canvas space. The review found
and corrected undersized landscape controls rather than accepting the passing
button tests as visual proof. The retained pre-migration captures cover
1200×760 and 390×844; they are in `collection_before/`.

## Captures

| Window size | Dealership | Change Car | Customization |
| --- | --- | --- | --- |
| 1200×760 | [Showroom](collection_after/dealer_1200x760.png) | [Collection](collection_after/owned_1200x760.png) | [Paint](collection_after/style_1200x760.png) |
| 1920×1080 | [Showroom](collection_after/dealer_1920x1080.png) | [Collection](collection_after/owned_1920x1080.png) | [Paint](collection_after/style_1920x1080.png) |
| 390×844 | [Showroom](collection_after/dealer_390x844.png) | [Collection](collection_after/owned_390x844.png) | [Paint](collection_after/style_390x844.png) |
| 844×390 | [Showroom](collection_after/dealer_844x390.png) | [Collection](collection_after/owned_844x390.png) | [Paint](collection_after/style_844x390.png) |

All 12 requested PNG dimensions were verified. Class cards, mechanical details,
wheels and finish previews were also captured at each size. These are actual
Godot renderer pixels. Where the viewport texture omits native window letterbox
margins, the capture includes those black margins without resampling the render.
[Capture manifest](collection_after/capture_manifest.json) records both sizes.

## Final regression coverage

- **Native end-to-end flow:** 14,152 checks across the four requested window
  sizes plus 360×780. Uses mouse, synthetic touch and keyboard events through
  the Godot viewport. Tests all six dealer classes, browsing and filtering,
  disabled purchases, exactly one debit per purchase, and purchase without
  changing the equipped car. Keyboard Enter also exercises a vehicle purchase.
- **Collection preservation:** switching and paging among owned vehicles retains
  paid engine stages, installed programmable ECU, launch RPM, saved tuning
  preset and per-vehicle appearance.
- **Cosmetics:** preview does not mutate physics, funds or saves; paid install,
  free owned reinstallation, compare, discard, factory restore and save/load
  pass. A native viewport touch swipe moves the option strip without selection
  or spending.
- **Shared layout:** 25,389 checks pass. The audit now checks the actual logical
  canvas used by the view, including wide landscape layouts.
- **Targeted regression:** 11 scripts passed across collection, dealership,
  customization, Garage/Upgrades, physics, upgrade model, race controls,
  race/save flow and shutdown. Editor import and capture also passed. This is
  separate from the initial Phase 2 run and does not claim a new full-suite run.

The scroll input adapter only owns the short-landscape option strip. It
distinguishes swipes from taps and sends taps to the original action dispatcher
once. It does not process purchases or introduce another state model. Existing
native and legacy presentations remain mutually exclusive.

Physical iPhone/Android safe-area ergonomics, touch behavior and GPU performance
still need device testing. Synthetic viewport input and Windows renders do not
substitute for that.
