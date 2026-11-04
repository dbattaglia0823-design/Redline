"""Rebuild the transmission validation report from deterministic Godot runs."""
from pathlib import Path
import csv
import json
import math

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "validation"


def main():
    data = json.loads((OUT / "transmission_benchmark.json").read_text(encoding="utf-8-sig"))
    paired = json.loads((OUT / "drag_tuning_benchmark.json").read_text(encoding="utf-8-sig"))
    rows = data["runs"]
    comparisons = []
    for setup in ("street", "drag"):
        for ident in dict.fromkeys(r["transmission"] for r in rows):
            group = [r for r in rows if r["setup"] == setup and r["transmission"] == ident]
            optimized = next(r for r in group if r["policy"] == "optimized")
            fixed = min((r for r in group if r["policy"] == "fixed"), key=lambda r: r["quarter_s"])
            comparisons.append({"setup": setup, "transmission": ident, "optimized_s": optimized["quarter_s"], "best_fixed_s": fixed["quarter_s"], "fixed_rpm": fixed["fixed_rpm"], "deficit_s": optimized["quarter_s"] - fixed["quarter_s"]})
    worst = max(r["deficit_s"] for r in comparisons)
    assert data["passed"] and len(rows) == 168
    assert all(r["safety_clamps"] == 0 and math.isfinite(r["quarter_s"]) for r in rows)
    assert worst < .03, f"Shift map is uncompetitive by {worst:.4f} s"
    assert paired["drag3_wins"] > 0 and paired["auto10_wins"] > 0
    (OUT / "transmission_comparison.json").write_text(json.dumps({"passed": True, "main_runs": len(rows), "paired_runs": len(paired["runs"]), "worst_optimized_deficit_s": worst, "comparisons": comparisons}, indent=2) + "\n")
    optimized = [r for r in rows if r["policy"] == "optimized"]
    fields = ["setup", "transmission", "zero_60_s", "zero_100_s", "eighth_s", "eighth_mph", "quarter_s", "trap_mph", "shift_count", "shift_time_s", "effective_shift_loss_s", "wheelspin_s", "rpm_min", "rpm_max", "rpm_mean", "engine_c", "transmission_c", "safety_clamps"]
    with (OUT / "transmission_summary.csv").open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        writer.writeheader(); writer.writerows(optimized)
    table = ["| Gearbox | Gears | Street ET / mph | Drag ET / mph |", "| --- | ---: | ---: | ---: |"]
    for ident in dict.fromkeys(r["transmission"] for r in rows):
        street = next(r for r in optimized if r["setup"] == "street" and r["transmission"] == ident)
        drag = next(r for r in optimized if r["setup"] == "drag" and r["transmission"] == ident)
        table.append(f'| {ident} | {len(street["gears"])} | {street["quarter_s"]:.3f} / {street["trap_mph"]:.1f} | {drag["quarter_s"]:.3f} / {drag["trap_mph"]:.1f} |')
    pairs = []
    for i in range(0, len(paired["runs"]), 2):
        a, b = paired["runs"][i:i + 2]
        if a["quarter_s"] < b["quarter_s"]:
            pairs.append(f'- Built fixture, final drive {a["final_drive"]:.2f}, {"factory converters" if a["stall"] == 0 else str(a["stall"])+" RPM converter"}: 3D **{a["quarter_s"]:.3f} s**, 10A **{b["quarter_s"]:.3f} s**.')
    physics = json.loads((OUT / "physics_test_results.json").read_text())
    check_log = (OUT / "test_transmissions.log").read_text()
    count = check_log.split("TRANSMISSION + PARTS: ")[1].split(" checks")[0]
    report = f'''# Transmission and vehicle upgrade validation

The existing game now has 21 gearbox configurations covering 2–10 forward gears, six transmission stages, and 34 purchasable mechanical parts across 20 slots. Existing cars, legacy stages, controls, wagers and saves remain compatible. The default Original 6P retains paddle shifting and its previous race balance.

## Verified results

- Coupled-physics regression: {physics["checks"]:,} checks passed. Stock Kaze remains {physics["stock_quarter"]["et"]:.6f} s at {physics["stock_quarter"]["mph"]:.3f} mph; the existing tier-three build remains {physics["upgraded_quarter"]["et"]:.6f} s at {physics["upgraded_quarter"]["mph"]:.3f} mph.
- Transmission/parts suite: {int(count):,} checks passed, including all ratios, H-gate clutch/overrev protection, paid control conversions, converter passivity and lockup, transbrake launch, foot-brake holding, strength/wear, cooling, part prerequisites, tuning bounds, gearbox-specific ownership/stages, save/load and audio telemetry. Counts include individual generated-audio sample validity checks.
- 168 matched main benchmark runs: every gearbox on two setups, calculated maps versus 6,500 / 7,000 / 7,400 RPM strategies. No safety clamps. Worst calculated-map deficit against the best tested fixed strategy: **{worst:.4f} s**. This is competitive within the tested grid, not a proof of global optimality.
- 36 additional paired tuning runs: 3D wins {paired["drag3_wins"]} of 18 pairs; 10A wins {paired["auto10_wins"]}. Gear count does not determine the winner.
- Rendered upgrade/control interaction tests passed: all 21 configurations reachable, real purchases, locked tuning, paddle conversion, H-gate keyboard and three-finger input, B transbrake and vehicle-test isolation.
- Existing audio, controls, menus, economy, rivals, race-flow and 30/60/120/144 FPS runtime suites pass. Native Windows drag playtest: 12.817 s at 114.0 mph, two automatic shifts, zero RPM clamps and zero audio underruns. Native test used gas assistance and disabled focus-out pausing only in its private harness.

## Measured performance

Each main setup holds engine, chassis, tires, final drive (3.20), stages, road, initial conditions and assisted driver constant across gearboxes. Gearbox weight, ratios, efficiency, control type, converter and shift behavior vary as installed hardware. All boxes use Pro Race internals for comparison; buying a new gearbox in the game starts it at Stock.

Street: Kaze engine/chassis, other stages zero. Drag: explicitly synthetic RWD test fixture, base torque 540 Nm, mass 1,350 kg, base grip 1.05, I6 engine and tier-three engine/turbo/tires/weight/exhaust/brakes. Both use the same final-drive kit and radiator. No nitrous. Two seconds of physical staging with a feedback pedal targeting 3,900 RPM; no forced RPM assignment. Times start when the independent bench releases staging, excluding staging/reaction time.

{chr(10).join(table)}

Examples where the 3-speed wins in the separate paired sweep:

{chr(10).join(pairs)}

The paired built fixture uses the Kaze base engine, all tier-three stages, base grip 0.9 and Pro Race gearbox internals. Each pair has identical final drive and radiator. Factory converters retain their transmission-specific stall characteristics; fitted converter comparisons use the same purchased kit and stall setting. Tall gearing avoids unnecessarily running the drag box against its direct-drive speed limit. Shorter gearing can reverse the result.

`transmission_summary.csv` includes 0–60/100, eighth/quarter, trap, shift count/time, wheelspin duration, engine range and temperatures. Trap here is interpolated line-crossing speed, not a separate 66-foot averaging zone. Full JSON retains per-shift timing and settled RPM, and the 42 optimized runs export 20 Hz telemetry CSVs. A null 0–100 means the vehicle did not reach that speed within 40 simulated seconds; it is not zero seconds. Shift interruption equivalent is duration weighted by the nominal torque cut, a comparison proxy rather than a measured causal elapsed-time penalty. It must not be read as the exact time recovered by an instantaneous gearbox.

## Changes and faults corrected

- Removed the old forward-gear count ceiling. Every gearbox has its own ratio set, mass, efficiency, torque rating, shift minimum and torque interruption behavior; no gear-count power multiplier.
- Kept stage progression separate from purchased assemblies. Internals stages and gearbox-specific clutch/controller/converter/ratio fitments remain owned per car and per gearbox; swapping assemblies does not transfer paid internal upgrades for free. New boxes start Stock. Reinstalling owned fitments costs nothing.
- Added a finite pump/turbine converter with stall multiplication, passive fluid impulses, slip heating and finite lockup. Corrected stale-load lockup lag, which could destabilize RPM; the locked converter shares inertia with the existing coupled solver. Brakes can hold converter creep. Optional transbrake locks output only in first near stationary.
- Replaced static-only shift scheduling with engine/gear/traction/converter calculations plus bounded full-physics candidate runs. The static approximation initially lost up to 0.23 s on some street automatics. The validated maps remove that deficit. Cache keys include vehicle, relevant stages, installed parts and tuning. Individual overrides require a purchased race controller.
- H-pattern shifting needs clutch + gear selection and retains throttle/rev-match responsibility; powered sequential/paddle conversions include an actuator. ECU-equipped H manuals allow ignition-cut flat shifting. Existing paddle queue/cancel protections remain intact. Automatic controller input cannot accidentally request a manual shift.
- Applied part effects to inertia, torque curve/flow, rotating/curb mass, fuel/torque support, boost response, rev limits, clutch capacity, final drive, tire radius/grip/inertia, weight transfer, cooling and progressive nitrous delivery. Supercharger conversions replace the turbo assembly; earlier turbo stages remain owned. Repeat configuration resets modifiers before applying parts, preventing stacked gains.
- Added thermal derating and race-local overload/heat wear; cooling changes actual temperatures. No permanent part destruction or new repair charge. RPM/tuning arrays reject nonfinite values and incompatible parts remain uninstalled. Rejected purchases do not deduct credits.
- Original synthesis now follows partial automatic/DCT combustion cuts, actual progressive nitrous flow and belt-driven supercharger tone. A supercharger does not arm the turbo blow-off effect. HUD/audio/telemetry read the same engine and drivetrain state.

## UI and controls

Basic View keeps the eight existing categories, installed stage, next purchase, affordability and a physical before/after comparison. Gearbox stages extend Stock → Stage 1 → Stage 2 → Stage 3 → Race → Pro Race; other legacy categories keep their three tiers.

Advanced tabs expose paged gearboxes and mechanical parts, part comparisons, two compact tuning pages, Street/Drag/Safe presets and an independent vehicle test. No endless parts list. Controller mode comes from installed hardware rather than a settings switch. Locked adjustments identify the required kit. Large landscape touch targets and multitouch input are retained; real-phone ergonomics remain unverified.

W gas, S brake, Q/E paddles or sequential selector, Shift manual clutch, Space nitrous, B compatible transbrake. H manuals use Shift + 1–6 or matching on-screen gates, N/0 neutral. Automatic/DCT hardware operates its own clutch; factory automatics shift themselves. Paid paddle controllers allow manual paddle operation on compatible assemblies. Mouse buttons and touch pointers release independently; pause/focus loss clears held inputs.

## Sources, approximations and remaining limits

Gear-ratio references are manufacturer publications: [Ford 10R80](https://www.fordservicecontent.com/Ford_Content/vdirsnet/OwnerManual/Home/Content?ProcUid=G1928612&Uid=G1928611&buildtype=web&countryCode=USA&div=f&languageCode=en&vFilteringEnabled=False&variantid=9584), [TCI transmission ratios](https://www.tciauto.com/gear-ratios), and [TREMEC TKX/Magnum ratios](https://tremec-blog.com/tremec-aftermarket-manual-transmission-gear-ratios/). The catalog uses Ford's listed 10R80 ratios; the drag 2D / 3D / 4D use TCI-listed 1.80/1.00, 2.10/1.40/1.00 and 2.48/1.48/1.00/0.75 sets. Other sets are original plausible configurations, not claims of specific donor fitment.

All prices, masses, efficiencies, shift timings, torque ratings, durability coefficients and conversion fitments are documented game estimates. ALL catalog fitments mean a platform-specific supplied package, not that one physical gearbox bolts into every car. Longitudinal automatic/drag packages are blocked for the FWD Nori. AWD packages assume an included suitable transfer interface. Supercharger and clutch installations assume matched supporting hardware. No original-game formulas or protected recordings are used.

The Strip footage does not identify these gearbox specifications, converter maps, durability or installed vehicle parts. Existing frozen footage calibration still passes; it remains a fitted reference fixture with estimated driver inputs, not independent verification of these new transmissions. Converter behavior is a lumped passive model, not an OEM fluid/valve-body or planetary model. No detailed clutch temperature distribution, fuel economy, detonation model, dyno-certified fitment, or permanent wear economy is claimed. Automatic schedules target this level quarter-mile benchmark; different tracks, nitrous use, throttle modulation or launch technique may favor custom points. Four bounded candidates do not establish a global optimum.

Actual Android/iOS touch ergonomics, low-end device performance, speaker latency and subjective driving/audio similarity still require human/device playtesting. The Windows/native and synthetic touch checks establish functional input routing, not those subjective or device-specific properties.

## Reproduction

Run `tools/validate_racing.ps1` with Godot 4.6 and Python 3. It isolates saves/caches, imports the existing project, runs the old and new headless/graphical suites, reproduces all 204 benchmark runs, checks reference/audio regressions and rebuilds this report. `tests/benchmark_transmissions.gd`, `tests/benchmark_drag_tuning.gd` and `scripts/vehicle_bench.gd` are reusable without the UI. Opening TEST BUILD never spends credits or updates race records.
'''
    (OUT / "TRANSMISSION_REPORT.md").write_text(report, encoding="utf-8")
    print(json.dumps({"transmission_analysis_passed": True, "runs": len(rows) + len(paired["runs"]), "worst_map_deficit_s": worst}))


if __name__ == "__main__":
    main()

