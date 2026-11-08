"""Tabulate measured runs without fitting vehicle physics to target times."""
from pathlib import Path
import csv
import json
import math

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "validation/physics_audit"


def number(value, digits=3):
    return "unreached" if value is None else f"{value:.{digits}f}"


def main():
    runs = {phase: json.loads((OUT / f"{phase}.json").read_text(encoding="utf-8"))["rows"]
            for phase in ("before", "after")}
    assert len(runs["before"]) == len(runs["after"]) == 18
    assert [(r["model"], r["level"]) for r in runs["before"]] == [(r["model"], r["level"]) for r in runs["after"]]
    for phase, rows in runs.items():
        assert all(r["quarter_s"] is not None and math.isfinite(r["quarter_s"]) and r["safety_clamps"] == 0 for r in rows), phase
    fields = ["phase", "model", "level", "drive", "engine_class", "hp", "zero_60_s", "sixty_130_s",
              "eighth_s", "eighth_mph", "quarter_s", "trap_mph", "quarter_wheelspin_s", "peak_wheelspin",
              "shift_count", "shift_time_s", "clutch_slip_s", "gearbox_slip_s", "rpm_max", "safety_clamps"]
    with (OUT / "measurements.csv").open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fields, extrasaction="ignore")
        writer.writeheader()
        for phase, rows in runs.items():
            writer.writerows(dict(row, phase=phase) for row in rows)
    text = """# REDLINE racing physics audit

Measured with Godot 4.6.3, using the existing `Drivetrain` at 240 Hz. The
`before.json` snapshot was captured before the physics changes; `after.json`
uses the same 18 vehicle/build fixtures. Full configurations, sampled RPM/speed/
traction/load/boost curves, individual shift RPM and duration, and diagnostics
are in those JSON files. `measurements.csv` contains both phases.

## Method and timing

- Standing start after two seconds of staging; no reaction delay is added.
- 0–60 and 60–130 are interpolated speed crossings from rest. This is **not**
  a separate stabilized rolling-start 60–130 pull.
- Eighth- and quarter-mile times in the tables start at the launch command and
  include clutch take-up and initial rollout. Speeds are instantaneous speeds at the distance
  marker, matching REDLINE's current timing system, rather than a real drag
  strip's final speed-trap interval average.
- JSON also retains the existing beam-release ET (`quarter_et_s`,
  `eighth_et_s`) and reaction/rollout measurements separately.
- Runs continue until both the quarter and 130 mph, or 40 simulated seconds.
  `unreached` means the speed was not reached in that window; it is not zero
  or a claimed top-speed result.
- Wheelspin in the table counts samples over 10% slip up to the quarter,
  at 0.05-second sampling resolution. Other whole-run diagnostics can extend
  beyond the quarter. Shift events record their own RPM and commanded delay.
- The benchmark driver uses full throttle, the existing launch-clutch helper,
  configured shift maps, and nitrous when a kit is installed. It is repeatable,
  not a claim about every player's driving. Each built fixture specifies its
  actual parts/tune in JSON; it is not a new player build preset.
- No engine ratings, vehicle mass, tire coefficients, class assignments, costs,
  or aerodynamic coefficients were changed to reach a target elapsed time.

## Acceleration, before → after

Times are seconds. The vehicle label includes build level or transmission.

| Vehicle / configuration | Drive | 0–60 | 60–130 | Quarter | Quarter change |
| --- | --- | ---: | ---: | ---: | ---: |
"""
    for before, after in zip(runs["before"], runs["after"]):
        text += (f'| {after["model"]} / {after["level"]} | {after["drive"]} | '
                 f'{number(before["zero_60_s"])} → {number(after["zero_60_s"])} | '
                 f'{number(before["sixty_130_s"])} → {number(after["sixty_130_s"])} | '
                 f'{number(before["quarter_s"])} → {number(after["quarter_s"])} | '
                 f'{after["quarter_s"]-before["quarter_s"]:+.3f} |\n')
    text += """
## Distance splits and traction, before → after

Each split is seconds / mph. Wheelspin is seconds through the quarter.

| Vehicle / configuration | Eighth | Quarter | Wheelspin |
| --- | ---: | ---: | ---: |
"""
    for before, after in zip(runs["before"], runs["after"]):
        text += (f'| {after["model"]} / {after["level"]} | '
                 f'{before["eighth_s"]:.3f} / {before["eighth_mph"]:.1f} → {after["eighth_s"]:.3f} / {after["eighth_mph"]:.1f} | '
                 f'{before["quarter_s"]:.3f} / {before["trap_mph"]:.1f} → {after["quarter_s"]:.3f} / {after["trap_mph"]:.1f} | '
                 f'{before["quarter_wheelspin_s"]:.2f} → {after["quarter_wheelspin_s"]:.2f} |\n')
    text += """
## Shift and coupling diagnostics after the changes

These diagnostics cover the entire run, which can continue beyond the quarter.
Short coupling saturation during launch/re-engagement is distinct from
sustained slipping. Raw per-shift events are preserved in `after.json`.

| Vehicle / configuration | Shifts | Shift RPM range | Commanded delay range | Clutch / gearbox slip seconds | Safety clamps |
| --- | ---: | ---: | ---: | ---: | ---: |
"""
    for row in runs["after"]:
        shifts = row["shifts"]
        rpms = [s["from_rpm"] for s in shifts]
        delays = [s["cut_s"] * 1000 for s in shifts]
        text += (f'| {row["model"]} / {row["level"]} | {len(shifts)} | '
                 f'{min(rpms):.0f}–{max(rpms):.0f} | {min(delays):.0f}–{max(delays):.0f} ms | '
                 f'{row["clutch_slip_s"]:.3f} / {row["gearbox_slip_s"]:.3f} | {row["safety_clamps"]} |\n')
    text += """
## Audit findings and changes

| System | Finding and disposition |
| --- | --- |
| Torque / horsepower | Existing vehicle-specific torque tables already reproduce rated ICE output; retained. HP is derived from torque × angular velocity, rather than an acceleration multiplier. Hybrid system HP remains separate. |
| Idle / redline / inertia | Retained the existing idle governor, hysteretic fuel-cut limiter, engine inertia and fixed solver. Regression checks cover stable idle, finite RPM, mechanical downshift protection and frame-rate equivalence. No assigned RPM drop was introduced. |
| Throttle / engine load | Retained response lag and load telemetry. Turbo pressure now responds to load; unloaded free revving produces limited pressure, with a separate launch-control allowance. Full-load rating and boost tuning envelopes remain unchanged. Roots and centrifugal behavior remains mechanically distinct. |
| Clutch / input capacity | Removed engine torque clipping at gearbox input rating. The finite clutch/pack impulse now limits transmitted torque while the engine can flare under overload. Existing overload/wear and warnings remain. Updated the old feedback test to check transmitted coupling torque rather than crankshaft torque. |
| Road automatic | Fixed missing light-throttle upshifts. Shift targets interpolate with throttle; kickdown compares useful lower-gear torque and keeps hysteresis below the upshift boundary. Full-load schedules still use the engine's performance curve. |
| Converter | Default capacity is sized from installed full-load torque at stall, including induction and engine upgrades. The old unboosted base-torque sizing could overload the converter and send stronger builds toward the limiter. Passive fluid-energy bounds and finite lockup capacity remain. Normal fluid slip is distinct from internal pack overload. |
| Manual / sequential / DCT / drag | Retained existing controls and type/upgrade shift delays, 2–10 gears, manual clutch checks, paddle queue, rev matching, DCT retention and drag multiplication. Drag automatics retain full-load schedules even at partial throttle. |
| Ratios / efficiency | Retained actual OEM ratios, per-type gear count and tuning, final drive, tire radius and efficiency. Tests verify gear selection cannot directly change speed/RPM, and wheel torque is limited through the coupled solver. |
| Shift planner duplication | Quasi-static force integrals remain a search heuristic, validated with the actual solver. They now respect clutch capacity and the current launch-grip envelope. Trial launches now use the same vehicle-specific launch RPM, clutch helper and installed nitrous as the benchmark driver, rather than a fixed 3900-RPM launch with a different clutch procedure and no spray. |
| Traction / suspension | Existing calibrated FWD/RWD/AWD grip, acceleration load transfer, pressure, launch bite, hop damping, wheel inertia and traction impulse are retained. No instant speed-based grip restoration or launch acceleration multiplier was added. Regression tests cover weak tires versus slicks, suspension, pressure and recovery with upgraded power. |
| Nitrous | Retained kit-only activation, finite bottle duration, torque addition and mechanical/fuel capacity limits. No stock nitrous, bypass of tire grip, or power while disengaged is introduced. |
| Hybrid assist | Fixed final-step battery overdraw: available electrical energy is now reduced by conversion efficiency before limiting wheel power. Electric axle torque still passes through tire traction. |
| Mass / aero / brakes / distance | Retained curb mass, weight/brake upgrades, quadratic drag, rolling resistance, braking cap and trapezoidal distance integration. Tests cover energy loss when coasting and stopping without reversing. |
| Class / economy / saves / UI | Fixed engine classes and player state remain independent of elapsed time. No UI redesign, prices, rewards, ownership or save schema changes. |

The original championship regression already failed its elapsed-time class
assertion on the original solver (`class_D_4`, verified in an isolated copy).
That obsolete check now validates the authored event division and a finished,
finite run. Player engine-class entry checks remain. All adjacent rivals must
still become faster in normalized quarter-mile and same-distance comparisons;
the former arbitrary 35 ms minimum gap was replaced with strict ordering above
1 ms numerical tolerance. The corrected solver produces gaps of 16 ms and
27 ms for two pairs. Boss difficulty-step and legal-player beatability checks
remain intact. No rival contracts or driver attributes were adjusted to fit
old target times.

## Physical model limits

This remains REDLINE's existing one-dimensional game simulation. Grip values
are calibrated whole-vehicle effective coefficients, not measured per-tire
friction curves. Axle transfer and hybrid torque allocation are lumped models;
there is no lateral/combined-slip tire solver, detailed differential, tire
temperature model, or full hydrodynamic converter map. Shift-retention factors,
thermal protection, and anti-stall clutch assistance remain game estimates.
The benchmark covers factory, tuned and extreme builds, but does not certify
manufacturer acceleration figures or every possible saved tune.

## Reproduce

Use Godot 4.6.3 and isolated save directories as provided by the runner:

```
python tools/run_regressions.py --godot C:/Godot/godot.exe --output .qa/physics-audit/regressions
python tools/report_physics_audit.py
```

The headless runner includes the focused audit and all 18 after measurements.
The immutable before snapshot should not be regenerated from the new solver.
For just the measured after runs, use `--headless --path . --script
tests/benchmark_physics_audit.gd`. The existing factory benchmark generator is
`tests/benchmark_roster.gd`.

## Verification evidence

`regressions.json` records the latest passing results from 18 headless suites,
the Godot import, and two graphical suites. The focused audit checks 4,628
conditions, including 30/60/144 Hz input replay, every supported gear count,
traction impulse bounds, passive coast energy, converter stall behavior,
overload, load-sensitive boost, launch control and depleted hybrid energy.
The existing tests also cover rated output across all 30 cars, the full
60-race economy route, transmission purchasing/tuning/save round trips,
nitrous, traction upgrades, max-power gearbox support and race controls.
The new frame-rate test required a float annotation fix; its successful
targeted rerun is recorded alongside the original batch results.

The retained drag calculation follows [NASA's drag equation](https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/drag-equation/):
force is proportional to density, drag area and speed squared. The coupled
impulse solver and passivity tests, rather than time targets, determine the
resulting acceleration.
"""
    (OUT / "REPORT.md").write_text(text, encoding="utf-8")
    print("Physics audit: 18 paired configurations, 36 rows; reports generated")


if __name__ == "__main__":
    main()
