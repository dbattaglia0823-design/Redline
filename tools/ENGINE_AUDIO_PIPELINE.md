# Engine audio asset pipeline

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
