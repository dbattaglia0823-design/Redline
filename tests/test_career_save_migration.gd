extends SceneTree
var failures:=0
var checks:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func _initialize() -> void:
	var p:=DriverProfile.new(); p.credits=9543; p.xp=2100; p.wins=8; p.races=14; p.career_wins=[5,2,1]; p.paint=4
	p.stages=[1,1,2,1,3,1,1,1]; p.hardware=VehicleBench.fixture("manual5",["ecu","clutch_twin"],{"launch_rpm":4200})
	p.garage.civic_si={"stages":GameCatalog.blank_stages(),"hardware":GameCatalog.factory_build("civic_si")}
	p.save_tune_slot("street","Old street tune"); p.save()
	var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DriverProfile.SAVE_PATH))
	for key in ["save_format","integrity","career_version","championship_wins","career_claims","event_records","career_serial"]: raw.erase(key)
	var file:=FileAccess.open(DriverProfile.SAVE_PATH,FileAccess.WRITE); file.store_string(JSON.stringify(raw)); file.close()
	var restored:=DriverProfile.new(); restored.load_profile()
	check(restored.credits==9543 and restored.xp==2100 and restored.wins==8 and restored.races==14,"Migration reset player totals")
	check(restored.career_wins==[5,2,1] and Championships.unlock_reason(restored,"C")=="","Migration lost legacy unlock credit")
	check(restored.garage.has("civic_si") and restored.stages==p.stages and restored.paint==4,"Migration lost vehicles or upgrades")
	check(restored.hardware.parts.values().has("ecu") and restored.hardware.tune.launch_rpm==4200 and restored.tuning_presets().street.name=="Old street tune","Migration lost transmission hardware, tuning or saved presets")
	check(FileAccess.file_exists(DriverProfile.SAVE_PATH+".pre_championships"),"Legacy save was not backed up")
	check(Championships.sanitize_wins({"E":99,"D":-3,"C":[],"B":"bad"})=={"E":10,"D":0,"C":0,"B":0,"A":0,"S":0},"Malformed championship state not normalized safely")
	raw["career_version"]=1
	raw["championship_wins"]={"E":5,"D":2}
	raw["career_claims"]=["class_E_4","open_0"]
	raw["event_records"]={"class_E_4":{"wins":1,"best_et":15.7}}
	file=FileAccess.open(DriverProfile.SAVE_PATH,FileAccess.WRITE); file.store_string(JSON.stringify(raw)); file.close()
	restored=DriverProfile.new(); restored.load_profile()
	check(Championships.wins(restored,"E")==5 and Championships.wins(restored,"D")==2,"Five-race save changed cleared rounds")
	check(Championships.trophies(restored)==0 and Championships.unlock_reason(restored,"D")=="" and Championships.unlock_reason(restored,"C")=="","Five-race save lost access or granted a new trophy")
	check(restored.career_claims==["class_E_4","open_0"] and is_equal_approx(restored.event_records.class_E_4.best_et,15.7),"Legacy claim or ET lost")
	restored.save(); restored=DriverProfile.new(); restored.load_profile()
	check(Championships.unlock_reason(restored,"C")=="","Migrated access did not survive version 2 save")
	var fresh:=DriverProfile.new(); fresh.wins=30; fresh.career_wins=[5,5,5]
	check(Championships.unlock_reason(fresh,"D")!="","Street wins bypassed the championship boss")
	p=DriverProfile.new()
	var event:=Championships.event("class_E_0")
	check(p.begin_wager(100,event),"Valid event entry rejected")
	var result:=p.award_race(event,true,true,17,-.03,80,0,0)
	check(p.credits==2300 and result.reward==0 and result.xp==0 and p.wins==0 and Championships.wins(p,"E")==0,"Red light paid a reward or advanced championship")
	check(p.career_claims.is_empty(),"Red light claimed a completion bonus")
	check(p.begin_wager(100,event),"Recovery entry after loss rejected")
	result=p.award_race(event,false,false,18,.4,79,0,0)
	check(p.credits==2460 and result.base==260 and result.bet_return==0,"Loss wager or finish award inconsistent")
	p.begin_wager(200,event); restored=DriverProfile.new(); restored.load_profile()
	check(restored.credits==2260 and restored.pending_wager.is_empty(),"Interrupted entry refunded or reopened the charged wager")
	p=DriverProfile.new(); p.credits=10000
	check(not p.begin_wager(501,event) and p.credits==10000,"Event wager cap bypassed")
	print("CAREER SAVE MIGRATION / ORIGINAL PROGRESS / PRESETS / RED LIGHT / WAGERS: ",checks," / ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
