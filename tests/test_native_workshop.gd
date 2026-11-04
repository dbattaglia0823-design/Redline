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
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false); game.set_physics_process(false)
	DirAccess.make_dir_recursive_absolute("res://validation/native_ui")
	for phone in [false,true]:
		root.size=Vector2i(390,844) if phone else Vector2i(1200,760)
		game.profile=DriverProfile.new(); game.profile.credits=100000; game.go_garage(); game.refresh_car(); await frame()
		game.workshop.details=false
		check(game.native_workshop.visible,"Native Garage unavailable")
		check(game.font is FontFile and game.mono is FontFile,"Typography depends on system fonts")
		var garage:=target("hub_owned"); check(garage.get("native_control") is Button,"Garage action is not native")
		root.get_texture().get_image().save_png("res://validation/native_ui/garage_"+("phone" if phone else "desktop")+".png")
		await click("tab_performance",phone); await click("upgrade_system_0",phone); await click("hub_category_0",phone); await click("upgrade_section_basic",phone)
		check(not game.menu.hub.categories and not game.dock.visible,"Upgrade modal did not isolate the overview")
		check(game.buttons.filter(func(item): return str(item.id).begins_with("tab_")).is_empty(),"Modal exposes background navigation")
		var snapshot:=JSON.stringify([game.profile.hardware,game.profile.stages,game.profile.credits])
		await click("stage_pick_2",phone)
		check(snapshot==JSON.stringify([game.profile.hardware,game.profile.stages,game.profile.credits]),"Preview changed the save")
		var predicted: float=game.menu.hub.studio.candidate().peak_horsepower()
		root.get_texture().get_image().save_png("res://validation/native_ui/purchase_"+("phone" if phone else "desktop")+".png")
		await click("install_0_2",phone)
		check(game.profile.credits==97900 and game.profile.stages[0]==2,"Native event purchase did not charge exactly once")
		check(is_equal_approx(predicted,game.car.peak_horsepower()),"Preview differs from installed physics")
		await click("install_0_2",phone)
		check(game.profile.credits==97900,"Disabled purchase charged twice")
		await click("hw_slot_0",phone); await click("hw_pick_forged",phone)
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
		for group in 4:
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
		root.get_texture().get_image().save_png("res://validation/native_ui/weight_"+("phone" if phone else "desktop")+".png")
		game.go_garage(); await frame()
	var report:=FileAccess.open("res://validation/native_ui/results.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed":failures==0,"checks":checks,"actual_viewport_events":true},"  ")); report.close()
	print("NATIVE WORKSHOP: ","PASS" if failures==0 else "FAIL"," / ",checks," checks")
	game.stop_presentation_audio(); await create_timer(.12).timeout; game.queue_free(); await process_frame; await process_frame
	quit(0 if failures==0 else 1)
