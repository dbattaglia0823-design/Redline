class_name RosterData
extends RefCounted
static var _rows: Dictionary = {}
const IDS: Array[String] = ["miata","civic_si","gti_vr6","rsx","brz","integra","gti","s2000","gr86","z350","supra","m3","sti","evo","type_r","mustang","supra_gr","camaro","golf_r","z400","z06","gtr","r8","gt500","redeye","turbo_s","mclaren","sf90","demon","chiron"]
const RETIRED := {"kaze":"miata","nori":"civic_si","aster":"supra","vanta":"gtr","mika":"gti_vr6","brindle":"z350","comet":"mustang","rikka":"sti","velora":"supra_gr","solenne":"mclaren","aurora":"r8","hammer":"demon"}
static func rows() -> Dictionary:
	if _rows.is_empty(): _rows=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/roster.json"))
	return _rows
static func factory_transmission(id: String) -> Dictionary:
	var model := id.trim_prefix("oem_")
	if not rows().has(model): return {}
	var s: Dictionary=rows()[model]; var kind:=str(s.gearbox_kind)
	kind="manual" if kind.begins_with("manual") else "dct" if kind.begins_with("dct") else "automatic"
	return {"id":id,"name":"Factory "+str(s.gear_ratios.size())+"-speed "+kind,"kind":kind,"ratios":s.gear_ratios.duplicate(),"mass":50.0 if kind=="manual" else 90.0,"efficiency":.92 if kind=="manual" else .94,"shift":.24 if kind=="manual" else .09 if kind=="dct" else .16,"capacity":maxf(350,float(s.peak_torque_nm)*1.3),"cost":0,"stage":0,"layout":"FWD" if s.drive=="FWD" else "LONG"}
