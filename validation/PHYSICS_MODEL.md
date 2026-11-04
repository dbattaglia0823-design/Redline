# Racing model and evidence boundaries

## Connected simulation

`scripts/drivetrain.gd` is the single model used by the player, bots, offline tests, and calibration. Units are meters, seconds, kilograms, newton meters, and radians per second internally; the public RPM field and HUD are conversions of engine angular velocity. `step()` accumulates caller time into 1/240-second steps. Gameplay calls it from Godot's 120 Hz physics callback, independently of drawing.

The torque curve is an original piecewise approximation: net naturally aspirated torque is 60%, 80%, 95%, 100%, 96%, 90%, 82%, and 25% of configured peak torque at normalized RPM positions 0, .15, .35, .55, .75, .90, 1.0, and 1.15. It is not a recovered manufacturer dyno curve. Horsepower is calculated as torque times RPM / 7127, including steady boost; transient boost can produce less power than that displayed peak.

Throttle has a configurable exponential response: 32/28/38/30 ms for Kaze/Nori/Aster/Vanta, divided by `1 + engine_stage * 0.08`. Custom configurations retain the previous 55 ms default, as does the frozen reference fixture. These are original responsiveness choices, not measured original-game parameters. Engine combustion torque, idle governor, RPM-dependent friction/pumping losses, nitrous, and bounded paddle rev matching act through engine inertia. Positive transmitted power includes an approximate 10% drivetrain loss. There is no commanded RPM ramp or speed-from-RPM assignment in normal simulation.

Each step solves two coupled constraints with finite impulses:

- Engine to driven wheels: engine angular speed equals driven-wheel angular speed times gear ratio and final drive when the clutch can transmit the required torque. Clutch impulse is bounded by installed clutch capacity times engagement times step duration.
- Tires to road: tire peripheral speed equals chassis speed when the required impulse is within the tire traction limit. Otherwise the driven wheels spin independently and apply only the bounded tire force to the chassis.

The clutch/wheel impulse equations include engine inertia, driven-wheel inertia, mass, tire radius, and overall ratio. Four projected solver iterations handle saturation. Chassis speed integrates tire force minus aerodynamic drag, rolling resistance, and service brakes; distance uses trapezoidal integration. Drag is `0.5 * 1.225 * CdA * speed^2`. Rolling resistance is `mass * 9.81 * coefficient`. Gear kinematics remain exact: locked RPM is `speed / tire_radius * gear_ratio * final_drive * 60 / (2*pi)`. Actual RPM can differ during clutch slip or wheelspin.

Fuel-cut hysteresis starts at configured redline and restores fuel 160 RPM below it. The emergency 125%-redline safety bound is not the normal limiter; all tested catalog runs must record zero safety clamps. Invalid nonfinite inputs are rejected. Single caller deltas over one second are rejected rather than creating a catch-up spiral.

## Deliberate driving assistance and limits

Paddles operate a finite clutch and bounded engine rev matcher. Stock torque interruption lasts 160 ms; gearbox tier three reduces it to 55 ms. The selected gear changes immediately, but engine RPM and acceleration do not jump. Unsafe over-rev downshifts are rejected using both driven-wheel and road speed. Q selects neutral below first gear. Manual Shift always opens the clutch.

Clutch engagement ramps at `8 + gearbox_stage * 2` per second. Explicit player requests may latch one further shift while the current torque cut completes. Repeated equal requests coalesce; an opposite request cancels it. Protection is checked again at execution; pause, focus loss, finish and reset clear the latch. AI/calibration retain the direct `shift()` API. The shift guide requires a coupled clutch and less than 10% positive wheel slip; its late reminder continues above the perfect-shift scoring window. This is an assistance heuristic, not a full optimal-power shift calculation.

An automatic launch/anti-stall controller ramps clutch engagement based on engine and road RPM. Staging holds the chassis while allowing engine dynamics. These are arcade assistance choices to support paddle driving. There is no stalling/restart procedure, clutch heat, clutch wear, suspension, differential simulation, individual wheel dynamics, or full tire slip curve. Tire grip is an effective driven-axle coefficient with approximate acceleration load transfer; it is not a measured tire coefficient or an axle-weight solver. Brakes are chassis forces bounded by effective tire grip; there is no ABS/lockup model or reverse driving.

Turbo uses RPM/throttle-dependent target boost and exponential spool/decay, not a thermodynamic exhaust/turbo model. Upgrade onset values 1700/2400/3200 RPM follow the supplied turbo menu. Free-rev boost is an arcade approximation and should not be interpreted as accurate unloaded turbo behavior. Nitrous adds engine torque only while actually spraying with full throttle, adequate road speed, engaged clutch, no shift/fuel cut, and released brakes. Duration drains only during spraying.

## Upgrade connections

| Upgrade | Physical effect |
| --- | --- |
| Engine | +14% torque per tier; compatible clutch capacity; quicker throttle response |
| Exhaust | +6% torque per tier; compatible clutch capacity |
| Turbo | +0.18 bar per tier, distinct onset/spool behavior |
| Tires | +0.095 effective driven grip per tier; increased brake grip |
| Weight | -65 kg per tier, with a 350 kg lower bound |
| Gearbox | Shorter torque interruption, faster engagement, +15% clutch capacity per tier |
| Brakes | +18% service-brake force per tier, subject to grip |
| Nitrous | +1.5 s bottle capacity and +6 percentage points torque addition per tier |

Existing dealer torque, mass, grip, saves, stage arrays, and public simulation methods remain compatible. No fitted reference profile is silently applied to dealer cars.

## Audio and HUD

`engine_voice.gd` synthesizes original exhaust harmonics with continuous firing/crank phases. Firing frequency is actual RPM / 60 times half the cylinder count. Audio receives actual throttle, transmitted clutch load, clutch engagement, boost, fuel-cut state, tire slip, nitrous, and shift serial. Pitch smoothing has an approximately 8 ms time constant; a 55 ms output queue replaces the former 120 ms queue. Load and clutch affect intensity/filtering, not an invented RPM. Fuel cuts attenuate combustion, actual shifts trigger transients, and boost-release hysteresis handles gradual throttle closure.

Four unity-sum RPM-band weights smoothly change harmonic balance across idle/low/mid/high ranges. Continuous carriers avoid loop seams. Compact/street I4, I6 and V6 profiles alter bass, upper harmonics, pulse character and intake balance; engine/exhaust/turbo/transmission stages modify those features and related effects. Closed-throttle negative torque adds overrun character. Pop and shift envelopes have smoothed attacks; unloaded low-RPM neutral taps do not produce loaded exhaust pops. These are original artistic profiles, not measured acoustic manifold models. The game output gain is -7 dB; validation WAVs retain raw DSP levels.

HUD RPM/speed/gear use the same vehicle state. Driven-wheel animation uses actual wheel angle; free wheels use road distance. F3 exposes engine and ideal road RPM, torque/load, clutch slip, wheel slip, traction force/limit, acceleration, boost, and audio underruns. Acoustic sample tests do not establish speaker latency or subjective similarity to The Strip.

`race_feedback.gd` reads the simulation and never writes it. Analog RPM, speed-strip and world-follow filters use 22/35/24 ms constants; numeric RPM/speed remain direct readings. Tiny pitch and bounded launch/shift shake affect the world/car only. Smoke is capped at 48 particles and starts at the driven axle. F4 controls optional shift guidance. After crossing, the simulation coasts for 0.55 s before results; interpolated line-crossing time and speed are frozen, so this presentation interval does not change the recorded result. Live timing still includes reaction from green; calibration separately subtracts the reference reaction.

## Expanded transmission and hardware model

`transmission_catalog.gd` defines independent 2–10-speed assemblies. Each carries ratios, mass, efficiency, input torque rating, type-specific shift minimum and control behavior. Original curb weights already include a 50 kg gearbox; replacements apply only their mass difference. Original 6P gearing and stage 0–3 behavior remain unchanged. Other types gain at most 0.003 efficiency per stage, bounded at 0.98; catalog baseline efficiencies and masses are estimates. Ratios determine kinematics, never an acceleration multiplier.

`vehicle_parts.gd` stores parts and prerequisites separately from legacy stage arrays. Gearbox stages and clutch/converter/controller/cassette fitments are owned per assembly. Engine/chassis parts remain per car. Every configuration resets from immutable vehicle data before applying modifiers. ECU rev-limit increases need mechanical headroom from internals. Fuel and engine-support limits bound advanced-build torque, including nitrous. Tall tires change wheel-to-engine RPM and leverage as well as grip. Grip additions diminish with existing tire stages. Straight-line suspension changes effective driven-axle load transfer; this is not a cornering/suspension geometry simulation.

Converter automatics retain the existing engine, wheel, tire and road solver with an additional 0.12 kg m² turbine rotor. Pump capacity scales with pump angular velocity squared and selected stall speed; converter stall is a nominal specification under a reference engine load, not a forced RPM target. Stall torque ratio decays with speed ratio, with output power bounded below input power. For pump speed `wp`, turbine speed `wt`, multiplication `M`, engine inertia `Ie` and turbine inertia `It`, the fluid impulse is bounded by `2*abs(wp-M*wt)/(1/Ie+M*M/It)`. The independent passivity test checks kinetic energy cannot increase through the fluid coupling alone. Converter heat comes from lost rotor energy; a transbrake dissipates held output power. Rotor/gear/speed constraints remain finite rather than assigning speed from engine RPM.

Modern converters ramp lockup with adequate turbine speed in second and above. A finite friction impulse joins the rotors; once locked and within pack capacity their combined inertia participates directly in the existing coupled solver. Overload allows renewed slip. Drag converters remain unlocked. This lumped model omits OEM fluid maps, planetary-member dynamics and individual clutch packs. Gearbox efficiency is applied once as torque loss while coupled; converter slip adds its own physical losses.

Drag, DCT and modern converter shifts retain nominal 60%, 35% and 25% combustion respectively, through finite pack capacity; manual/sequential interruptions and actuator synchronization differ. H-gate input requires clutch and a valid target; without an ECU the driver is responsible for lifting and rev matching. Existing anti-stall launch assistance is retained as an arcade approximation. Transbrake is installed hardware and can hold only first below 0.5 m/s. Brake holding at rest includes incoming tire force, allowing service brakes to resist converter creep.

`shift_planner.gd` integrates predicted acceleration using engine curve, ratios, converter, torque rating, traction, drag, mass, shift interruption and inertia. It then runs four bounded full-solver quarter-mile candidates with physical staging. The static seed and blends toward a limit derived from the particular engine's redline compete by elapsed time; it does not impose one universal RPM or promise a global optimum. Modern/drag controller logic follows the resulting per-gear map with slip guards and dwell. Manual overrides require a race controller. Cache keys include base vehicle data, all stages, installed gearbox/parts and tuning. Maps assume a level quarter-mile without nitrous; different launch conditions, distances, temperatures or throttle strategies may require tuning.

Engine and transmission temperatures evolve from power/pack-slip/fluid losses and cooling toward thermostatic baselines. Engine torque derates above 110°C. Race-local overload/heat wear lowers available torque/pack strength; reset starts a fresh run. The coefficients are gameplay estimates, not measured materials data, and there is no persistent damage or repair economy. Original quarter-mile regression temperatures stay below derating, preserving previous balance.

Audio now reads `combustion_fraction` for partial automatic/DCT cuts and `nitrous_delivery` for the actual progressive flow. Superchargers use a continuous belt-whine carrier and do not arm the turbo blow-off event. Continuous engine phases and existing profile synthesis remain intact. The F3 overlay adds turbine speed, converter slip and thermal/wear telemetry.

## Calibration evidence

`reference_observations.json` contains direct manual HUD/time-slip readings and their stated display/reading uncertainty. `reference_profile.json` contains assumed/fitted physical values and estimated inputs used only by `tests/run_calibration.gd`. Neither file is an original-game specification. The fit is nonunique: vehicle mass, radius, inertia, drag, torque, traction and analog control levels cannot be separately recovered from this footage.

The frozen replay starts at the visible clock zero, holds the clutch through the observed 0.908 s reaction, approximates a launch lift and first-gear throttle, and includes estimated clutch/throttle interruptions. See the replay source for the exact timestamped schedule. The same schedule and supported hardware values are applied to the preserved pre-change model for comparison. The legacy model ignored several now-supported parameters, including inertia and driven-wheel state. Parameter sweeps are retained as calibration history; normal validation does not refit them.

Reference shifting uses the human's manual clutch/interface. The observed RPM undershoot during those changes is not imposed on automatic paddles; ratio settling, finite torque interruption, and rev matching are verified separately. Further untouched footage with a known car/build and visible controls is required for independent fidelity validation.
