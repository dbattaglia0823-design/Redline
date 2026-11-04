from pathlib import Path
import re
r=Path(__file__).resolve().parents[1]
p=r/'scripts/game_catalog.gd'; s=p.read_text(encoding='utf-8')
s=s.replace('static func opponent(career: int, index: int) -> Dictionary:','static func opponent(career: int, index: int, profile: DriverProfile = null) -> Dictionary:')
s=s.replace('var model: String = ["kaze", "aster", "vanta"][career]','var model: String = ["miata", "supra", "gtr"][career]').replace('model = "nori"','model = "civic_si"')
s=s.replace('\treturn {"hardware":hardware,"skill":career,','\tvar contract := {"hardware":hardware,"skill":career,')
needle='"shift_delay":0.17 - career * 0.035}'
assert needle in s
s=s.replace(needle,needle+'\n\treturn PerformanceClasses.match_contract(profile,career,index,contract) if profile != null else contract')
p.write_text(s,encoding='utf-8')
for filename,profile in [('main.gd','profile'),('garage_view.gd','g.profile'),('mobile_view.gd','g.profile'),('race_ai.gd','profile')]:
 p=r/'scripts'/filename; s=p.read_text(encoding='utf-8')
 s=re.sub(r'GameCatalog.opponent\((event_index|g.event_index|career),(selected_opponent|g.selected_opponent|index|i)\)',lambda m:'GameCatalog.opponent('+m[1]+','+m[2]+','+profile+')',s)
 p.write_text(s,encoding='utf-8')
p=r/'scripts/main.gd'; s=p.read_text(encoding='utf-8').replace('if RaceAI.advance_estimates(): menu_dirty = true','if RaceAI.advance_estimates(): menu_dirty = true\n\t\tif PerformanceClasses.advance(): menu_dirty = true')
s=s.replace('func start_race() -> void:\n','func start_race() -> void:\n\tif PerformanceClasses.request(profile.vehicle_id,profile.stages,profile.hardware).is_empty():\n\t\tshow_toast("Measuring build / try again shortly"); return\n')
p.write_text(s,encoding='utf-8')
p=r/'scripts/garage_hub.gd'; s=p.read_text(encoding='utf-8').replace('t(configuration_label(),60,221,13,g.MUTED)','t(configuration_label()+" / "+PerformanceClasses.label(g.profile),60,221,13,g.MUTED)')
p.write_text(s,encoding='utf-8')
p=r/'scripts/mobile_view.gd'; s=p.read_text(encoding='utf-8').replace('t(g.menu.hub.configuration_label(),42,259,18,g.MUTED)','t(PerformanceClasses.label(g.profile),42,259,18,g.MUTED)')
p.write_text(s,encoding='utf-8')
