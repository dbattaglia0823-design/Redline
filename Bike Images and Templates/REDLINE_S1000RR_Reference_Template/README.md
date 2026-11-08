# REDLINE — S1000RR reference-quality motorcycle sprite

This package uses the **user-supplied S1000RR image** as the source for faithful appearance. Unlike prior approximate SVG sketches, this visually preserves the reference fairings, exhaust, controls, brakes, paint, and proportions.

## Artwork
- `reference_master.png` — transparent, padded 2048×738 full original reference image.
- `body.png` — the original stationary body cutout with rotating wheel areas punched out.
- `body_no_wheels.png` — improved body-only asset generated from the reference, with tires and rims removed while preserving visible hardware such as brake calipers, fork bottoms, chain, swingarm, and exhaust.
- `body_no_wheels_game.png` — game-sized 1000×360 version of the improved wheel-less body asset.
- `preview_body_only_game.png` — quick preview of the body-only game asset.
- `rear_wheel.png`, `front_wheel.png` — isolated spinning wheel regions.
- `*_game.png` — resized assets for Redline's existing 1000×360 coordinate canvas.
- `preview.png` / `preview_game.png` — composed static preview.
- `anchors.json` — wheel geometry.
- `motorcycle_sprite.gd` — standalone Godot 4 example displaying independent wheel rotation.

## Integration
1. Copy `body_game.png`, `rear_wheel_game.png`, and `front_wheel_game.png` into `res://assets/vehicles/motorcycle_template/`.
2. Use `motorcycle_sprite.gd` on a Node2D; feed speed in meters/second and optionally rear-wheelspin ratio.
3. For the existing Redline renderer, implement a motorcycle-specific render path or adapt `VehicleRenderer` to draw transparent PNG wheel layers instead of its procedural car wheels.
4. Do not enable Redline car-wheel/stance and spoiler customizations for this bike until bike-specific options exist.

## Anchors
- Rear: `[270.508, 255.61]`, front: `[729.492, 255.61]`, normalized to 1000×360.
- Both centerlines are level.
- Approximate radius: `97.168` source-art canvas pixels.

## Limitations
These are high-resolution *raster cutouts* from the supplied image, not geometry-correct vectors. Fixed fenders, forks, swingarm and exhaust are kept stationary; some fine details of the brake/chain near moving-wheel boundaries may require manual paint-cleanup for close-up animation. Wheel-spoke cutouts are not newly illustrated from behind. The bike has not yet been integrated into, or tested in, Redline itself. No claim of a licensed third-party asset is made.


## Recommended current use
Use `body_no_wheels_game.png` if you want the cleanest body-only version for composing your own wheel sprites. Keep `rear_wheel_game.png` and `front_wheel_game.png` as the spinning wheel layers. Because the improved wheel-less body was generated as a cleanup pass, treat the existing anchors in `anchors.json` as a solid starting point and expect a small retune in Godot if you notice any sub-pixel mismatch.


## Customization-ready wheel anchors (v2)
`anchors.json` now provides *two artwork-specific profiles*. Choose the profile matching the body image:

| Profile | Body | Rear center | Front center | wheel radius |
|---|---|---|---|---|
| `clean_generated_body` (default) | `body_no_wheels_game.png` | `(224, 255)` | `(768, 255)` | `97.5 px` |
| `original_reference_body` | `body_game.png` | `(270.508, 255.61)` | `(729.492, 255.61)` | `97.168 px` |

Coordinates are in the same **1000×360 top-left-origin coordinate system** as the body image. Both wheels in each profile have matching center Y and matching radius, keeping the tires level. Draw each customizable wheel centered at its anchor, with a diameter equal to 2× radius; rotate around the center. Draw the body afterward so the stationary brakes/fork/swingarm obscure the appropriate parts of each wheel.

The included `motorcycle_sprite.gd` reads the JSON and supports changing between the two profiles without rewriting coordinates. Replace the wheel textures for customized wheel designs. The setup is a standalone example, not a completed integration with Redline's existing `VehicleRenderer` or customization UI.

`preview_custom_wheels_game.png` shows wheels assembled with the **new body**; `preview_anchors_game.png` adds coordinate guides. These are visually tuned placements, but the generated body is not perfectly mechanically consistent at both axles, so some caliper/axle art will require a final touch-up before claiming exact OEM fitment.
