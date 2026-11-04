# Racing feel, sound and shifting polish

The validated 240 Hz engine/clutch/tire/chassis solver is preserved. This pass improves input response, sound character, paddle requests, and presentation; existing cars, upgrades, saves, garage, dealership and progression remain compatible.

## What changed

- **Throttle:** dealer-car response constants are now 28–38 ms, with a modest response improvement from engine upgrades. Torque responds on the next solver step; inertia and drivetrain load still determine RPM. Untuned/custom configurations retain the previous 55 ms default, including the frozen reference fixture.
- **Paddles:** the first tap selects its gear immediately. One extra tap can wait for the current torque cut to finish; further same-direction taps coalesce into that one request. An opposite tap cancels it. Pause, focus loss, reset and finishing clear pending requests. Wheel-speed over-rev protection is checked again when executing a pending request. The UI distinguishes accepted, queued, cancelled, protected, early, late, traction and manual-clutch shifts.
- **Transmission upgrades:** the existing 160/125/90/55 ms torque-cut settings remain. Faster upgraded clutch engagement makes their recovery differences more noticeable. There is no instantaneous engine-RPM assignment.
- **Original engine synthesis:** continuous-phase idle/low/mid/high harmonic blends; four supported vehicle profiles (compact I4, street I4, smooth I6 and V6); load-dependent intake/exhaust filtering; quieter closed-throttle overrun; redline fuel cuts; bounded shift transients; boost-dependent whistle/blow-off; upgraded-exhaust lift pops, transmission whine, tire and nitrous effects. Engine/exhaust/turbo/transmission upgrades affect timbre as well as the sounds caused by their actual performance changes. All signals come from drivetrain state. No reference recordings or protected samples are reused.
- **Feedback:** a short tachometer/road-follow filter, gentle chassis pitch, bounded launch/shift shake, smoke from the actual driven axle that fades after traction returns, loaded-shift exhaust flashes, and a 0.55 s physical coast before showing results. Finish time/speed are captured at the line and remain frozen during coasting. The finish stripe now meets the front bumper at the timing point. Buttons and HUD remain outside the camera transform.
- **Shift guide:** F4 toggles guidance. Launch wheelspin/open-clutch revving no longer triggers a misleading perfect-shift cue; a late-shift reminder remains visible above the ideal window. Manual paddle input remains available. F3 retains physical telemetry.
- **Windows keyboard fix:** native testing exposed virtual key events with logical E/P but an unrelated physical scan code. The controls now prefer recognized physical bindings and otherwise use the logical key. Press/release and key-repeat behavior remain tested.

## Measurements and regressions

| Controlled measurement | Previous pass | Current pass |
| --- | ---: | ---: |
| Kaze stock throttle to 90% | about 127 ms | 75 ms |
| Kaze engine-tier-3 throttle to 90% | — | 62.5 ms |
| Stock / race gearbox clutch to 90%, same road state | — | 275 / 121 ms |
| Kaze stock quarter, canonical launch/shift strategy | 13.342 s / 109.68 mph | 13.219 s / 109.85 mph |
| Kaze all-tier-3 quarter, same strategy | 10.025 s / 151.53 mph | 10.001 s / 151.61 mph |
| Fitted reference replay quarter | 18.444 s / 74.92 mph | unchanged |

The supplied reference slip is **18.415 s at 75 mph**. Its replay still has **0.835 mph speed RMS error**, **103 RPM loaded gear-2/3 RMS error**, and up to **593 RPM launch error**. Its unknown vehicle parameters and analog inputs remain estimates; this is calibration on that recording, not independent recovery of the original physics. Dealer cars are different vehicles and are not expected to run the reference car's time.

The source audio mix drops about **20.1 dB** and **19.7 dB** across the two measured manual-shift windows. High-RPM mix peaks around **430–440 Hz** are consistent with a prominent second firing harmonic at the displayed four-cylinder RPM; that correspondence is an inference. Music and other mixed sounds prevent exact engine isolation. The reference's manual RPM undershoot/recovery is longer than the chosen paddle torque cuts and is not forced onto them. Measurements and timestamps are in `reference_audio_analysis.json` and `reference_shift_observations.json`.

**All automated suites passed:** 19,501 physics assertions, 1,484 additional response/paddle/presentation checks, all-eight-upgrade tests, stock/max-build stress tests on four cars, custom gearing, keyboard/mouse/multitouch and virtual-key tests, bot contracts, menus, full race/save/payout flow, and frozen reference comparisons. Timestamped paddle requests and physics agree at 30/60/120/144 caller FPS. Presentation checks confirm that effects do not change physical telemetry, pause freezes them, and smoke allocation is bounded at 48.

Audio is deterministic across buffer chunks. Four/six-cylinder firing frequencies measure **100/150 Hz at 3000 RPM**. The dynamic audio test peaks at **0.421 PCM**, with a largest adjacent-sample change of **0.199** and evolving-physics pitch-tracking error of **82 RPM**. These are waveform/telemetry checks, not listening scores. All eight stock/built profile snapshots differ and remain finite/unclipped. Continuous stock/built race-audio demos also pass, including real launches, shifts and coast; their peaks remain below 0.512 PCM. Live graphical runs recorded **zero startup and sampled steady-state audio underruns** at four 30–144 FPS caps on this PC. The output queue remains 55 ms; speaker/device latency was not measured.

A native Windows pass completed a quarter with a keyboard paddle and an on-screen mouse paddle, verifying actual gear/clutch/torque transitions, pause/resume and the result slip. It used test-only automatic throttle and disabled focus auto-pause because the automation surface changes foreground focus; normal focus clearing is tested separately. Its late shifts produced 16.714 s at 76.01 mph, so it is an input/integration check, not a calibrated performance comparison. Method/source snapshots and results are retained under `validation/`.

## Review and remaining limits

Run `tools/validate_racing.ps1` for the repeatable suite. Listen to `race_audio_kaze_stock.wav` and `race_audio_kaze_built.wav` for continuous original synthesis from real simulation, or the eight `profile_*` WAVs for controlled equal-RPM/load snapshots. WAVs contain raw DSP before the game's -7 dB output gain. Their automated driving strategy differs slightly from the canonical benchmark.

The final package was extracted without Godot caches: fresh import, physics, polish checks and graphical controls all passed again. See `delivery_verification.json`.

Human playtesting is still required to judge enjoyment, perceived shift timing, speaker/headphone tonal balance, and whether this synthetic sound is comparable in quality to The Strip. No claim of subjective audio parity is made. Actual phone touch/audio/performance, low-end hardware, and output-device latency remain unverified. The first reference clip's audio is silent, and the second is mixed with other sounds. The prior launch discrepancy and simplified tire friction, turbo model and launch assistance remain documented in `PHYSICS_MODEL.md`.
