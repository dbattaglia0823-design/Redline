# Current 30-car asset pipeline

**Current v2 instructions: `tools/PREMIUM_VEHICLE_ART_PIPELINE.md`.** The rebuild
commands below describe the archived first atlas pass. The legacy installer is
blocked from overwriting v2 art. Use `tools/import_vehicle_art.py` for current
paint, glazing, lamp masks, finishes, wheel layers and reviewed source crops.

The active roster uses original detailed PNG illustrations. The older SVG generator is a fallback/development pass, not the final art pipeline.

## Sources and rebuild order

- Mechanical source: `tools/build_roster.py`; corrections: `tools/refine_roster_data.py`.
- Original transparent five-car atlases: `assets/vehicles/source_atlases/{E,D,C,B,A,S}.png`.
- Atlas splitter, paint/finish variants, masks, and independent stock wheels: `tools/RosterAtlasPipeline.cs`.
- Manifest and simulation-art anchor synchronization: `tools/install_roster_atlas.py`.

From the project root in PowerShell:

```powershell
& C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /r:System.Drawing.dll /out:.reference_helpers/RosterAtlasPipeline.exe tools\RosterAtlasPipeline.cs
& .reference_helpers/RosterAtlasPipeline.exe (Get-Location).Path
python tools/install_roster_atlas.py
& C:\Godot\godot.exe --headless --editor --path . --quit
& C:\Godot\godot.exe --headless --path . --script tests/benchmark_roster.gd
```

Use the configured Python interpreter if `python` is not on PATH. Rebuilding roster data also requires the refinement and manifest-install steps; otherwise authored anchors are lost. Do not run `generate_roster_art.py` after the PNG installer: it writes the earlier SVG manifest.

## Runtime contract

Each model has 1000x360 layers, wheel/exhaust/body anchors, opaque body interiors, paint/finish variants, a real paint mask, and separate front/rear wheel textures. Physics supplies wheel rotation and effects. Factory wheel art is used for default appearance; existing procedural wheels serve custom designs and colors. Cosmetic selection IDs remain stable.

Factory wings are baked into these illustrations. Replacement spoiler choices are hidden rather than pretending to render them correctly; saved ownership remains intact. Window/light masks and body accessories still need artistic inspection on every extreme appearance configuration. No numeric test can prove exact production-car proportions or licensing readiness.

## Validation

`tests/test_roster.gd` checks all 30 bodies, unique masks, opaque paint interiors, mechanical builds, classes, upgrades, hybrid energy, and migration. `tests/test_roster_ui.gd` exercises native dealership/garage/upgrade/collection/race flows, saves screenshots to `validation/roster_art/`, and covers desktop and portrait layouts. `tools/roster_contact_sheet.py` composes those real rendered screenshots.

## Paint-mask cleanup

The paint mask includes dark neutral body shading (brightness > 8 rather than > 75) so lower bumpers and sills do not retain speckled gray islands when recolored. Original glazing/lamp exclusions remain. Generic headlight/taillight bars were removed from VehicleRenderer; the installer hides those unsupported customization categories without deleting saved appearance ownership. Factory lamp artwork remains visible.

## Retained integrated artwork (inactive)

The pipeline retains `race_body_%d_%s.png` and `rim_radius` metadata from the earlier reflection experiment. Runtime rendering now uses body-with-cutouts variants and independently rotating stock wheel textures in every view. Custom wheels use the existing procedural renderer. The rotating rim-reflection outline is removed. Keep wheel anchor positions and radius accurate when processing a new atlas.

