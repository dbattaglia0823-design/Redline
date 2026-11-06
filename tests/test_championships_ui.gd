extends SceneTree
var game: Node2D
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	RosterTest.ready(game); game._process(0); game.sync_menu_size(); game.queue_redraw()
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
func click(id: String) -> void:
	var point:=Vector2(-1,-1)
	for item in game.buttons:
		if item.id==id: point=game.to_global(item.rect.get_center())
	check(point.x>=0,"Missing career action: "+id)
	var e: InputEvent
	if root.size.x<1000:
		e=InputEventScreenTouch.new(); e.index=6
	else:
		e=InputEventMouseButton.new(); e.button_index=MOUSE_BUTTON_LEFT
	e.pressed=true; e.position=point; root.push_input(e,true)
	e=e.duplicate(); e.pressed=false; root.push_input(e,true); await frame()
func key(code: Key,down: bool=true) -> void:
	var e:=InputEventKey.new(); e.physical_keycode=code; e.pressed=down; game._input(e)
func bounds(label: String) -> void:
	var region:=Rect2(Vector2.ZERO,Vector2(root.content_scale_size))
	for i in game.buttons.size():
		check(region.encloses(game.buttons[i].rect),"Offscreen "+label+" / "+str(game.buttons[i].id))
		for j in range(i+1,game.buttons.size()): check(not game.buttons[i].rect.intersects(game.buttons[j].rect),"Overlapping "+label+" / "+str(game.buttons[i].id)+" / "+str(game.buttons[j].id))
func race_player() -> void:
	for i in 384: game._physics_process(1.0/120)
	key(KEY_W)
	for i in 10000:
		if game.car.upshift_ready():
			if game.car.control_mode=="hpattern": key(KEY_SHIFT); key(KEY_0+game.car.gear+1); key(KEY_SHIFT,false)
			elif game.car.control_mode!="automatic": key(KEY_E); key(KEY_E,false)
		game._physics_process(1.0/120)
		if game.screen in ["results","practice_results"]: break
	key(KEY_W,false); await frame()
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.set_process(false); game.set_physics_process(false); game.profile=DriverProfile.new(); game.refresh_car()
	DirAccess.make_dir_recursive_absolute("res://.qa/class_career_expanded")
	for phone in [false,true]:
		root.size=Vector2i(390,844) if phone else Vector2i(1200,760)
		game.go_garage(); game.tab="races"; game.career_board.active=false
		game.event_index=0; game.selected_opponent=0
		RaceAI.request_estimate(game.current_contract(),game.FINISH)
		RaceAI.request_estimate(RaceAI.player_contract(game.profile),game.FINISH)
		for step in 40: RaceAI.advance_estimates(1200)
		await frame()
		bounds("street series")
		root.get_texture().get_image().save_png("res://.qa/class_career_expanded/street_"+("phone" if phone else "desktop")+".png")
		await click("open_championships")
		bounds("class picker")
		root.get_texture().get_image().save_png("res://.qa/class_career_expanded/classes_"+("phone" if phone else "desktop")+".png")
		for letter in Championships.CLASSES:
			await click("cb_class_"+letter); bounds("rival "+letter)
			if letter=="S": check(not game.action_enabled("race"),"Locked class can enter")
			await click("cb_back")
		await click("cb_open"); bounds("open events"); await click("cb_back")
		await click("cb_class_E"); bounds("E rival")
		for step in 40: RaceAI.advance_estimates(1200)
		await frame()
		root.get_texture().get_image().save_png("res://.qa/class_career_expanded/rival_"+("phone" if phone else "desktop")+".png")
		await click("cb_back"); await click("cb_back")
		check(not game.career_board.active,"Back failed to restore original street series")
	# A brand-new stock starter must be able to beat the first class rival.
	root.size=Vector2i(1200,760); game.profile=DriverProfile.new(); game.refresh_car(); game.career_board.open(); game.career_board.select_series("E")
	RosterTest.ready(game); await frame(); await click("race")
	check(game.screen=="race" and not game.profile.pending_wager.is_empty(),"Class race failed to start")
	await race_player()
	check(game.screen=="results" and game.result_win and game.profile.championship_wins.get("E",0)==1,"Stock starter cannot beat first class racer")
	var money: int=game.profile.credits; game.complete_race(); check(game.profile.credits==money,"Results granted duplicate class reward")
	root.get_texture().get_image().save_png("res://.qa/class_career_expanded/first_victory.png")
	root.size=Vector2i(390,844); await frame(); bounds("phone time slip")
	root.get_texture().get_image().save_png("res://.qa/class_career_expanded/results_phone.png")
	root.size=Vector2i(844,390); await frame(); bounds("landscape time slip")
	root.size=Vector2i(1200,760); await frame(); bounds("desktop time slip")
	await click("next_rival"); await click("race")
	check(game.active_distance==201.168,"Championship eighth-mile heat was forced to a quarter mile")
	await race_player(); check(game.screen=="results" and game.player_finish>0 and game.profile.championship_wins.E==(2 if game.result_win else 1),"Short championship timing or progression failed")
	game.go_garage(); game.tab="races"; game.career_board.select_series("OPEN"); game.career_board.selected="open_3"
	await frame(); await click("race"); check(game.active_distance==804.672,"Open half-mile distance not honored")
	await race_player(); check(game.screen=="results" and game.player_finish>0,"Long open race did not finish")
	check(not game.profile.career_claims.has("open_3"),"Losing long race claimed a first-win bonus")
	await click("next_rival")
	check(game.career_board.selected=="open_4","Next Race did not advance to the next open-class rival")
	# Full mechanical upgrade -> tune -> save -> practice -> championship loop.
	game.go_garage(); game.profile.credits=80000; game.profile.xp=20000; game.profile.career_wins=[5,5,5]; game.profile.legacy_class_access=["D","C","B","A","S"]; await frame()
	await click("tab_performance"); await click("hub_category_0"); await click("install_0_1"); await click("hub_back")
	game.menu.hub.studio.system=0; game.menu.hub.open_upgrade(4); await frame()
	await click("hw_pick_ecu"); await click("hw_buy"); await click("upgrade_section_tune"); await click("open_tuning")
	check(game.tab=="tuning","Upgrades did not connect to tuning")
	await click("tt_plus_launch_rpm"); var launch: float=game.car.launch_rpm
	await click("tt_page_presets"); await click("tt_save")
	check(game.profile.tuning_presets().has("street"),"Tuning preset not saved")
	await click("tt_drive"); await race_player()
	check(game.screen=="practice_results" and not game.tuning.last.is_empty(),"Upgraded practice failed")
	await click("tt_details"); bounds("practice telemetry"); await click("tt_return"); await click("tt_back")
	game.go_garage(); game.tab="races"; game.career_board.open(); RosterTest.ready(game)
	var measured:=PerformanceClasses.request(game.profile.vehicle_id,game.profile.stages,game.profile.hardware)
	game.career_board.select_series(str(measured["class"])); await frame(); await click("race"); await race_player()
	check(game.screen=="results" and game.result_win,"Tuned build could not compete in its class")
	game.go_garage(); check(game.profile.buy_vehicle("brz"),"Earned vehicle purchase failed"); game.refresh_car()
	RosterTest.ready(game); game.tab="races"; game.career_board.open()
	var next_class: String=PerformanceClasses.factory_class("brz")
	game.career_board.select_series(next_class); await frame(); await click("race"); await race_player()
	check(game.screen=="results" and game.result_win,"Second car could not compete in another class")
	game.go_garage(); game.profile.select_vehicle("miata"); game.refresh_car()
	check(game.car.launch_rpm==launch and game.profile.tuning_presets().has("street"),"Car switching lost tuning or presets")
	var restored:=DriverProfile.new(); restored.load_profile()
	check(restored.garage.has("brz") and restored.career_wins==[5,5,5] and not restored.event_records.is_empty(),"Integrated save lost ownership, legacy career or race records")
	game.go_garage(); game.tab="races"; game.career_board.open()
	for window in [Vector2i(844,390),Vector2i(667,375)]:
		root.size=window; game.career_board.picker=true; await frame(); bounds("landscape classes")
		for b in game.buttons:
			if str(b.id).begins_with("cb_"): check(minf(b.rect.size.x,b.rect.size.y)*float(window.y)/760>=44,"Small landscape class target")
		await click("cb_class_E"); bounds("landscape rival")
		for b in game.buttons:
			if str(b.id).begins_with("cb_") or b.id in ["race","bet_more","bet_less","bet_clear"]: check(minf(b.rect.size.x,b.rect.size.y)*float(window.y)/760>=44,"Small landscape race target")
		root.get_texture().get_image().save_png("res://.qa/class_career_expanded/rival_landscape_%d.png"%window.x)
	# Enter the real final race, run the solver, and verify the trophy and result screen.
	game.go_garage(); game.tab="races"
	game.profile.credits=1000000
	game.profile.xp=100000
	game.profile.championship_wins={"E":10,"D":10,"C":10,"B":10,"A":10,"S":9}
	check(game.profile.buy_vehicle("demon"),"Boss test could not purchase a legal S car")
	game.profile.stages=[3,2,3,1,5,3,0,1]
	game.refresh_car()
	game.career_board.select_series("S")
	for window in [Vector2i(1200,760),Vector2i(390,844),Vector2i(844,390)]:
		root.size=window
		await frame()
		for step in 40: RaceAI.advance_estimates(1200)
		await frame(); bounds("boss ladder")
		var rungs:=0
		for entry in game.buttons:
			if str(entry.id).begins_with("cb_rival_"): rungs+=1
		check(rungs==10,"Boss ladder did not show all ten rivals")
		root.get_texture().get_image().save_png("res://.qa/class_career_expanded/boss_ladder_%d.png"%window.x)
	game.career_board.selected="class_S_6"
	await frame(); await click("race")
	check(game.screen=="race" and game.active_distance==201.168 and game.nitrous_lock_reason()=="MOTOR ONLY","Motor-only heat did not apply its distance and nitrous rule")
	key(KEY_SPACE)
	check(not game.nitrous_input(),"Motor-only heat allowed keyboard nitrous")
	key(KEY_SPACE,false)
	game.go_garage(); game.tab="races"; game.career_board.select_series("S")
	root.size=Vector2i(390,844)
	await frame(); await click("race")
	check(game.screen=="race" and game.active_contract.get("boss",false),"Boss race did not start")
	root.get_texture().get_image().save_png("res://.qa/class_career_expanded/boss_intro.png")
	await race_player()
	check(game.screen=="results" and game.result_win and Championships.trophies(game.profile)==6,"Final boss battle did not award the sixth trophy")
	check(game.result_bonus==Championships.BONUSES[-1],"Final boss battle paid the wrong bonus")
	check(game.result_base_pay==int(game.active_contract.purse),"Time slip included the trophy bonus in base pay")
	bounds("boss results")
	root.get_texture().get_image().save_png("res://.qa/class_career_expanded/boss_victory.png")
	await click("next_rival")
	check(game.career_board.picker,"Final victory did not return to the completed career overview")
	game.stop_presentation_audio(); await create_timer(.12).timeout; game.queue_free(); await process_frame
	print("CLASS CAREER UI / PHONE / STARTER WIN / UPGRADE-TUNE-TEST-RACE / SECOND VEHICLE / SAVE: ",checks," / ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
