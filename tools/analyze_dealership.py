"""Summarize native dealership validation without substituting estimated ratings."""
from pathlib import Path
import csv
import json
import math

out = Path(__file__).resolve().parents[1] / 'validation'
data = json.loads((out / 'dealership_metrics.json').read_text())
rows = data['vehicles']
assert data['failures'] == 0 and len(rows) == 30
assert len({r['vehicle'] for r in rows}) == 30
assert all(math.isfinite(r['quarter_s']) and r['quarter_s'] > 0 for r in rows)
assert data['budget_built_quarter_s'] < data['flagship_stock_quarter_s']
with (out / 'dealership_comparison.csv').open('w', newline='') as f:
    fields = ['vehicle','name','brand','price','unlock_level','transmission','hp','torque_nm','mass','quarter_s','ai_quarter_s','mph']
    writer = csv.DictWriter(f, fieldnames=fields)
    writer.writeheader(); writer.writerows(rows)
table = ['| Model | Credits | Level | Factory box | Engine HP / Nm | kg | Bench quarter |', '| --- | ---: | ---: | --- | ---: | ---: | ---: |']
for r in rows:
    table.append(f"| {r['name']} | {r['price']:,} | {r['unlock_level']} | {r['transmission']} | {r['hp']} / {r['torque_nm']:.0f} | {r['mass']:.0f} | {r['quarter_s']:.3f} s |")
report = '# Dealership validation\n\n'
report += 'Thirty factory builds were exercised with native Godot tests: configuration, purchase/equip behavior, exact currency deductions, duplicate rejection, progression locks, filters, collection pagination, and per-car save/load. Engine horsepower excludes electric assistance; SF90 assistance is separate.\n\n'
report += '\n'.join(table)
report += f"\n\nThe tuned GR86 fixture ran {data['budget_built_quarter_s']:.3f} s versus {data['flagship_stock_quarter_s']:.3f} s for the stock R8. This verifies one affordable-build comparison, not universal superiority over expensive cars.\n\n"
report += 'These are simulation results, not manufacturer-certified performance. See ROSTER_REPORT.md for specification provenance, artwork limitations, class differences, reference gaps, and device testing still required.\n'
(out / 'DEALERSHIP_REPORT.md').write_text(report, encoding='utf-8')
print(json.dumps({'dealership_analysis_passed': True, 'vehicles':len(rows), 'budget_build_competitive':True}))
