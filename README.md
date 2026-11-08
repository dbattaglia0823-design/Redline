# REDLINE // Street Division

An original Godot 4.6 drag-racing prototype inspired by the interaction patterns in the supplied reference screenshots. Open `project.godot` in Godot and press F5, or run `Play.bat`. The launcher imports the artwork before opening the game.

## Liquid Glass interface

Garage and class-specific Dealership browsing now use the Game Development Toolkit's functional layouts with REDLINE's vehicle renderer and purchase controllers. Garage presents the selected car, make/model/year and live stats, with Upgrades, Customize and Change Car actions. Dealership opens its existing engine-class index first, then a searchable catalog and vehicle detail view inside that class. See `tools/TOOLKIT_UI_INTEGRATION.md` for the action/data contract mappings and validation commands.

The existing game uses a dark glass design system: rounded surfaces, orange actions, icon-based upgrade cards, and adaptive detail sheets. The shared bottom dock has exactly four destinations: Garage, Race, Dealership and Profile. Secondary features remain under Garage. Screens share styling, animations and action routing, with responsive touch targets and safe-area transforms.

Open Driver to choose reduced UI motion or Low effects. Medium/High cache one downsampled background when a sheet opens; Low uses a readable tinted surface without a screen read. No live blur is applied separately to controls. Desktop Tab / Shift+Tab moves focus, Enter or Space activates it, and Escape returns through the existing menu hierarchy. Racing keys are unchanged. F6 toggles a development-only rectangular-surface/old-dock comparison; it does not revert gameplay or the layout redesign.

The palette, translucency, radius, shadow, blur amount and animation duration are centralized in `scripts/glass_palette.gd` and `assets/ui/liquid_glass.tres`; native Control styles live in `assets/ui/glass_theme.tres`. The floating dock uses PanelContainer / MarginContainer / HBoxContainer. The existing custom-drawn screens keep one shared hit map so native and drawn controls cannot execute the same action twice.

See `validation/LIQUID_GLASS_REPORT.md` and `validation/ui_before`, `validation/ui_after` for changes, limitations, tests and matched screenshots. Run `tests/test_glass_ui.gd` for the responsive interaction audit, or `tools/validate_racing.ps1` for the complete regression suite.

## Controls

PlayStation (DualShock / DualSense) and Xbox controllers use Godot's standard gamepad mapping. Connect over USB or a supported Bluetooth connection, then press a button to take control. Keyboard and touch remain available. The pause screen shows labels for the active controller family.

| Action | Xbox | PlayStation |
| --- | --- | --- |
| Throttle / brake (analog) | RT / LT | R2 / L2 |
| Clutch / transbrake (hold) | LB / RB | L1 / R1 |
| Upshift / downshift | B / X | Circle / Square |
| Neutral (H manual) | Y | Triangle |
| Nitrous (hold, requires kit) | A | Cross |
| Pause / resume | Menu | Options |
| Navigate menus | D-pad or left stick | D-pad or left stick |
| Select / back (menus) | A / B | Cross / Circle |

For H manuals, hold the clutch while stepping through gears; clutch and over-rev protections still apply. Automatic gearboxes retain their automatic shifting behavior. In Tuning, up/down moves between controls and left/right adjusts the selected slider. Held directions repeat after a short delay. Disconnecting the active controller pauses a race and releases its pedals; reconnect and press Menu / Options to resume. Only one controller drives a race at a time.

Controller regression checks inject mapped button and axis events through the real input pipeline, including purchasing, tuning, manual shifts, deadzones, pause and disconnect recovery. Physical USB/Bluetooth pairing, OS drivers and device-specific mappings still require testing with real PlayStation and Xbox controllers.

| Action | Keyboard | Mouse / touch |
| --- | --- | --- |
| Gas | W or Up, hold | Hold GAS |
| Brake | S or Down, hold | Hold BRAKE |
| Downshift | Q or Left, tap | Tap the left paddle |
| Upshift | E or Right, tap | Tap the right paddle |
| Clutch | Shift, hold | Hold CLUTCH |
| H-pattern gear selection | Hold Shift + 1–6; N or 0 for neutral | Hold CLUTCH and tap a gear gate |
| Compatible transbrake | B, hold | Hold TRANSBRAKE |
| Nitrous | Space, hold | Hold NITROUS |
| Pause | P or Escape | Pause button |
| Rematch | R or Enter on results | Rematch |
| Mute | M | Garage sound button |
| Physics telemetry | F3 | F3 button during a race |
| Shift guide | F4 | Keyboard toggle |

The original car keeps paddle shifting. Hold gas during staging; hold Shift to free-rev, then release to launch. Paddle shifts have automatic clutch assistance. The original stock guide uses 6,750–7,350 RPM; installed hardware builds calculate their own shift map. Unsafe downshifts are rejected.

Q below first selects neutral (N); E selects first again. Neutral revving cannot accelerate the car. Shift manually opens the clutch even with paddle assistance enabled.

Purchased H manuals require clutch + a gear gate; release the throttle and match revs, or fit a programmable ECU for ignition-cut flat shifts. Purchased sequential or paddle actuators change the available input system. Factory automatics and drag automatics shift themselves; compatible paid paddle controllers allow manual operation. Converter and DCT hardware operates its own clutch. A fitted transbrake locks first-gear output near stationary, loads the converter, then releases to launch.

A second paddle tap during a shift can queue one gear change. Repeated taps do not build a long queue; the opposite paddle cancels the pending tap. Pausing or switching windows clears it. The optional guide waits for traction and clutch recovery, then keeps reminding you if the shift is late.

Mouse buttons can hold separate pedals: hold gas with the left button and tap a paddle with the right button, or mix keyboard and mouse. Releasing anywhere releases that button's pedal. Pausing and switching windows clear held controls.

Nitrous starts with six usable seconds per race, extended by nitrous upgrades. It sprays under full throttle with the clutch engaged, brakes released, and speed above about 11 mph. It pauses during shifts, stops when empty, and refills on the next race.

## Garage and workshop

Open Upgrades from Garage. One overview organizes every existing category into Engine & Power, Drivetrain, Chassis & Grip, and Supporting Systems. Categories open a single component sheet with named package, hardware and tuning choices. Close or Escape returns to the same system and selection. Background controls are blocked while a sheet is open.

Engine airflow packages, programmable ECUs and stronger internals have distinct roles. A fitted induction assembly replaces the packaged turbo curve rather than adding a second turbo. Comparisons show actual configured parameters; non-engine upgrades use relevant mechanical values and assisted quarter-mile forecasts rather than a giant unchanged dyno. Live Dyno remains accessible throughout. See `validation/UPGRADE_STUDIO_REPORT.md` and `validation/UPGRADE_PARAMETER_AUDIT.md` for the audit, reference observations, corrections, tests and screenshots.

Transmission stages remain Stock -> Stage 1 -> Stage 2 -> Stage 3 -> Race -> Pro Race, separate from owned gearbox configurations. Other legacy categories retain three stages. All 34 mechanical parts and 21 gearbox configurations remain accessible through their category windows. Tune presets affect only the selected category. The dyno returns to the same component window, and TEST BUILD is an independent utility on the overview.

Purchases, ownership, compatibility, save data, upgrade effects and vehicle testing continue using the existing systems. There are no separate car-hotspot, basic-workshop or advanced-workshop navigation paths. Gearbox controls, engine output, mass, traction and other previews use the actual configured simulation.

Appearance includes six paint finishes and three wheel finishes. Each owned car keeps its own paint, wheels, and upgrades.

## Race board and wagers

Three career ladders unlock at levels 1, 3, and 5. Each has five named bot rivals, with 100 m, eighth-mile, and quarter-mile events. Beat rivals in order; previously beaten rivals remain available for rematches.

Choose a stake using the slider or +/- buttons. Entry charges the stake immediately. Winning returns twice the stake, including the original stake. Losing, forfeiting, or closing during a run loses the stake. The results slip shows race pay, bet return, and net profit separately. Wagers use fictional local game credits.

Race cash comes only from winning bets. A win returns twice the stake (the original stake plus equal profit); losses, red lights, and abandoned races lose the stake. Free races still earn XP and championship progress, but never money. Spending or losing every credit leaves no racing income until the player has betting funds again; no emergency loan is granted. Returning to the race board after a win selects the next unlocked rival.

The live clock, time-slip totals, 60-foot split and saved records count from green, including driver reaction. This time basis is labeled on the slip; reference calibration separately compares reaction-excluded drag ET.

## Dealership

| Car | Engine / drivetrain | Price |
| --- | --- | --- |
| Kaze S2 | 2.0L turbo I4 / RWD | Starter, already owned |
| Nori Club RS | 1.8L turbo I4 / FWD | $5,200 |
| Aster GT | 3.0L turbo I6 / RWD | $12,500 |
| Vanta RX | 3.8L twin-turbo V6 / AWD | $32,000 |

Buying a car adds it permanently to the collection. Equip on purchase defaults to Yes and can be switched off. Previously owned cars remain available. Vehicle torque, mass, and traction affect the actual race simulation. Horsepower is calculated from the simulated torque and boost curves.

## Presentation

Original vector car artwork adds shaped body panels, metallic shading, reflected glass, detailed lighting, wheel arches, brake discs, calipers, and animated wheels. Twelve body styles with six paint variants each are included. The workshop environment has equipment and lighting; racing adds a sunset sky, illuminated skyline, fencing, track lighting, and road detail.

The supplied screenshots and both race videos have been reviewed. The first video has a silent track; the second includes mixed game audio/music. Engine sounds are original synthesis. Subjective similarity and device latency still need human testing.

Engine sound now blends idle, low, mid and high RPM character continuously, with distinct profiles for all four cars, load/overrun contrast, limiter cuts, turbo/blow-off and upgrade-dependent exhaust/transmission character. Subtle acceleration/shift motion, driven-axle tire smoke and a short finish coast follow the real simulation. Exact finish values are captured before coasting.

## Saves and compatibility

Progress is stored in Godot's `user://driver_v1.json`. Earlier saves are migrated automatically, preserving credits, XP, records, appearance, and the five original upgrade categories. New saves also contain owned cars, separate builds, career progress, and an in-flight wager record.

This remains a playable prototype: no multiplayer, real-money wagering, full 100-race careers, engine swaps, permanent part failures, or commercial release packaging. Purchased mechanical hardware is retained in each car's collection.

## Validation

The racing model now connects engine torque and inertia to a finite clutch, driven-wheel inertia, tire traction, and chassis forces in a shared 240 Hz solver. RPM is not a scripted speed target. The HUD, wheel animation, and original engine audio use the resulting simulation state. F3 displays RPM/ideal road RPM, torque/load, clutch and wheel slip, traction forces, acceleration, boost, and audio underruns.

Read [the current transmission report](validation/TRANSMISSION_REPORT.md) for the new hardware, 204 matched performance runs, source ratios, fixes and verification limits. [The polish report](validation/POLISH_REPORT.md) and [earlier validation report](validation/VALIDATION_REPORT.md) preserve previous phase results. [The model notes](validation/PHYSICS_MODEL.md) explain equations and arcade assistance. The separate fitted reference profile is a calibration fixture; it does not replace dealer-car configurations.

Run the complete repeatable suite using Godot 4.6 and Python 3 (standard library only):

```powershell
./tools/validate_racing.ps1 -GodotPath 'C:\Godot\godot.exe' -PythonPath 'python'
```

The wrapper isolates test saves and caches from your real progress, waits for the Windows GUI executable, and fails on script errors as well as assertion failures. Use `-HeadlessOnly` when graphical playback is unavailable; that omits controls/menu/race-flow/live-audio integration checks. It also runs all transmission comparisons and checks calculated maps against three fixed-RPM strategies. Frozen calibration and independent audio-frequency checks run by default; no reference parameter refit occurs. Logs, JSON results and telemetry CSVs are under `validation/`; integration screenshots go to `.qa/`. Original synthetic audio validation WAVs are included for review. Physical Android/iOS ergonomics and subjective driving/audio fidelity still need device playtesting.

The included `tools/generate_art.py` rebuilds the original SVG artwork without external Python packages.
## Garage and live dyno

The garage emphasizes the active car, actual engine horsepower/torque, effective base grip and running mass, with Upgrades, Customize and Change Car actions. Change Car lists owned vehicles only and previews their saved builds before activation. The upgrade entry screen groups 15 mechanical categories; the existing parts, stages, gearbox configuration, tuning and vehicle test remain the purchase and simulation systems.

LIVE DYNO is available throughout upgrades. Expand it to toggle HP and Nm independently, compare solid installed curves with dashed compatible previews, and read peak changes. Curves are steady full-throttle engine output without nitrous, calculated from full_engine_torque and RPM/7127 horsepower conversion. They are not wheel dyno or transient turbo measurements. Chassis and gearbox upgrades do not fabricate engine-power gains. Back/Return and Escape retain category selection.

Garage and mechanical menus use bounded grids with responsive portrait and landscape presentations. Physical-phone ergonomics and low-end-device performance remain unverified.
## Racing and career

FIND MATCH on the race board recommends an unlocked opponent using simulated results for your current build and the selected event distance. Opponent horsepower, quarter-mile estimate, skill and difficulty are visible before entry. Estimates assume assisted driving; they are not promised results. Career tiers still unlock at driver levels 1, 3 and 5, and the next rival opens after a win. Dealership purchases remain credit-based.

AI now drives the same configured engine and 2–10-speed hardware simulation, with traction recovery, appropriate manual/automatic inputs, reaction variation and small skill-dependent mistakes. Drag builds use an installed transbrake. Free races award XP and progression; fictional cash wagers are the only race income. Duplicate-payment guards and interrupted-stake forfeiture remain. Driver badges show First Win, Five Wins and City Champion from saved progress. The result slip shows launch-input reaction alongside the green-to-finish time.

See validation/CAREER_REPORT.md and validation/rival_test_results.json for AI calibration, verification and remaining playtesting limits.

## Expanded dealership and collection

The dealership now offers twelve fictional vehicles with manufacturer, price band, class and drivetrain filters. It shows factory engine output, real running mass/grip, installed factory transmission and assisted quarter-mile estimates, compared with your active upgraded car. DETAILS expands the technical specifications. Left/right arrows browse cars; Escape closes details.

Eight new original builds add an affordable NA hatch, classic and modern muscle, AWD sport compact, turbo-six GT, high-rev V8/V10 exotics and a purpose-built drag car. New models have distinct physical engine/gearing/chassis data and original vector bodywork. These are stylized 2D assets, not production-licensed models. Existing cars retain their old factory configuration and purchase availability.

EQUIP ON PURCHASE can be switched off to collect a car without changing the active build. Owned vehicles page four at a time in Change Car. New high-end models unlock through driver level; ownership and individual tuning persist. The default 6P is not granted as a free conversion to every new factory gearbox, while previously owned gearboxes remain owned.

Layered vehicle artwork loads on demand with a bounded 32-texture cache. Physical mobile ergonomics and low-end performance still need device testing. See validation/DEALERSHIP_REPORT.md for the factory benchmark table and validation limits.
## Static body and wheel effects

Cars retain their original 2D illustrations. Body pitch, launch compression and subtle idle vibration now move the body separately from wheel anchors. Animated rim highlights, optional rotating spokes and lightweight radial blur read actual driven-wheel angular speed; free wheels follow road speed. Burnout smoke, exhaust pulses and opponent effects follow the same simulation data. Installed tire dimensions appear in garage and race previews.

EFFECTS on the Driver screen or paused-race menu selects Low, Medium or High. Low favors static spokes, fewer rim segments, fewer smoke particles and less background/camera detail. Preferences persist without changing vehicle performance. See validation/VISUAL_EFFECTS_REPORT.md for budgets, tests and the equivalent-axle model's limitations. Physical-phone performance remains unverified.

## Modular customization

Garage > Customize (or the Customize navigation tab) opens the single appearance editor. Choose a category and preview an option, compare it with the installed car, then Buy/Install. Paint and the original rim finishes remain included. Other finishes, wheel designs, sidewalls, calipers, tint, ride height, spoilers, light treatments and original liveries have clear costs. Owned choices reinstall free; Restore Factory keeps your purchases. Every car saves its own appearance and ownership, including migrated old paint/rim choices.

These are cosmetic components. Ride height changes body presentation; mechanical suspension and tire dimensions remain in Upgrades. The dyno, torque, grip, mass and gearing do not gain arbitrary bonuses. Custom spokes, sidewalls, calipers and body layers share the existing physics-driven wheel/smoke/exhaust effects.

Customize reflows to a portrait grid on narrow windows, with a large preview and touch controls. The garage, races, results, upgrades, collection, dealership and driver screens now also have portrait layouts. Device performance and subjective touch ergonomics need physical phone testing. See [customization validation](validation/CUSTOMIZATION_REPORT.md) and [the vehicle asset pipeline](tools/VEHICLE_ASSET_PIPELINE.md) for the manifest contract and adding art without per-car rendering or UI branches. Regenerate source art first with `tools/generate_art.py`, then its layered derivatives with `tools/generate_vehicle_layers.py`.

## Gameplay quality pass

Start in the garage and choose Find a Race. New players default to a $0 wager; free finishes earn XP, while cash requires a winning bet. Results offer Garage, Upgrades, Rematch and Next Race. Garage returns to the actual vehicle hub. Builds, tuning, cosmetics, ownership and prior saves remain compatible.

Upgrade details are hidden by default, with real component comparisons and the existing live dyno. Transmission configuration opens on the selected gearbox family. Locked tuning hardware is identified before adjustment. Portrait race controls adapt to installed manual, sequential, paddle, DCT, automatic and transbrake hardware; desktop keys remain unchanged. DATA/F3 provides drivetrain telemetry.

Menus fit safe-area insets and pointer input follows the same transform. Rotation clears held pedals. Static screens redraw when needed, and car/rival estimates run in bounded slices instead of blocking drawing. See [the quality review](validation/QUALITY_OVERHAUL_REPORT.md), `validation/quality_model_results.json` and the existing suite results for actual performance/progression evidence and device-testing limits.

## Drag facility and race atmosphere

Races share a layered drag strip with asphalt/rubber texture, barriers, grandstands, lighting, a functional tree, starting beams, finish stripe and timing board. The existing careers choose daylight or illuminated night palettes without changing grip or physics. Headlights, brake lights, wheel effects, launch/shift body motion and the restrained camera use live state. Quiet original ambient synthesis and start/foul/finish cues accompany the existing engine, tire, turbo and drivetrain audio.

Staging Assist preserves the previous held start. During countdown, Stage switches to Manual for physical brake/clutch/transbrake release and optional brake-held burnouts. Leaving the beam before green causes a red light, loses the wager and awards no cash, XP or record. Reaction is now measured at beam clearance; results separate ET from reaction while the race clock and historical Best 1/4 Total retain green-to-finish timing. Opponent trap speed is captured at its crossing. Read [the presentation report](validation/RACE_PRESENTATION_REPORT.md) for the beam approximations and test limits. Physical phone performance and subjective sound still require device playtesting. Regenerate original strip layers with `python tools/generate_strip_art.py`.

## Quality-of-life controls

Ctrl+Tab / Ctrl+Shift+Tab switches main sections. Tab / Shift+Tab moves focus; Enter activates it. Mouse Back follows Escape. In Change Car, Left/Right previews owned cars without equipping; in the dealership, Home/End jumps to the first/last filtered car. Clear filters, Discard preview and No wager provide direct undo/reset actions without extra confirmation. See validation/QOL_REPORT.md for all ten improvements.


## Distinct drag-strip environments

Dockside Dragway now races through a detailed sunlit industrial port, Midnight Motorplex uses floodlit grandstands and a cool city skyline, and Redline Park is a warm daylight professional facility with sculpted grandstands and glass VIP suites. Original location artwork, layered distance-driven scrolling, rubbered asphalt, safety walls, drainage, softer smoke/contact shadows and detailed tree lamps bring the cars into the venue. Low effects limits decorative work, and Reduced Motion disables camera shake and speed streaks.

See [the environment overhaul and screenshot review](validation/TRACK_ENVIRONMENT_OVERHAUL.md) for all three tracks at staging, acceleration and high speed, plus finish, Low and portrait views. Run `tests/test_track_environments.gd` in graphical Godot to regenerate the 18 review images; the fixtures deliberately hold speeds/distances for matched visual comparisons. Surface artwork can be regenerated with `python3 tools/generate_track_surfaces.py`; the original PNG panoramas are committed source assets. Physical-phone performance remains to be tested.

## Vehicle motion and racing effects

Sprung-body motion now follows acceleration, braking, weight, drivetrain and suspension hardware, with restrained shift/traction recovery. Tire smoke uses driven-axle contact anchors and slip speed; rim highlights and faint blur follow actual wheel phase while preserving the original wheel art. Exhaust pulses follow RPM/cylinder count, boost and nitrous affect subtle plume presentation, and short backfires are limited to eligible upgraded builds at hot loaded events. Nitrous alone does not create flames.

See [the motion review, screenshots, clips and test results](validation/VEHICLE_MOTION_OVERHAUL.md). `tests/test_motion_feedback.gd` checks the mechanical responses; graphical `tests/test_motion_rendering.gd` captures four vehicle classes, with optional `-- --record` gameplay frames. Low quality and Reduced Motion remain available. Physical-phone performance is unverified.

## Unified gearbox tuning

Tuning & Test Track → Tune → Gearbox shows Number of Gears, Final Drive Ratio and every individual ratio in one scrolling list, with minus/slider/plus controls and live speeds at the RPM limit. Transmission-specific count limits, valid descending ratios, fine final-drive adjustments, existing tuning access rules and per-vehicle/transmission saving use the shared tuning system. Mouse, touch, keyboard and mobile scrolling are supported.

See [the gearbox tuning review and desktop/mobile screenshots](validation/UNIFIED_GEARBOX_TUNING.md). Run `tests/test_unified_gearing.gd` for shared model/save checks and graphical `tests/test_unified_gearing_ui.gd` for input and layout validation.

## Test Track analysis and comparisons

Run data now saves recent tests per vehicle and distance, with A/B time slips, personal-best markers, setup comparisons and overlaid speed/RPM graphs. Drag either graph to inspect synchronized RPM, speed, wheelspin, clutch slip and acceleration. Diagnostic flags identify traction, clutch-slip, limiter and low-RPM exposure without inventing an elapsed-time penalty. Full numeric tuning groups now use the same minus/slider/plus controls as gearing; presets and optimization remain available.

See [the Test Track analysis review and desktop/mobile captures](validation/TEST_TRACK_ANALYSIS.md). `tests/test_run_analysis.gd` validates measured timing, diagnostics, comparisons and persistent history; graphical `tests/test_run_analysis_ui.gd` checks controls and layouts. Recent traces are bounded and compressed in the existing integrity-checked profile; personal-best summaries remain after older traces rotate out. Physical-phone performance remains unverified.


## Racing physics audit

The existing shared 240 Hz drivetrain now supports load-aware turbo pressure, light-throttle automatic shifts and kickdown, engine-matched default converters, and physical clutch/gearbox overload without clipping crankshaft torque. Shift planning shares the benchmark launch procedure and installed nitrous. Existing controls, fixed engine classes, upgrades and saves remain in place.

See the [measured before/after audit](validation/physics_audit/REPORT.md) for 18 factory, upgraded and transmission configurations, including 0–60 mph, 60–130 mph, eighth/quarter-mile times and crossing speeds, shift RPM/duration, traction and coupling diagnostics. All 30 factory estimates were regenerated. Run the headless checks with `python tools/run_regressions.py --godot C:/Godot/godot.exe`, then `python tools/report_physics_audit.py` to tabulate the results. The before snapshot is retained as historical evidence; physical-model limitations and timing conventions are documented in the report.

## Championship difficulty and betting economy

Each class opener is calibrated roughly 0.4 seconds behind that class’s slowest stock car under competent simulated driving. All 30 stock cars are checked against their own opener. Subsequent rivals use progressively stronger real builds; bosses require substantial upgrades, traction and good shifts. Engine classes, race IDs, eighth/quarter/half-mile modes and saved championship progress remain intact.

Bet caps scale by class and round: Class E rises from $2,000 to $50,000; Class S rises from $40,000 to $1,000,000. Purses, finish payments, first-win cash and boss cash bonuses are removed, including old bound race contracts. Trophies, unlocks and XP remain. Free races are available at $0; they do not repair a depleted bankroll.

Upgrade packages now cost base × 1 / 3 / 8, with gearbox tiers extending to ×18 / ×36. Component ladders have wider street/track/race price gaps. Existing owned parts and tiers remain owned and free to re-equip. See [the measured difficulty and economy report](validation/championship_economy/REPORT.md) for stock margins, boss times, caps, prices and the simulated betting-funded career route.
