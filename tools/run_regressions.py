"""Run the release-critical Godot checks with separate save directories."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
from tempfile import TemporaryDirectory

HEADLESS = (
    "test_save_recovery", "test_career_save_migration", "test_championships",
    "test_career_economy_sim", "test_roster", "test_physics", "test_traction_expansion",
    "test_driving_feedback", "test_transmissions", "test_parts_lineup", "test_customization",
    "test_upgrade_model", "test_advanced_tuning", "benchmark_launch_balance",
)
GRAPHICAL = ("test_save_recovery_ui", "test_championships_ui", "test_race_hud", "test_upgrade_redesign", "test_native_workshop", "test_customization_ui", "test_main_navigation", "test_vehicle_lighting", "test_track_environments", "test_pressure_units", "test_controls_and_imperial")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--output", type=Path, default=Path(".qa/regressions"))
    parser.add_argument("--graphical", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    results = {}

    def run(name, command, timeout):
        log = output / f"{name}.log"
        with TemporaryDirectory(prefix="redline-", dir=output) as temporary:
            env = dict(os.environ, APPDATA=temporary, LOCALAPPDATA=temporary,
                       XDG_DATA_HOME=temporary, XDG_CONFIG_HOME=temporary, XDG_CACHE_HOME=temporary,
                       TEMP=temporary, TMP=temporary, TMPDIR=temporary)
            with (output / f"{name}.stdout").open("wb") as captured:
                try:
                    process = subprocess.run(
                        [args.godot, "--path", str(root), "--log-file", str(log), *command],
                        cwd=root, env=env, stdout=captured, stderr=subprocess.STDOUT, timeout=timeout,
                    )
                except subprocess.TimeoutExpired:
                    results[name] = "timeout"
                    print(f"{name}: timeout", flush=True)
                    return False
        errors = re.search(r"^\s*(?:SCRIPT ERROR|ERROR):|\bFAIL\b", log.read_text(encoding="utf-8", errors="replace"), re.M) if log.exists() else True
        passed = process.returncode == 0 and not errors
        results[name] = "pass" if passed else "fail"
        print(f"{name}: {results[name]}", flush=True)
        return passed

    if run("import", ["--headless", "--editor", "--import", "--quit"], 720):
        for name in HEADLESS:
            run(name, ["--headless", "--script", f"tests/{name}.gd"], 360)
        if args.graphical:
            for name in GRAPHICAL:
                run(name, ["--script", f"tests/{name}.gd"], 180)
    (output / "summary.json").write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    return int(any(value != "pass" for value in results.values()))


if __name__ == "__main__":
    raise SystemExit(main())
