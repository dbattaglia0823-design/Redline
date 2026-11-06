extends SceneTree

var failed := false
func check(ok: bool,message: String) -> void:
	if not ok: failed=true; push_error(message)

func write_raw(path: String,value: String) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(value)
	file.close()

func _initialize() -> void:
	var p:=DriverProfile.new()
	p.credits=9200
	p.championship_wins={"E":3}
	p.save()
	check(p.save_error=="" and not DriverProfile.read_save(DriverProfile.BACKUP_PATH).is_empty(),"Initial save and backup were not validated")
	p.credits=12500
	p.save()
	var raw:=FileAccess.get_file_as_string(DriverProfile.SAVE_PATH)
	var backup:=FileAccess.get_file_as_string(DriverProfile.BACKUP_PATH)
	var modified:=raw.replace('"credits":12500','"credits":13500')
	check(modified!=raw,"Fixture did not modify saved credits")
	write_raw(DriverProfile.SAVE_PATH,modified)
	var loaded:=DriverProfile.new()
	loaded.load_profile()
	check(loaded.save_blocked and loaded.recovery_available,"Valid JSON with a damaged checksum was accepted")
	loaded.save()
	check(FileAccess.get_file_as_string(DriverProfile.SAVE_PATH)==modified and FileAccess.get_file_as_string(DriverProfile.BACKUP_PATH)==backup,"Defaults or invalid primary overwrote recovery files")
	check(loaded.recover_backup() and loaded.credits==9200 and Championships.wins(loaded,"E")==3,"Verified backup did not restore progress")
	var reloaded:=DriverProfile.new()
	reloaded.load_profile()
	check(not reloaded.save_blocked and reloaded.credits==9200,"Restored primary did not load")
	write_raw(DriverProfile.SAVE_PATH,"{ truncated")
	write_raw(DriverProfile.BACKUP_PATH,"{ invalid")
	reloaded.save()
	check(reloaded.save_blocked and not reloaded.recovery_available and FileAccess.get_file_as_string(DriverProfile.SAVE_PATH)=="{ truncated","Unreadable primary was overwritten without a backup")
	print("SAVE INTEGRITY AND RECOVERY: ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
