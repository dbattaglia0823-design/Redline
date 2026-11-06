extends SceneTree

var game: Node2D
var failures:=0
var checks:=0
class LowEndCurve extends Drivetrain:
	func full_engine_torque(rpm: float) -> float:
		return super.full_engine_torque(rpm)+(10.0 if rpm<3000 else 0.0)
func check(value: bool,message: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	RosterTest.ready(game); game.sync_menu_size(); game.queue_redraw()
	for i in 5: game._process(.1); await process_frame
	await RenderingServer.frame_post_draw
func target(id: String) -> Dictionary:
	for entry in game.buttons:
		if entry.id==id: return entry
	check(false,"Missing visible action "+id); return {}
func click(id: String,touch: bool=false) -> void:
	var control: Control=game.native_workshop.targets.get(id)
	if is_instance_valid(control):
		var ancestor:=control.get_parent()
		while ancestor!=null and not ancestor is ScrollContainer: ancestor=ancestor.get_parent()
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await frame()
	var entry:=target(id)
	if entry.is_empty(): return
	var point: Vector2=game.to_global(entry.rect.get_center())
	# Exercise Godot's real event pipeline, rather than calling game._input.
	if touch:
		var event:=InputEventScreenTouch.new(); event.index=4; event.position=point; event.pressed=true
		root.push_input(event,true); event=event.duplicate(); event.pressed=false; root.push_input(event,true)
	else:
		var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.position=point; event.pressed=true
		root.push_input(event,true); event=event.duplicate(); event.pressed=false; root.push_input(event,true)
	await frame()
func run() -> void:
	var stock:=Drivetrain.new(); var low_end:=LowEndCurve.new()
	for engine in [stock,low_end]: engine.configure_vehicle(GameCatalog.spec("miata")); engine.configure(GameCatalog.blank_stages())
	check(is_equal_approx(stock.full_engine_torque(stock.redline_rpm*.75),low_end.full_engine_torque(stock.redline_rpm*.75)),"Powerband test does not isolate the low range")
	check(UpgradeStudio.engine_changed(stock,low_end),"Dyno misses low-RPM changes with identical high-RPM torque")
	var fixture:=DriverProfile.new()
	var initial_quote:=fixture.upgrade_quote(-1,-1,"induction","turbo_race")
	check(fixture.commit_upgrade_quote(-1,-1,"induction","turbo_race",JSON.stringify(initial_quote))=="Not enough credits" and fixture.hardware.parts.is_empty(),"Unaffordable bundle partially installed")
	fixture.hardware.owned_parts.append("fuel_street")
	var owned:=fixture.upgrade_quote(-1,-1,"induction","turbo_race")
	check(owned.cost==7000 and owned.items[0].cost==0 and owned.build.parts.fuel=="fuel_street","Owned support was charged or left unfitted")
	fixture.hardware.parts.fuel="fuel_ethanol"
	var equivalent:=fixture.upgrade_quote(-1,-1,"induction","turbo_race")
	check(equivalent.cost==7000 and equivalent.items.size()==1,"An equivalent fitted fuel system was replaced")
	check(fixture.commit_upgrade_quote(-1,-1,"induction","turbo_race",JSON.stringify(owned)).begins_with("Build changed"),"A stale quote was accepted")
	var blocked:=fixture.upgrade_quote(-1,-1,"converter","converter_race")
	check(blocked.reason=="Unknown component","Retired converter is still available")
	var supported:=fixture.upgrade_quote(-1,-1,"clutch","clutch_race")
	check(supported.stages[4]==0 and supported.items.size()==1,"Clutch quote still requires a gearbox stage")
	var old_save:=FileAccess.open(DriverProfile.SAVE_PATH,FileAccess.WRITE)
	old_save.store_string(JSON.stringify({"roster_version":2,"credits":50000,"vehicle_id":"miata","garage":{
		"miata":{"stages":[3,0,0,0,3,0,0,0],"hardware":GameCatalog.factory_build("miata")},
		"brz":{"stages":[1,0,0,0,0,0,0,0],"hardware":GameCatalog.factory_build("brz")}}}))
	old_save.close()
	var migrated:=DriverProfile.new()
	migrated.load_profile()
	check(migrated.highest_stage(0)==3 and migrated.highest_stage(4)==3,"Legacy tiers were not migrated to ownership")
	check(migrated.install_hardware("clutch_race").begins_with("Installed"),"Gearbox downgrade test could not fit the race clutch")
	var lower:=migrated.upgrade_quote(4,0)
	check(lower.items.size()==1 and lower.cost==0,"Gearbox downgrade still affects clutch fitment")
	var funds:=migrated.credits
	check(migrated.upgrade(4,0) and migrated.hardware.owned_parts.has("clutch_race") and migrated.hardware.parts.has("clutch"),"Gearbox downgrade changed clutch fitment")
	check(migrated.upgrade(4,3) and migrated.install_hardware("clutch_race").begins_with("Installed") and migrated.credits==funds,"Reinstalling gearbox tier and clutch charged again")
	check(migrated.upgrade(0,0) and migrated.select_vehicle("brz") and migrated.highest_stage(0)==1,"Ownership leaked between vehicles")
	check(migrated.upgrade(0,0) and migrated.upgrade_cost(0,2)==GameCatalog.PART_COSTS[0]*2,"Buying above ownership charged again for a lower tier")
	check(migrated.select_vehicle("miata") and migrated.stages[0]==0 and migrated.highest_stage(0)==3,"Vehicle switch lost equipped or owned tiers")
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false); game.set_physics_process(false)
	DirAccess.make_dir_recursive_absolute("res://validation/native_ui")
	for window in [Vector2i(1200,760),Vector2i(390,844),Vector2i(844,390)]:
		var phone: bool=window.x<1000
		var suffix: String={1200:"desktop",390:"phone",844:"landscape"}[window.x]
		root.size=window
		game.native_workshop.catalog_filter=-1
		game.profile=DriverProfile.new(); game.profile.credits=100000; game.go_garage(); game.refresh_car(); await frame()
		game.workshop.details=false
		check(game.native_workshop.visible,"Native Garage unavailable")
		check(game.font is FontFile and game.mono is FontFile,"Typography depends on system fonts")
		var garage:=target("hub_owned"); check(garage.get("native_control") is Button,"Garage action is not native")
		if window.x!=844: root.get_texture().get_image().save_png("res://validation/native_ui/garage_"+suffix+".png")
		await click("tab_performance",phone); await click("upgrade_system_0",phone); await click("hub_category_0",phone)
		check(not game.menu.hub.categories and not game.dock.visible,"Upgrade modal did not isolate the overview")
		check(game.buttons.filter(func(item): return str(item.id).begins_with("tab_")).is_empty(),"Modal exposes background navigation")
		var snapshot:=JSON.stringify([game.profile.hardware,game.profile.stages,game.profile.credits])
		await click("stage_pick_2",phone)
		check(snapshot==JSON.stringify([game.profile.hardware,game.profile.stages,game.profile.credits]),"Preview changed the save")
		var predicted: float=game.menu.hub.studio.candidate().peak_horsepower()
		if window.x!=844: root.get_texture().get_image().save_png("res://validation/native_ui/purchase_"+suffix+".png")
		await click("install_0_2",phone)
		check(game.profile.credits==97900 and game.profile.stages[0]==2,"Native event purchase did not charge exactly once")
		check(is_equal_approx(predicted,game.car.peak_horsepower()),"Preview differs from installed physics")
		await click("install_0_2",phone)
		check(game.profile.credits==97900,"Disabled purchase charged twice")
		await click("stage_pick_0",phone)
		var stock_hp: float=game.menu.hub.studio.candidate().peak_horsepower()
		check(stock_hp<predicted and game.car.peak_horsepower()==predicted,"Stock preview did not show the downgrade")
		check(game.native_workshop.targets.install_0_0.text=="Equip Free","Owned Stock tier did not show Equip Free")
		await click("install_0_0",phone)
		var downgraded:=DriverProfile.new()
		downgraded.load_profile()
		check(downgraded.stages[0]==0 and downgraded.highest_stage(0)==2 and downgraded.credits==97900,"Save lost the equipped or owned tier after downgrade")
		check(is_equal_approx(game.car.peak_horsepower(),stock_hp),"Installed downgrade disagreed with the preview")
		await click("stage_pick_1",phone); await click("install_0_1",phone)
		check(game.profile.stages[0]==1 and game.profile.credits==97900,"Intermediate tier was not free")
		await click("stage_pick_2",phone); await click("install_0_2",phone)
		check(game.profile.stages[0]==2 and game.profile.credits==97900 and is_equal_approx(game.car.peak_horsepower(),predicted),"Re-equipping the purchased tier changed cost or performance")
		await click("hw_pick_forged",phone)
		await click("hw_buy",phone)
		check(game.profile.credits==95100,"Native part installation charged incorrectly")
		check(game.profile.hardware.parts.get("internals","")=="forged","Part was not installed")
		game.glass.focused="details_toggle"; await frame()
		var key:=InputEventKey.new(); key.keycode=KEY_ENTER; key.physical_keycode=KEY_ENTER; key.pressed=true; root.push_input(key,true)
		key=key.duplicate(); key.pressed=false; root.push_input(key,true); await frame()
		check(game.workshop.details,"Keyboard Details action disconnected or activated twice")
		await click("hub_back",phone); await click("hub_category_0",phone)
		check(game.workshop.selected_hardware=="forged","Back navigation lost part selection")
		var saved:=DriverProfile.new(); saved.load_profile()
		check(saved.stages[0]==2 and saved.hardware.parts.get("internals","")=="forged","Native purchase did not persist")
		await click("hub_back",phone)
		for group in UpgradeStudio.GROUPS.size():
			await click("upgrade_system_%d"%group,phone)
			for entry in game.buttons:
				if entry.get("native_control") is Button:
					check(entry.rect.has_area() and Rect2(Vector2.ZERO,game.native_workshop.size).encloses(entry.rect),"Native target outside canvas")
		await click("upgrade_system_2",phone); await click("hub_category_14",phone)
		check(is_equal_approx(game.menu.hub.studio.candidate().peak_horsepower(),game.car.peak_horsepower()),"Weight comparison invented engine power")
		for i in 90: RaceAI.advance_estimates(1000)
		await frame()
		var resolved:=false
		for label in game.native_workshop.find_children("*","Label",true,false):
			if label.text.contains("1/4 est"): resolved=true
		check(resolved,"Async benchmark completed but native comparison stayed in measuring state")
		if window.x!=844: root.get_texture().get_image().save_png("res://validation/native_ui/weight_"+suffix+".png")
		await click("hub_back",phone); await click("upgrade_system_-1",phone)
		if phone:
			var scroller: ScrollContainer=game.native_workshop.find_child("CatalogList",true,false)
			var point: Vector2=scroller.get_global_rect().get_center()
			var scrollbar:=scroller.get_v_scroll_bar()
			var can_scroll:=scrollbar.max_value>scrollbar.page
			var finger:=InputEventScreenTouch.new(); finger.index=8; finger.pressed=true; finger.position=point
			root.push_input(finger,true)
			var drag:=InputEventScreenDrag.new(); drag.index=8; drag.position=point-Vector2(0,75)
			root.push_input(drag,true)
			finger=finger.duplicate(); finger.pressed=false; finger.position=drag.position; root.push_input(finger,true)
			await frame()
			check(game.menu.hub.categories and (not can_scroll or scroller.scroll_vertical>0),"Catalog swipe selected a part or failed to scroll")
			scroller.scroll_vertical=0; await frame()
		var search: LineEdit=game.native_workshop.search
		search.grab_focus()
		search.edit()
		for character in "turbocharger":
			var typing:=InputEventKey.new(); typing.pressed=true; typing.unicode=character.unicode_at(0)
			typing.keycode=KEY_SPACE if character==" " else 0
			root.push_input(typing,true)
		await frame()
		check(search.text=="turbocharger","Catalog search did not accept keyboard input")
		check(game.native_workshop.targets.hub_category_5.visible and not game.native_workshop.targets.hub_category_0.visible,"Search did not find the turbo by its part name")
		search.clear(); search.text_changed.emit(""); search.release_focus(); await frame()
		root.get_texture().get_image().save_png("res://validation/native_ui/catalog_"+suffix+".png")
		await click("hub_category_5",phone); await click("hw_pick_turbo_hybrid",phone)
		var quote: Dictionary=game.native_workshop.active_quote()
		var credits: int=game.profile.credits
		check(quote.cost==3200 and quote.items.size()==1,"Turbocharger should be a single purchase")
		var preview_hp: float=game.menu.hub.preview().peak_horsepower()
		await click("hw_buy",phone)
		check(game.profile.credits==credits-3200 and game.profile.hardware.parts.get("induction")=="turbo_hybrid","Turbocharger did not install exactly once")
		check(is_equal_approx(game.car.peak_horsepower(),preview_hp),"Turbocharger output differed from its preview")
		saved.load_profile()
		check(saved.hardware.parts.get("induction")=="turbo_hybrid" and saved.credits==credits-3200,"Turbocharger did not persist")
		var expected := {1:["intake_street","plenum","intake_velocity","intake_race"],3:["fuel_street","fuel_injectors","fuel_ethanol"],4:["ecu_street","ecu","ecu_track","ecu_race"],8:["clutch_street","clutch_twin","clutch_race"]}
		for category in expected:
			game.menu.hub.open_upgrade(category)
			await frame()
			for id in expected[category]:
				check(game.native_workshop.targets.has("hw_pick_"+id),"Shop is missing "+id)
		game.menu.hub.open_upgrade(6)
		await frame()
		check(game.native_workshop.targets.has("stage_pick_1") and not game.native_workshop.targets.has("hw_pick_progressive") and not game.native_workshop.targets.has("upgrade_section_tune"),"Nitrous shop still shows controller or tuning")
		game.go_garage(); await frame()
	var report:=FileAccess.open("res://validation/native_ui/results.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed":failures==0,"checks":checks,"actual_viewport_events":true},"  ")); report.close()
	print("NATIVE WORKSHOP: ","PASS" if failures==0 else "FAIL"," / ",checks," checks")
	game.stop_presentation_audio(); await create_timer(.12).timeout; game.queue_free(); await process_frame; await process_frame
	quit(0 if failures==0 else 1)
