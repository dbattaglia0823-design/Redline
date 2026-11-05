# Vehicle artwork v2

The active renderer uses 30 distinct original studio side-profile illustrations.
The Miata, Supra A80 and Mustang GT established the lighting and framing for the
new set. The sources are individually keyed PNGs alongside the authoring manifest.
They are illustrated likenesses of the roster's model years and trims.

## Rebuild

Use the configured Python interpreter with Pillow and NumPy:

```
python tools/import_vehicle_art.py --audit
python tools/import_vehicle_art.py --install
python tools/validate_vehicle_art.py
```

`--install miata supra mustang` rebuilds just those vehicles. The first install
archives existing PNGs, manifest and roster in
`checkpoints/vehicle-presentation-20261104/installed_art.zip`. Source atlases and
save files are retained. Runtime cosmetic indices and part ownership are stable.

Original normalized legacy masters are `assets/vehicles/<id>/source.png`.
Active-source configurations are `assets/vehicles/source_premium/authoring.json`.
The earlier trio inputs remain available for comparison. For new source sheets,
`tools/prepare_vehicle_sheet.py` removes the solid magenta field and proposes
wheel centers from the lower tire arcs. Review the keyed car and axle fit before
copying the emitted configuration into the authoring manifest.

The old C# atlas installer now refuses to overwrite v2 artwork. Its normalized
master export is available through `.reference_helpers/export_legacy_masters.py`
if the original source masters must be reconstructed. Do not use the old SVG
generators or legacy atlas installer to rebuild current runtime assets.

## Authoring contract

- Logical canvas: 1000 x 360, front faces right. Runtime textures are 1000 x 360
  or 2000 x 720; originals can be larger. The three new cars use 2000 x 720.
- Wheel center baseline: y274. Set source rear/front axle centers and tire radius
  from the illustration. Importer normalizes them and updates only the roster's
  drawing anchors, never its physical tire radius or mechanical wheelbase data.
  A source with staggered tires can also supply separate visual radii. The rear
  baseline stays fixed while the front wheel follows its measured center.
- Source crop is optional. Axle coordinates and glass polygons are relative to
  that crop. Transparent padding, isolated car, no baked ground shadow or scene.
- Use strict side elevation and level circular wheels. Inspect the actual model
  year, bumper/lights, roof, glass and overhangs. Do not substitute later models.
- Neutral silver is the paint source. Opaque body/glass interiors, transparent
  surroundings, antialiased edge coverage; no white matte or disconnected noise.
- `glass` contains source-space glass polygons, `trim` logical-space exclusions.
  Bright roadster glass can set `glass_luminance_max` explicitly. Existing glass
  masks grow only through connected dark glazing, avoiding rectangular tinting.
- `assets/vehicles/lamp_regions.json` contains logical fixture polygons. Clear
  white lamps must be excluded from paint, along with colored lenses/markers.
  These are segmentation masks, not generic bars or light boxes drawn on cars.
- Factory spoiler/trim are baked. Unsupported spoiler/light replacements remain
  hidden, with purchased cosmetic ownership retained. Do not invent attachment
  anchors for a body accessory that has not been authored and fitted.

The importer creates paint/finish variants, paint mask, glass/tint, lamp layer,
body-clipped stripe/number liveries, normalized master, independent original
wheel cutouts and integrated inspection artwork. Every vehicle keeps its own
silhouette and wheel artwork. Gloss, matte and metallic are separate baked
shading treatments; metallic grain is deterministic and has no runtime shader.

## Runtime composition

Factory wheel artwork is static and lies behind the sprung body. Short neutral
rim reflections use the simulation's driven/rolling wheel angle and angular
speed. Stopped wheels have no moving highlight. No substitute spinning factory
wheel, outer tire ring, neon circle, frame timer or generic headlight box is used.
Custom wheel designs retain the existing physics-driven procedural rendering.

Body pitch/stance do not move unsprung wheel centers. The wheel texture's gutter
is preserved rather than shrinking the tire into its body cutout. Contact shadows
follow actual wheel anchors/radius. Low effects quality skips reflections and
contact-shadow bands. Night modulation applies to factory wheel art too.

Glass/lamps/factory wing are already in v2 body textures; they must not be drawn
again as redundant full-resolution layers. Tint and livery remain independent.
The vehicle texture cache is LRU, capped at 32 textures AND 32 MiB estimated
RGBA8 persistent residency. Frame references stay alive until draw commands are
replaced. This is not a claim about total application/driver memory.

## Validation

`tests/test_vehicle_presentation.gd` captures all 30 cars in garage, upgrades,
collection, dealer, customization, appearance preview and racing. It also covers
390x844, 844x390 and 667x375 for the three reference cars and stresses high-res
appearance browsing against the texture budget. `test_rim_rendering.gd` checks
all 30 wheel anchors, stationary phase changes, moving reflections, custom wheels
and rendering without physics mutation. `tools/vehicle_art_contact_sheets.py`
composes actual captures for inspection.
`-- --roster-review` captures a real test-track launch and Garage view for
every vehicle, with extended screens for the trio. The contact-sheet tool's
`--roster-review` option collects those Garage and race frames.

Integrity checks do not prove automotive likeness. Full-size model/trim review,
physical iPhone performance and human assessment remain separate quality gates.
Caliper/sidewall changes still use the existing custom-wheel path; independent
repainting of brakes behind an opaque factory wheel needs authored gap masks.

## Sources and rights

`source_premium/asset_manifest.json` documents original generated artwork and
visual research links. Photographs are research references only, never runtime
textures. Real names/branding remain configurable; no release licensing decision
is implied by this development artwork pass.
