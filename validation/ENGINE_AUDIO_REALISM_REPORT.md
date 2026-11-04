# Engine audio realism and quality pass

Implemented in the existing local REDLINE project. The native looping-voice/live
effects architecture remains; vehicle physics, hardware, prices, saves, progression
and race timing were not replaced or altered by the audio system.

## Implemented

- Thirty vehicle-specific acoustic banks, plus eighteen family fallbacks. Different
  cylinder runner arrivals, pulse widths, exhaust resonances, intake resonances and
  restrained cycle variation replace dependence on family EQ alone. These are
  **original synthesized approximations, not authentic vehicle recordings**.
- Fourteen source RPM regions, only two neighboring regions blended at once, with
  normal source pitch ratios 0.79–1.26. Source RPM derives from actual cycle/sample
  count. Equal-power gains and short envelopes keep pressure layers continuous.
- Exhaust priority and sixteen bounded player slots (eight rival slots) allow RPM
  transitions to retain the important exhaust regions while quieter tails fade.
- Load/intake/overrun blending responds to simulated throttle, delivered load,
  negative engine torque, clutch and combustion fraction. Neutral and loaded states
  no longer use the same throttle-heavy pressure mix.
- Exhaust/filter/EQ, intake, boost/spool, blower, ECU limit, mechanical shifts and
  nitrous respond to installed hardware and simulation state. A turbo-converted
  BRZ retains its own header identity rather than taking the STI's runner pattern.
- Stock shifts do not automatically backfire. Loaded performance-exhaust shifts
  can emit restrained transients; gearbox kinds have different engagement/whine
  levels. Forging alone does not invent a camshaft lope.
- Supercharger whine is more audible and linked to engine speed/actual pressure.
  Turbo release requires pressurized throttle release, and nitrous uses actual
  delivery. Hybrid motor tone follows road speed and actual assist power rather
  than ICE RPM; its reduction/pole order remains an acoustic approximation.
- Source identity clears false shift triggers when swapping preview copies of the
  same car. Initial effects playback waits for vehicle setup, avoiding an empty
  startup buffer and a briefly queued generic engine. Closed audio refuses late
  simulation callbacks that could restart it.
- F7 lab: fixed 240Hz physics idle, neutral throttle/lift, limiter/lift, acceleration,
  stock/installed/upgrade comparisons, layer isolation and WAV recording (20s cap).
  Restart and replay work after pauses/completed pulls. Header/vehicle controls fit
  desktop and phone widths. Advanced flags reset before ordinary upgrade previews.
  Drivetrain/nitrous upgrade auditions use a physical launch/shift run; installed
  nitrous can operate through the same AI/vehicle simulation, not an audio timer.
- 720 unused older-anchor WAVs were moved into the ignored checkpoint, retaining
  originals and retiring 36,573,660 source bytes from the active asset tree. The
  original v1 banks are separately archived. The active manifest has 3,360 WAVs.

## Validation performed

The model suite passed **15,128 assertions**, including source identity, two-region coverage, constrained pitch, load response, rapid-sweep exhaust allocation, forced-induction identity, hybrid pitch, shift gating, preview-source changes and shutdown callbacks.

Nine selected Godot regression scripts passed (see the JSON results), plus
source-bank, native-output and reference-analysis tools. The entire project-wide
validation suite was not rerun. A late preview-detection type-inference error was
corrected; import, lab, model, runtime and shutdown checks passed afterward.

All 3,360 referenced source files passed peak/DC/RMS/seam checks. All thirty cars
have native constant-RPM/load-release captures. Ten representative engines have
longer controlled 3000RPM captures crossing repeated native loop boundaries.
Eight stock/upgraded eight-second acceleration/shift clips use the actual physics
through the lab's AI driver. Steady captures are acoustic fixtures, not vehicle
performance benchmarks. Raw recordings are retained. Listening copies apply only
20ms edge fades, without loudness normalization or pitch alteration.

Maximum measured thirty-car capture peak: 0.2637 linear. Maximum physics-pull peak: 0.5469 linear. Both have headroom below the safety limiter. These levels do not alone prove perceived quality.

Windows native runtime tests at 30/60/120/144 render caps reported zero startup
and steady-state generator underruns, matching audio targets/physics telemetry and
zero physics safety clamps. A cap is not proof of achieved mobile FPS. Lab neutral
physics results matched at 30/60/120Hz update rates. Preview isolation, recordings,
play/restart, mute/close and resource shutdown were exercised. Physical iPhone
performance, OS audio-session interruptions and end-to-end speaker latency remain
unverified.

The supplied LCXM2683 recording was analyzed locally for general timing and mixed
audio energy around launch/lift/shifts. Its first observed shift window drops about
20dB relative to the preceding mix window. Music and other effects prevent using
this as isolated engine loudness or a proprietary synthesis recipe. No reference
audio was incorporated into runtime assets and no exact tonal match is asserted.

## Remaining sound-quality limits

Human listening is still required to judge factory authenticity, convincing rasp,
exhaust body, subtle looping/clicks and subjective mix balance. Spectra and finite
samples are not realism scores. The output remains synthesized; a properly licensed
on/off-load recording session across stable RPM bands would improve authenticity.
The source research manifest records candidate licensing/access constraints. The
new V8 idle candidate is CC BY 4.0 but requires login and lacks a verified matched
engine/RPM set, so it was not downloaded. No restricted preview access was bypassed.
No engine-sim code/assets/output were incorporated or claimed.

Runner delays, resonances, blower orders and the hybrid motor order are documented
acoustic design estimates, not measured OEM formulas. Camshaft hardware, exact
turbo-shaft/motor rotor models, engine start/stall/shutdown and nitrous purge
controls are not present in the existing simulation and were not fabricated as
working physical features. Family synthesis remains a graceful lower-fidelity
fallback when individual assets are unavailable.

## Factory roster capture checklist

All rows passed source/voice coverage and native output checks. Peak is measured
from the controlled 3000RPM/load-release capture, not a real vehicle SPL rating.
No row represents human approval of factory-authentic sound.

| Vehicle | Factory engine | Acoustic family | Native peak |
|---|---|---|---|
| Mazda MX-5 Miata | 1.6L NA I4 | i4_na | 0.234 |
| Honda Civic Si | 1.6L NA I4 | i4_vtec | 0.205 |
| Volkswagen Golf GTI VR6 | 2.8L NA VR6 | vr6_na | 0.222 |
| Acura RSX Type-S | 2.0L NA I4 | i4_vtec | 0.232 |
| Subaru BRZ | 2.0L NA H4 | h4_na | 0.244 |
| Acura Integra Type R | 1.8L NA I4 | i4_vtec | 0.213 |
| Volkswagen Golf GTI | 2.0L turbo I4 | i4_turbo | 0.241 |
| Honda S2000 | 2.2L NA I4 | i4_vtec | 0.217 |
| Toyota GR86 | 2.4L NA H4 | h4_na | 0.264 |
| Nissan 350Z | 3.5L NA V6 | v6_na | 0.242 |
| Toyota Supra Turbo | 3.0L twin-turbo I6 | i6_turbo | 0.209 |
| BMW M3 E46 | 3.2L NA I6 | i6_na | 0.215 |
| Subaru WRX STI | 2.5L turbo H4 | h4_turbo | 0.212 |
| Mitsubishi Lancer Evolution VIII | 2.0L turbo I4 | i4_turbo | 0.211 |
| Honda Civic Type R | 2.0L turbo I4 | i4_turbo | 0.234 |
| Ford Mustang GT | 5.0L NA V8 | v8_cross | 0.228 |
| Toyota GR Supra 3.0 | 3.0L turbo I6 | i6_turbo | 0.223 |
| Chevrolet Camaro SS | 6.2L NA V8 | v8_cross | 0.185 |
| Volkswagen Golf R | 2.0L turbo I4 | i4_turbo | 0.219 |
| Nissan Z Performance | 3.0L twin-turbo V6 | v6_tt | 0.229 |
| Chevrolet Corvette Z06 | 5.5L NA V8 | v8_flat | 0.194 |
| Nissan GT-R NISMO | 3.8L twin-turbo V6 | v6_tt | 0.152 |
| Audi R8 V10 Performance | 5.2L NA V10 | v10_na | 0.239 |
| Ford Mustang Shelby GT500 | 5.2L supercharged V8 | v8_super | 0.230 |
| Dodge Challenger SRT Hellcat Redeye | 6.2L supercharged V8 | v8_super | 0.203 |
| Porsche 911 Turbo S | 3.8L twin-turbo H6 | h6_turbo | 0.138 |
| McLaren 765LT | 4.0L twin-turbo V8 | v8_flat_tt | 0.220 |
| Ferrari SF90 Stradale | 4.0L hybrid twin-turbo V8 | v8_flat_tt | 0.162 |
| Dodge Challenger SRT Demon 170 | 6.2L supercharged V8 / E85 | v8_super | 0.214 |
| Bugatti Chiron | 8.0L quad-turbo W16 | w16_tt | 0.189 |

## Files and use

- F7 → Audio Lab → select car/build/mode → Play. Record WAV saves a bounded audition.
- `validation/audio_listening/`: 18 listening copies (ten steady and eight pulls).
- `validation/audio_demo/`: raw physics-pull captures; older legacy Evo clips remain
  outside this pass's eight-clip comparison set.
- `validation/audio_steady/`: raw repeated-loop fixtures for the ten example engines.
- `validation/native_engine_<id>.wav`: thirty raw load/lift captures.
- `validation/audio_quality_results.json`: levels and analysis scope.
- `validation/engine_audio_realism_results.json`: current selected regression results.
- `assets/audio/asset_manifest.json` and `source_research.json`: provenance/licensing.
- `tools/ENGINE_AUDIO_PIPELINE.md`: rebuild, import, testing and capture workflow.
