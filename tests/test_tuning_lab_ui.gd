extends SceneTree
var game: Node2D
var failures:=0
var checks:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	game.sync_menu_size(); game.queue_redraw()
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
func rect(id: String) -> Rect2:
	for b in game.buttons:
		if b.id==id: return b.rect
	check(false,"Missing action "+id); return Rect2()
func click(id: String) -> void:
	var e:=InputEventScreenTouch.new(); e.index=7; e.pressed=true; e.position=game.to_global(rect(id).get_center()); game._input(e); e.pressed=false; game._input(e); await frame()
func key(code: Key,down: bool = true) -> void:
	var e:=InputEventKey.new(); e.physical_keycode=code; e.pressed=down; game._input(e)
func bounds(label: String) -> void:
	var region:=Rect2(0,0,600,1300) if game.is_portrait() else Rect2(0,0,1200,760)
	for i in game.buttons.size():
		var a: Dictionary=game.buttons[i]
		check(region.encloses(a.rect),"Offscreen "+label+" "+str(a.id))
		for j in range(i+1,game.buttons.size()): check(not a.rect.intersects(game.buttons[j].rect),"Overlap "+label+" "+str(a.id)+" / "+str(game.buttons[j].id))
func drive(length: float,trans: String) -> void:
	game.go_garage(); game.profile.hardware=VehicleBench.fixture(trans); game.profile.stages[4]=5; game.refresh_car()
	game.staging.assisted=true
	var before:=JSON.stringify([game.profile.credits,game.profile.xp,game.profile.races,game.profile.wins,game.profile.career_wins,game.profile.pending_wager])
	game.start_practice(length)
	check(game.screen=="race" and game.practice_mode and game.active_distance==length,"Practice start failed")
	check(game.tuning.length==length,"Repeat practice would use the wrong distance")
	check(game.profile.pending_wager.is_empty(),"Practice opened career wager")
	# Deliberate reaction delay, then operate the installed hardware through keyboard input.
	for i in 384: game._physics_process(1.0/120)
	key(KEY_W)
	for i in 9000:
		if game.car.upshift_ready():
			if game.car.control_mode=="hpattern": key(KEY_SHIFT); key(KEY_0+game.car.gear+1); key(KEY_SHIFT,false)
			elif game.car.control_mode!="automatic": key(KEY_E); key(KEY_E,false)
		game._physics_process(1.0/120)
		if game.screen=="practice_results": break
	key(KEY_W,false)
	check(game.screen=="practice_results","Player-driven practice did not finish: "+trans)
	check(JSON.stringify([game.profile.credits,game.profile.xp,game.profile.races,game.profile.wins,game.profile.career_wins,game.profile.pending_wager])==before,"Practice changed economy/career")
	if game.tuning.last.is_empty(): return
	var m: Dictionary=game.tuning.last.metrics
	var et: Variant=m.eighth_s if length<300 else m.quarter_s
	check(m.reaction_s!=null and float(m.reaction_s)>.20 and et!=null,"Missing reaction or ET")
	check(absf(float(m.total_s)-float(m.reaction_s)-float(et))<.0001,"Player RT / ET not separated")
	check(game.tuning.last.samples.size()>50 and not game.tuning.last.shifts.is_empty(),"Missing run telemetry / shifts")
	check(length>300 or m.quarter_s==null,"Eighth test fabricated a quarter result")
	await frame(); bounds("results")
	await click("tt_details"); bounds("telemetry")
	var plot: Rect2=game.tuning.graph_rect
	game.activate_at(plot.position+Vector2(plot.size.x*.75,plot.size.y*.5),"touch_3")
	check(game.tuning.cursor>game.tuning.last.samples.size()/2,"Touch telemetry scrub did not select data")
	var release:=InputEventScreenTouch.new(); release.index=3; release.pressed=false; game._input(release)
	var snap: Dictionary=game.car.telemetry(); await frame(); check(game.car.telemetry()==snap,"Telemetry review mutated simulation")
	root.get_texture().get_image().save_png("res://validation/tuning/telemetry_"+trans+("_phone" if game.is_portrait() else "_desktop")+".png")
	game.complete_race(); check(JSON.stringify([game.profile.credits,game.profile.xp,game.profile.races,game.profile.wins,game.profile.career_wins,game.profile.pending_wager])==before,"Repeated practice finish paid rewards")
	await click("tt_return")
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false); game.set_physics_process(false)
	game.profile=DriverProfile.new(); game.refresh_car()
	DirAccess.make_dir_recursive_absolute("res://validation/tuning")
	for phone in [false,true]:
		root.size=Vector2i(390,844) if phone else Vector2i(1200,760)
		game.go_garage(); await frame(); await click("open_tuning")
		check(game.tab=="tuning","Garage tuning action failed")
		for group in TuningSetup.GROUPS.size():
			await click("tt_group_%d"%group); bounds("tuning group")
			if TuningSetup.GROUPS[TuningSetup.GROUPS.keys()[group]].size()>4: await click("tt_rows"); bounds("more tuning")
		root.get_texture().get_image().save_png("res://validation/tuning/setup_"+("phone" if phone else "desktop")+".png")
		await click("tt_page_presets"); await click("tt_save"); await click("tt_rename")
		bounds("rename modal"); check(game.buttons.size()==2,"Rename modal leaked background actions")
		game.tuning.name_edit.text="My street setup"; await click("tt_name_save")
		check(game.profile.tuning_presets().street.name=="My street setup","Rename did not persist")
		await click("tt_preview")
		var preview_snapshot:=JSON.stringify([game.profile.hardware,game.profile.credits])
		for budget in 120:
			game.tuning.update()
			if not game.tuning.preview_result.is_empty(): break
		check(not game.tuning.preview_result.is_empty() and not game.tuning.preview_base_result.is_empty(),"Preset versus current estimate did not complete")
		check(preview_snapshot==JSON.stringify([game.profile.hardware,game.profile.credits]),"Preset measurement changed live state")
		await click("tt_load"); await click("tt_page_optimize"); bounds("optimizer")
		await click("tt_back"); await click("tt_back"); check(game.tab=="garage","Back did not return to garage")
		await drive(201.168,"manual5")
		await drive(402.336,"drag3")
		check(game.tuning.histories.size()>=2,"Run history not retained across distances")
	# Unassisted practice starts behind the beams; tree waits for the physical car.
	game.go_garage(); game.staging.assisted=false; game.start_practice(201.168)
	var initial: float=game.countdown
	for i in 120: game._physics_process(1.0/120)
	check(game.car.distance<0 and game.countdown==initial and not game.staging.beam(0),"Manual staging advanced without reaching the beam")
	game.go_garage(); game.staging.assisted=true
	game.profile=DriverProfile.new(); game.profile.vehicle_id="supra"
	game.profile.garage.supra={"stages":GameCatalog.blank_stages(),"hardware":GameCatalog.factory_build("supra")}
	game.profile.stages=[3,2,3,1,5,1,1,1]
	game.profile.hardware=VehicleBench.fixture("drag3",["ecu","billet","fuel_ethanol","turbo_race","boost_control","drag_wheels","lsd"])
	game.profile.tune_hardware("boost_by_gear",[.3,.7,1.1],false); game.refresh_car(); game.tuning.open()
	check(game.tuning.last.is_empty(),"Another vehicle's telemetry appeared under this car")
	game.profile.save_tune_slot("quarter","Quarter-mile setup")
	game.tuning.optimizer=TuneOptimizer.new(); game.tuning.optimizer.begin(game.profile,402.336)
	for trial in 1200:
		if game.tuning.optimizer.done: break
		game.tuning.optimizer.advance(9600)
	check(game.tuning.optimizer.done,"UI recommendation did not complete")
	for phone in [false,true]:
		root.size=Vector2i(390,844) if phone else Vector2i(1200,760)
		for section in ["setup","presets","optimize"]:
			game.tuning.page=section; game.tuning.group=1; game.tuning.slot="quarter"
			await frame(); bounds("equipped "+section)
			root.get_texture().get_image().save_png("res://validation/tuning/equipped_"+section+("_phone" if phone else "_desktop")+".png")
	var funds: int=game.profile.credits
	await click("tt_opt_apply")
	check(game.profile.credits==funds and game.profile.hardware.tune==game.tuning.optimizer.best_tune,"UI optimizer apply did not install the measured tune")
	game.start_practice(201.168)
	for tick in 384: game._physics_process(1.0/120)
	game.controls.hold("test","gas")
	for tick in 6000:
		game._physics_process(1.0/120)
		if game.screen=="practice_results": break
	check(game.screen=="practice_results","Optimized automatic did not complete landscape telemetry fixture")
	for window in [Vector2i(844,390),Vector2i(667,375)]:
		root.size=window; game.go_garage(); game.tuning.open()
		for section in ["setup","presets","optimize","results"]:
			game.tuning.page=section
			game.tuning.details=section=="results"
			if section=="setup":
				for group in TuningSetup.GROUPS.size():
					game.tuning.group=group; game.tuning.row_page=0; await frame(); bounds("landscape settings")
					for b in game.buttons:
						if str(b.id).begins_with("tt_"): check(minf(b.rect.size.x,b.rect.size.y)*float(window.y)/760>=44,"Small landscape tuning target "+str(b.id))
			await frame(); bounds("landscape "+section)
			for b in game.buttons:
				if str(b.id).begins_with("tt_"): check(minf(b.rect.size.x,b.rect.size.y)*float(window.y)/760>=44,"Small landscape action "+str(b.id))
		root.get_texture().get_image().save_png("res://validation/tuning/landscape_%d.png"%window.x)
	game.stop_presentation_audio(); await create_timer(.12).timeout; game.queue_free(); await process_frame
	print("TUNING UI / MODAL / DESKTOP+PHONE / PRACTICE / TELEMETRY / ZERO CAREER SIDE EFFECTS: ",checks," / ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
