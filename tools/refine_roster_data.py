"""Apply explicitly documented primary/multi-final reductions to source specifications."""
from pathlib import Path
import json
r=Path(__file__).resolve().parents[1]; p=r/'assets/data/roster.json'; rows=json.loads(p.read_text())
s=rows['s2000']; s['raw_gear_ratios']=[3.133,2.045,1.481,1.161,.942,.763]; s['primary_reduction']=1.208
s['gear_ratios']=[round(x*1.208,6) for x in s['raw_gear_ratios']]
s['evidence']['gearing']='Honda 2004 specifications: six gear pairs, 1.208 primary and 4.100 final; primary folded into simulation gear pairs'
s['mass']=round(2835*.45359237,1); s['tires']='Front 215/45 R17; rear 245/40 R17'; s['tire_radius']=(17*.0254/2+.245*.40)
s=rows['rsx']; s['mass']=1260; s['gear_ratios'][0]=3.267; s['tires']='205/55 R16'; s['tire_radius']=.2032+.205*.55
s['evidence']['gearing']='2003 Acura Type-S table'; s['evidence']['mass']='2003 Acura Type-S: 1260 kg'; s['evidence']['tires']='2003 Acura table; nominal unloaded radius calculated'
s=rows['gti']; s['raw_gear_ratios']=[3.36,2.09,1.48,1.09,1.1,.91]; s['gear_ratios']=s['raw_gear_ratios'][:4]+[round(x*3.087/3.94,6) for x in s['raw_gear_ratios'][4:]]
s['evidence']['gearing']='Effective common-final ratios; secondary final estimated at 3.087, pending trim-specific verification'
s=rows['golf_r']; s['raw_gear_ratios']=[3.19,2.75,1.9,1.04,.79,.86,.66]; s['final_drive']=4.47; s['mass']=1530
s['gear_ratios']=[round(x*(1 if i in [0,3,4] else 3.3/4.47),6) for i,x in enumerate(s['raw_gear_ratios'])]
s['tires']='235/35 R19 option'; s['tire_radius']=19*.0254/2+.235*.35
s['evidence']['gearing']='VW 2019 published gear pairs and finals I=4.47, II=3.30; common-final branch mapping is an explicit approximation'
s['evidence']['mass']='VW 2019 DSG curb mass: 1530 kg'; s['evidence']['tires']='VW 19-inch option; nominal unloaded radius calculated'
rows['chiron']['layout']='W16'; rows['brz']['layout']='H4'; rows['gr86']['layout']='H4'; rows['sti']['layout']='H4'; rows['turbo_s']['layout']='H6'
p.write_text(json.dumps(rows,indent=2)+'\n')
print('Corrected primary/multi-final reductions and published RSX/S2000/Golf R details; estimates explicitly marked')
