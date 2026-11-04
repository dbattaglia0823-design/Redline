# Engine audio asset pipeline

## Current v2 production workflow

The existing native-loop/live-effects architecture is retained. The bank now has
30 vehicle-specific acoustic designs plus 18 family fallbacks. These are original
synthesized pressure-pulse/resonator loops, **not authentic engine recordings**.
`assets/audio/engine_designs.json` contains reviewed design approximations:
cylinder runner arrival delays, pressure-pulse width, exhaust resonances, intake
resonance and restrained cycle variation. They do not change vehicle physics.

```
python tools/generate_engine_audio.py --vehicles
python tools/analyze_engine_banks.py
```

For a focused Mustang/Evo iteration without rebuilding every family:

```
python tools/generate_engine_audio.py --families "" --vehicle-ids mustang,evo
```

Import with Godot, then run `test_audio_realism`, `test_audio_profiles`,
`test_dynamic_audio`, `test_audio_steady_loops`, `test_audio_lab_ui`, `test_audio`,
`test_polish`, `test_runtime` and `test_shutdown`. These cover objective behavior,
not subjective realism. `export_dynamic_audio` captures four stock/upgraded
physics pulls; `tools/analyze_audio_quality.py` creates diagnostic metrics and
listening copies with only 20ms file-edge fades. It does not normalize loudness.
Never apply listening-copy fades to raw diagnostic captures or runtime loops.

The fourteen 650–11625 RPM anchors have ~25% spacing. Only two adjacent regions
blend, using equal-power gains; normal operating pitch ratios remain within
0.79–1.26. Every source RPM is calculated from the actual cycle/sample count.
Per-vehicle core banks survive forced-induction conversions: a turbo BRZ retains
its own equal-runner acoustic identity rather than acquiring the STI's unequal
header rumble. Family override is an audio-only development control.

Player source count is bounded at 16 including fading regions; rivals use 8 and
exhaust layers only. Exhaust allocation takes priority over auxiliary tails.
Low quality omits optional mechanical/intake-off loops. Wave assets load on
demand; source switches retire cached wave references. Native filters/EQ change
exhaust/intake character while engine RPM comes from the drivetrain. Gain/RPM
envelopes are short smoothing filters, not independent engine animations.

Initialization waits for a configured vehicle before priming the effects stream.
Shutdown refuses later physics callbacks. Source identity prevents false shift
events when switching between copies of the same vehicle for upgrade previews.
Stock street shifts no longer generate generic exhaust pops. Performance-exhaust
transients, supercharger whine, turbo release, nitrous and gear whine retain
simulation/hardware gating. Electric assistance uses actual hybrid power and a
road-speed acoustic order estimate, not ICE RPM. Precise motor gearing/pole
counts, exhaust gas dynamics and turbo shaft speeds are not simulated acoustically.
Forged internals do not invent a camshaft loping idle; no adjustable camshaft
component currently exists.

F7 opens the development lab. Physics idle, neutral throttle/lift, neutral limiter,
and acceleration run at 240 Hz independent of rendering. Restart and Play support
repeating completed runs. Record WAV saves up to 20 seconds, then detaches its
recording effect. Editor runs save in `validation/audio_auditions`; packaged debug
runs use writable user data. Close also saves/stops an active recording. Basic
upgrade sound previews remain compact and do not expose developer controls.

`tools/prune_engine_banks.py` audits stale generator files; `--apply` moves them
into the ignored checkpoint rather than deleting them, and updates the asset
manifest. This pass retired 720 unused old-anchor WAVs (36,573,660 source bytes).
The active manifest contains 3,360 WAVs. Original v1 banks are also archived at
`checkpoints/audio-realism-20261104/original_banks.zip`.

Listening and physical-device interruption/latency testing remain necessary.
The historical workflow below describes the first family-only bank pass.

1. `tools/generate_engine_audio.py --families v8_cross,i4_turbo` rebuilds the two representative prototype families. Omit `--families` to rebuild all 18 banks. This is original procedural pressure-pulse/resonator synthesis, not recordings or engine-sim output. Python requires NumPy.
2. Run `tools/analyze_engine_banks.py`. Import the project with Godot after changing WAV files.
3. Run native `tests/test_dynamic_audio.gd` and `tests/test_audio_lab_ui.gd`, then the existing runtime checks. `tests/export_dynamic_audio.gd` exports real-time stock/upgraded sweep/lift clips. The project validation PowerShell script includes the new model and UI checks.
4. Review audio by listening; numerical acceptance does not certify realistic sound.

`assets/audio/engines/bank.json` maps family to source RPM rows and layer paths. Each source RPM is calculated from the actual integer sample/cycle count. Loops are mono PCM16, 22,050 Hz. The runtime duplicates stream resources locally and sets loop bounds from decoded duration, retaining phase and constrained pitch across regions. No audio stream data is modified globally.

Replacing a layer with a recording requires verified model/configuration, stable measured source RPM, compatible loaded/off-load conditions, seamless edit, gain/DC/headroom checks, lawful source access and an entry in asset_manifest.json with author/license/attribution and processing details. Review source_research.json for candidates not imported. Do not infer that a public preview authorizes bypassing an authenticated original download.

EngineAudioProfile.resolve uses actual installed parts and roster engine layout; it contains per-vehicle acoustic tuning. EngineLoopPlayer handles bounded native streams and filters. EngineVoice.next_effect_sample supplies lightweight live effects; its full original synthesis remains fallback. EngineAudio coordinates preview isolation, rival attenuation and four audio buses. AudioLab is F7/debug-only for advanced testing; compact upgrade auditions work separately.

## Quick use

- F7 in a debug garage/menu opens Audio Lab; Escape or Close returns.
- Sound preview in engine, intake/exhaust, induction, ECU/nitrous and drivetrain upgrade details auditions copies of the selected build.
- Stock/upgraded listening clips are in validation/audio_demo/. No human listening result is asserted by this pipeline.
