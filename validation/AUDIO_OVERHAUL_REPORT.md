# REDLINE dynamic audio implementation and validation

## Implemented

The main engine now uses offline-generated PCM banks played by native Godot audio players, mixed with lightweight live mechanical/induction/tire/nitrous effects. The previous continuous EngineVoice synthesis remains a safe fallback when a bank is absent. This is original synthesized audio, not authentic recordings of the named production cars, and not output from engine-sim.

There are 18 engine families, nine absolute source-RPM regions per family, and five layer types: loaded exhaust, unloaded exhaust, loaded intake, unloaded intake and mechanical noise. In total 810 original WAV files occupy approximately 41 MB. Each loop contains whole 720-degree engine cycles. Pressure impulses, bank arrival differences, resonant filtering and periodic noise are generated offline; expensive per-sample core harmonic work is removed from normal GDScript playback.

The source-bank metadata and per-file hashes/author/origin are in `assets/audio/asset_manifest.json` and `assets/audio/engines/bank.json`. External candidate sources, authors, licenses, intended uses and rejection/access reasons are in `assets/audio/source_research.json`. No external recording was downloaded or incorporated. No reference-game audio was copied. No restricted recording was used for training, model development or synthesis.

## Engine character and physics

Profiles distinguish NA/turbo inline fours, high-revving fours, NA/turbo boxer fours, NA/turbo inline sixes, VR6, NA/twin-turbo V6, cross-plane V8, flat-plane V8, supercharged V8, turbo flat-plane V8, V10, NA/turbo flat sixes, and W16. Every roster ID has explicit brightness, intake and mechanical acoustic tuning rather than only a pitch multiplier. SF90 combustion audio stays separate from its energy-delivery-dependent electric whine.

Audio receives actual engine RPM, throttle, load, combustion fraction, clutch, shift state, boost, wheelspin, nitrous delivery, shaft speed and hybrid power. Native source pitch follows engine RPM rather than road speed. Source-region weights sum to unity; extreme crossfade tails are bounded to 0.70–1.42 pitch ratio, with most energy near the closest RPM region. Source playback is phased to a shared engine cycle when a region enters. Gain/pitch transitions are smoothed; no shift resets engine phase.

Exhaust stages/manifolds alter the exhaust filter and resonance/brightness; a fitted intake plenum changes the intake layer. Stroker/compression hardware subtly changes resonance. Actual turbo onset and pressure come from physics; turbo assemblies tune compressor whistle character. Roots and centrifugal units use different whine harmonics. Gear whine is stronger for installed sequential/drag hardware rather than universally increasing with transmission stage. Shift/overrun/BOV events remain gated by real loaded transitions. No new camshaft upgrade or invented cam idle behavior was added.

## Mixing and performance

Player, opponent, mechanical and environmental sources have separate buses with headroom protection, plus a master safety limiter. The native source pool is bounded to twelve slots per vehicle source; ordinary playback uses nearby RPM regions. Opponents use only exhaust layers, attenuate with physical separation, and retire voices when distant. Low quality omits extra mechanical/off-intake layers. Inaudible streams stop. Source resources are cached per current family rather than loading the whole library.

The effects generator stays at 22,050 Hz and retains the existing 55 ms queue. The native engine layer avoids that generator queue; total hardware output latency is not measured. No new native extension, platform DLL or third-party runtime dependency is required.

## Audio testing and previews

Press **F7 in a debug garage/menu build** to open the development Audio Lab. It selects all 30 vehicles, factory/installed/isolated intake-exhaust builds, optional engine-family auditions, manual RPM/throttle/load/boost/clutch/gear, shift/limiter/nitrous states, layer isolation, repeatable RPM sweep/lift, and a real private-simulation acceleration run. Explicit manual-state controls are auditions, not changes to player physics.

Relevant upgrade popups have an optional **Sound preview** action. This opens a compact stock/installed/selected-candidate audition. All configurations are copied, currency and ownership are untouched, and the overlay blocks input to purchasing controls behind it. Close returns to the same upgrade selection and restores layer settings.

## Research and choice

- [Godot AudioStreamGenerator](https://docs.godotengine.org/en/stable/classes/class_audiostreamgenerator.html) documents CPU/latency tradeoffs and recommends lower mix rates or compiled implementations for intensive synthesis. Native prepared loops reduce GDScript work without adding a platform-specific extension.
- [Godot audio buses](https://docs.godotengine.org/en/stable/tutorials/audio/audio_buses.html) and native AudioStreamPlayer support separate mix paths and sample playback.
- [Freesound V8 by overmedium](https://freesound.org/people/overmedium/sounds/651534/) is CC0 but requires login to download; its specific engine is unknown and the clip is neutral blips/idle. [Marcelweiss S63](https://freesound.org/people/marcelweiss/sounds/505321/) and [EwanPenman11 turbo pass-by](https://freesound.org/people/EwanPenman11/sounds/659544/) are additional CC0 candidates, not a matched multi-RPM loaded recording set. Access restrictions were not bypassed.
- [Sonniss GDC](https://gdc.sonniss.com/) and its [current license](https://sonniss.com/gdc-bundle-license/) were reviewed. The bundle was not bulk-downloaded or used for AI processing/training. Exact usable engine layers would require individual file selection and provenance review.
- [Engine-sim](https://github.com/ange-yaghi/engine-sim) was evaluated as an offline option. Its referenced repository is MIT but explicitly not an engineering-accurate simulation; newer release/content terms must be reviewed separately. No engine-sim code, content or binary was copied into REDLINE.
- The procedural engine dataset at https://rdoerfler.github.io/procedural-engine-sounds-page/ was rejected because its CC BY-NC license is unsuitable for commercial game use.

## Validation evidence

- `tools/analyze_engine_banks.py`: all 810 files checked for finite PCM, DC, headroom, energy and loop seam steps. Maximum raw bank peak was about 0.602.
- `test_audio_profiles`: 25,273 assertions covering all 30 vehicles, available banks, RPM regions, pitch ranges, crossfade continuity, correct family assignment and real installed-part acoustic changes.
- `test_dynamic_audio`: native captures for all 30 engines under the same 3,000 RPM loaded/release sequence, bounded native voices, mute and RPM checks. Additional checks cover distant-opponent retirement and missing-bank recovery.
- `test_audio_lab_ui`: desktop/portrait compact sheets, all-vehicle selection, candidate copies, manual RPM, private physics pulls, close behavior and blocked purchasing input behind the modal.
- Existing DSP/fallback, physics, controls, upgrades, fresh-save gameplay, runtime audio synchronization and shutdown checks were also exercised. Individual logs under `validation/` are authoritative.
- Native 30-car captures and objective metrics: `validation/native_engine_*.wav`, `validation/native_audio_metrics.json`. Stock/upgraded V8 and turbo-four RPM sweep/lift clips: `validation/audio_demo/`.

## Remaining quality gaps

Numerical tests cannot establish believable engine timbre. No human listening panel, calibrated speaker/headphone comparison or physical iPhone profiling was performed. The new original synthesis provides differentiated, responsive engine families but is not a verified recording match for each real car, and is not certified release-quality audio.

Cam timing, cylinder deactivation, detailed exhaust plumbing and actual engine ignition/stall states are not simulated by the current game; no fake events were added for them. The existing synthetic crowd/ambient bed remains, rather than new licensed crowd recordings. The current solver exposes one equivalent driven axle, which bounds tire/mechanical spatial detail. More authentic timbres should come from a properly licensed loaded/off-load recording session or individually reviewed recording pack that can replace this bank through the same manifest contract.

### Final recovery/check results

The final targeted runs passed: test_audio_profiles (25,273 checks), test_dynamic_audio (all 30 native banks, source limits, distant-opponent retirement and missing-bank recovery), test_audio_lab_ui (including the actual F7 input path), test_audio (fallback DSP), test_polish, test_runtime, test_controls, test_physics, test_upgrade_studio_ui, test_quality_ui and test_shutdown. Source-bank and native-capture numerical analyses also passed. Native captures peaked below 0.246 before the bus safety ceiling; runtime samples at 30/60/120/144 FPS caps reported zero steady-state underruns and zero physics safety clamps.

The F7 physical-key route and an idempotent preview-close guard were corrected during the final input pass. No confirmation or purchasing action is triggered behind the audition sheet. The final tests were targeted to affected systems; this is not a claim that every unrelated test in the project was rerun after the audio pass.

### Reference sound comparison

LCXM2683.MP4 was freshly decoded locally for numeric review; ten idle/launch/shift/coast/load windows are recorded in current_reference_audio_analysis.json. The mixed track drops by about 20 dB around each sampled manual shift, consistent with the separately observed manual lift/clutch sequence. This is not an isolated engine measurement and does not justify forcing that attenuation or shift duration onto DCT/automatic cars. REDLINE uses its actual combustion retention and engine-load state instead. The spectral peaks were not treated as exact engine firing frequency or a verified tonal match. No protected reference audio is in the game banks.
