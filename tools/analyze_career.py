"""Validate and tabulate the actual shared-physics AI calibration."""
from pathlib import Path
import csv
import json
import math

folder = Path(__file__).resolve().parents[1] / 'validation'
data = json.loads((folder / 'rival_test_results.json').read_text())
rows = data['runs']
assert data['failures'] == 0 and len(rows) == 15
assert all(not r['early_motion'] and r['safety_clamps'] == 0 and math.isfinite(r['quarter_s']) and 5 < r['quarter_s'] < 30 for r in rows)
assert len({r['transmission'] for r in rows}) >= 6
assert rows[-1]['quarter_s'] < rows[10]['quarter_s']
with (folder / 'career_balance.csv').open('w', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=['event','opponent','transmission','hp','quarter_s','quarter_mph'], extrasaction='ignore')
    writer.writeheader(); writer.writerows(rows)
table = ['| Tier / rival | Gearbox | HP | Quarter seconds | Line mph |','| --- | --- | ---: | ---: | ---: |']
for r in rows:
    table.append(f"| {r['event']+1} / {r['opponent']+1} | {r['transmission']} | {r['hp']} | {r['quarter_s']:.3f} | {r['quarter_mph']:.1f} |")
report = folder / 'CAREER_REPORT.md'
text = report.read_text(encoding='utf-8-sig').split('\n## Calibration table')[0]
report.write_text(text + '\n## Calibration table\n\nFixed base driver seeds, two seconds of staging, 240 Hz engine solver, reaction included. Actual attempts add small driver variation. Trap is line-crossing speed. These are simulation results, not footage measurements.\n\n' + '\n'.join(table) + '\n',encoding='utf-8')
print(json.dumps({'career_analysis_passed': True, 'opponents': len(rows), 'quarter_range_s': [min(r['quarter_s'] for r in rows),max(r['quarter_s'] for r in rows)]}))
