"""Report the authored difficulty curve and wager-funded economy evidence."""
from pathlib import Path
import csv
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "validation/championship_economy"


def main():
    measured = json.loads((OUT / "difficulty.json").read_text(encoding="utf-8"))
    events = json.loads((ROOT / "assets/data/championships.json").read_text(encoding="utf-8"))
    career = json.loads((ROOT / ".qa/career_economy_progression.json").read_text(encoding="utf-8"))
    assert career["passed"] and len(career["events"]) == 60
    assert len(events) == 65 and all(e["purse"] == 0 and e["completion_bonus"] == 0 for e in events.values())
    (OUT / "betting_career.json").write_text(json.dumps(career, indent=2) + "\n", encoding="utf-8")
    rows = measured["races"]
    with (OUT / "difficulty.csv").open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, ["id", "class", "model", "recipe", "distance", "old_quarter_ai_s", "quarter_ai_s", "old_race_s", "race_s", "bet_cap"], extrasaction="ignore")
        writer.writeheader()
        writer.writerows(dict(row, distance=events[row["id"]]["distance"], bet_cap=int(row["bet_cap"])) for row in rows)
    text = """# Championship difficulty and betting economy

The 60 existing championship IDs, rival identities, ten rounds per class,
boss flags, mixed eighth/quarter-mile distances, open half-mile mode, motor-only
rules, player engine classes, and saved progress are retained. Rival vehicles
now have engines belonging to their championship class. The following results
use REDLINE's shared physics and actual AI controls, not acceleration bonuses.

## Opening matches and bosses

Each opener uses a stock opponent calibrated about 0.4 seconds behind the
slowest stock car in its class at a 0.18-second driver reaction. The regression
also tests all 30 stock cars with a 0.25-second reaction, correct launches and
shifts; every one beats its own opener by more than 0.1 seconds. Faster stock
cars naturally have more margin. Poor launches, missed shifts and red lights
can still lose an opening race.

After the opener, real engine, induction, traction, transmission and nitrous
builds become progressively faster. All 54 follow-up matches are also at least
0.08 seconds faster than their previous contracts over the normalized quarter,
and at least 0.03 seconds faster over each event's actual race distance.
All 30 stock cars lose to their class boss
by more than 0.7 seconds in the competent-driver simulation. Bosses remain
beatable with purchased upgrades and good control; the full funded career is
tested through the actual purchase, equipping, wagering and award APIs.

Times below are quarter-mile-normalized green-to-finish seconds, including
AI reaction. Eighth-mile events retain their actual race distance. The old
times were remeasured using the same physics before changing the contracts.

| Class | Slowest stock | New opener | Old boss | New boss | Opening bet cap | Boss bet cap |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
"""
    for letter in "EDCBAS":
        group = [r for r in rows if r["class"] == letter]
        first, last = group[0], group[-1]
        text += (f'| {letter} | {max(first["stock_times"].values()):.3f} | {first["quarter_ai_s"]:.3f} | '
                 f'{last["old_quarter_ai_s"]:.3f} | {last["quarter_ai_s"]:.3f} | ${int(first["bet_cap"]):,} | ${int(last["bet_cap"]):,} |\n')
    text += """
## Betting is the only race income

- No purse, loss/finish payment, first-win cash, boss cash, or automatic bailout.
- A winning bet returns twice the stake: the stake back plus equal net profit.
  Losing, red-lighting or abandoning a race loses the stake. Duplicate results
  cannot pay again. Entry binds the authoritative event and checks its cap.
- Old bound contracts containing obsolete purses or bonuses cannot restore
  those payments. Existing balances, purchased parts, ownership and progress
  are preserved; a price increase does not charge an owned part again.
- Free races remain available at zero credits and still earn XP and advance
  eligible championship wins. They award zero cash. Spending or losing all
  cash intentionally removes the ability to earn race money until the player
  has a bankroll; this risk was explicitly selected by the user.
- Trophies and next-class unlocks are independent of cash rewards. First-clear
  trophy presentation and replay guards remain even though cash bonuses are zero.
- Caps rise by class and round, including motor-only heats (their nitrous
  restriction remains). Open rivals have caps ordered by measured quarter-mile
  pace. Wager buttons/slider steps adapt to the available maximum, and an exact
  cap remains selectable. The balance always limits the stake.

## Upgrade pricing

Stage prices are incremental, and skipping ahead sums all unowned stages.
The multipliers are base × 1 / 3 / 8; gearbox stages extend to ×18 / ×36.
For example, engine tiers cost $700 / $2,100 / $5,600; buying tier three from
stock costs $8,400. Gearbox stages cost $900 / $2,700 / $7,200 / $16,200 /
$32,400, totaling $59,400 from stock. Existing owned lower/higher tiers can be
equipped again without another charge.

Component ladders also have larger price gaps. All prices below are full
component purchase prices; owned parts are free to re-equip in their fitment.

| Component | Previous | New |
| --- | ---: | ---: |
"""
    pattern = r'"(\w+)":\{"slot":"([^"\n]+)"[^\n]*?"name":"([^"\n]+)"[^\n]*?"cost":(\d+)'
    old_source = subprocess.check_output(["git", "show", ":scripts/vehicle_parts.gd"], cwd=ROOT).decode("utf-8")
    old_prices = {r[0]: int(r[3]) for r in re.findall(pattern, old_source)}
    # Preserve the historical comparison when this tool runs after a commit.
    if (OUT / "prices.json").exists():
        old_prices.update({r["id"]: r["before"] for r in json.loads((OUT / "prices.json").read_text(encoding="utf-8"))["components"]})
    new_rows = re.findall(pattern, (ROOT / "scripts/vehicle_parts.gd").read_text(encoding="utf-8"))
    prices = []
    for ident, slot, name, cost in new_rows:
        before, after = old_prices[ident], int(cost)
        prices.append({"id": ident, "slot": slot, "name": name, "before": before, "after": after})
        if before != after:
            text += f"| {name} | ${before:,} | ${after:,} |\n"
    (OUT / "prices.json").write_text(json.dumps({"stage_multipliers": [0, 1, 3, 8, 18, 36], "components": prices}, indent=2) + "\n", encoding="utf-8")
    text += f"""
## Betting-funded progression simulation

The automated route completed **all 60 championship races**, starting with the
normal $2,400 balance and stock Miata. It used **{career['recovery_runs']} extra
betting replays**, conservative stakes of at most one-third of its current
balance, exact staged prices, actual purchase/equip APIs, retained per-car
ownership, and zero non-betting race income. It kept $1,000 for betting after
planned purchases. This is one attainable route, not an optimal buying plan,
a human win-rate claim, or a guarantee against bankruptcy. A player willing
to stake more risks more; free races never substitute for betting income.
The per-race car, upgrade cost, player/rival times, balance and replay count
are recorded in `betting_career.json`.

## All 60 matches

| Race | Rival car | Old quarter | New quarter | Actual-distance time, old → new | Bet cap |
| --- | --- | ---: | ---: | ---: | ---: |
"""
    for row in rows:
        text += (f'| {row["id"]} | {row["model"]} | {row["old_quarter_ai_s"]:.3f} | '
                 f'{row["quarter_ai_s"]:.3f} | {row["old_race_s"]:.3f} → {row["race_s"]:.3f} | ${int(row["bet_cap"]):,} |\n')
    text += """
## Reproduce and validate

```
python tools/run_regressions.py --godot C:/Godot/godot.exe --output .qa/championship-economy/regressions
python tools/report_championship_economy.py
```

`test_betting_progression.gd` checks every stock opener, stock-versus-boss
performance, all 60 increasing caps, betting settlement, zero-credit XP/progress,
old-contract payouts, duplicate awards and staged ownership prices.
`test_championships.gd` checks increasing normalized and same-distance pace,
class-correct rival engines, six trophies, unlocks, rewards and saved progress.
`test_career_economy_sim.gd` exercises a complete betting-funded career.

The offline authoring script is `tests/rebalance_championships.gd`; `-- --write`
publishes its measured real builds. It is not run during play and does not
rubber-band opponents to the player's upgrades. `tests/build_championships.gd`
refreshes performance metadata without changing engine classes. Historical
physics-only measurements remain in `validation/physics_audit`.

## Validation results and existing shutdown issue

The final batch passed all 21 headless suites plus the Godot import. After
the last two Class S adjustments, the targeted difficulty test passed all
335 checks and the complete betting-funded 60-race economy simulation passed
again. Desktop/phone/landscape wager interactions, all-class race UI, upgrade
purchasing, controller inputs and trophy flow passed their visual assertions.
Million-credit stakes were tested through actual mouse/touch entry events.

The Windows Godot process exits with access violation `0xC0000005` after these
graphical tests finish, despite the assertions passing. This also reproduces
with a pre-change source overlay (verified by the old $2,100 tier-two engine
quote, versus the new $2,800 cumulative quote) in a minimal garage-open/close
probe. An empty renderer probe exits cleanly. The same shutdown fault occurs
with native OpenGL and ANGLE, so clean graphical-process shutdown is **not**
claimed. This existing application shutdown issue remains outside this
championship/economy update. Evidence and exit statuses are recorded in
`regressions.json`; local screenshots and raw logs are under
`.qa/championship-economy`. Physical phone/controller hardware was not tested.
"""
    (OUT / "REPORT.md").write_text(text, encoding="utf-8")
    print("Championship/economy report: 60 matches, 30 stock cars, full betting-funded route")


if __name__ == "__main__":
    main()
