# Test Track and performance analysis

Run data now provides persistent A/B comparisons: a complete time slip, setup snapshots, diagnostic flags, overlaid speed/RPM traces and interactive synchronized cursors. The three most recent completed tests are retained for each vehicle and distance. Personal-best ET summaries survive trace rotation. Presets, optimization and the no-stakes practice workflow remain available.

## Visual review

These captures use two actual solver-driven Miata tests with different final drives, launch settings and grip. They are repeatable comparison fixtures, not promised performance targets. Orange is A; blue is B. Green deltas indicate faster times or greater trap speed, orange indicates regressions, and launch RPM changes remain neutral. A star identifies a retained personal best. The PB header continues to show the best valid ET even after its trace ages out.

| Layout | Time slip | Overlaid graphs | Shift data | Numeric tuning |
| --- | --- | --- | --- | --- |
| Desktop | [Image](test_analysis/desktop_slip.png) | [Image](test_analysis/desktop_graphs.png) | [Image](test_analysis/desktop_shift_data.png) | [Image](test_analysis/desktop_launch_controls.png) |
| Portrait | [Image](test_analysis/portrait_slip.png) | [Image](test_analysis/portrait_graphs.png) | [Image](test_analysis/portrait_shift_data.png) | [Image](test_analysis/portrait_launch_controls.png) |
| Compact landscape | [Image](test_analysis/landscape_slip.png) | [Image](test_analysis/landscape_graphs.png) | [Image](test_analysis/landscape_shift_data.png) | [Image](test_analysis/landscape_launch_controls.png) |

The run selectors cycle independently through recent tests for the current vehicle and distance. Analysis reveals the traces and shift data; drag either graph to move both cursors. Traces align at beam release rather than the green signal, so reaction differences remain separate from driving performance. Returning to tuning preserves the selected tuning group. The native result list scrolls vertically and supports mouse and touch.

## Recorded results

The existing solver and staging clocks remain authoritative. The recorder now captures 60-foot trap speed and measured RPM at beam release, alongside 60-foot, eighth and quarter ET/traps, reaction, 0–60, green total, shift RPM, acceleration, wheelspin and clutch-slip samples. Distance splits and trap speeds interpolate between physics frames. Launch RPM interpolates across the release frame. The final trace sample is clipped to the finish; no quarter result is manufactured for an eighth-mile test, and a 0–60 crossing after the finish is omitted.

Each run records transmission, ratios, final drive, configured launch RPM, redline, tire pressure, differential setting, traction-slip target, pedal curve, clutch rate, boost target and launch damping. The results show gearing and launch settings for A and B, plus other numeric setup changes where they differ. These snapshots stay associated with the recorded run when current tuning changes.

Diagnostic flags report observed exposure, not counterfactual time penalties:

- Wheelspin: time above 15% wheelspin under throttle.
- Clutch slip: time above 600 RPM slip while substantially engaged, under throttle and outside a shift; conventional converter slip is excluded.
- Limiter: limiter exposure under high throttle outside a shift.
- Low RPM/load: high-throttle operation below 45% of the RPM limit in second gear or above, with road speed over 5 m/s.

Durations are clipped to beam release and finish. They can overlap and must not be summed as lost ET. Peak acceleration and the synchronized sample readout provide additional context. A faster run can still show more wheelspin if another adjustment improved its overall result; the interface does not invent a causal time saving.

## Persistence and storage

`RunArchive` stores normalized, finite, bounded records in the existing `driver_v1.json` profile. The field is compressed JSON encoded as a string, preserving the existing profile integrity checks and atomic save/backup mechanism. This avoids a checksum-roundtrip problem exposed by large nested floating-point traces. Legacy profiles without telemetry load with an empty history; a plain JSON archive field is also readable.

Each vehicle/distance retains three traces, with up to 180 graph samples and 64 shift events per run. Trace samples are downsampled and quantized for storage; split metrics and diagnostic integrals retain their recorded precision. Current 30-vehicle / two-distance coverage fits within the 192-record safety ceiling. PB summaries retain metrics and setup rather than a permanent full trace. The full-roster stress fixture filled all history slots and round-tripped in a profile well below the existing 4 MiB limit (approximately 0.4 MiB for these fixtures). This is not a worst-case compression ratio or phone memory benchmark.

Red lights are retained as unranked tests and cannot replace a PB. Repeated completion does not append duplicate records. Recording tests does not award credits, XP or career wins. If saving is blocked, the UI reports saving unavailable while keeping the current run in memory.

## Tuning integration

The existing native slider panel now serves Launch, Power, Gearbox, Clutch and Grip. Every numeric row has minus/slider/plus controls and current values. Boost caps are shown for each gear directly. Access rules, integer/continuous steps and mechanical limits continue through the existing tuning API. Edits reach the solver immediately; saving and expensive shift-plan rebuilding finish on release. Vertical touch scrolling, large mobile targets and keyboard controls are retained. Named presets and the optimizer use the same settings.

## Validation

Godot 4.6.3, GL Compatibility, Mesa llvmpipe software rendering, dummy audio:

| Test | Result |
| --- | --- |
| `tests/test_run_analysis.gd` | Passed: 80 checks; split/trap interpolation, finish clipping, post-finish exclusion, immutable frozen records, four vehicle classes, manual/DCT/drag transmissions, tuned ratios and launch settings, diagnostics, A/B deltas, red-light PB rejection, full-roster history bounds, compression and save/reload |
| `tests/test_run_analysis_ui.gd` | Passed: 134 checks; run selection, graph touch scrubbing, every enabled numeric control, desktop/portrait/landscape, visibility, reload and 12 captures |
| `tests/test_tuning_lab_ui.gd` | Passed: 3,879 checks; live practice driving, telemetry, presets, optimizer and no career/economy side effects |
| `tests/test_unified_gearing_ui.gd` | Passed; existing gearbox input, count changes, scrolling and save/load |
| `tests/test_save_recovery.gd` | Passed; profile integrity and recovery |
| `tests/test_advanced_tuning.gd` | Passed: 252 checks |

The regression suites ran in a refreshed disposable project with isolated user data, preserving tracked historical reports. Rendering warnings about unavailable V-Sync and occasional existing ObjectDB-at-exit warnings did not produce script or assertion failures. Real-device ergonomics, thermal behavior and frame-time budgets remain unverified.

Reproduce with a graphical display for the UI test:

```sh
godot --headless --path . --editor --quit
XDG_DATA_HOME=/tmp/redline-analysis-model godot --headless --path . --script tests/test_run_analysis.gd
XDG_DATA_HOME=/tmp/redline-analysis-ui godot --path . --audio-driver Dummy --script tests/test_run_analysis_ui.gd
```

No cloud environment configuration or publication was changed.
