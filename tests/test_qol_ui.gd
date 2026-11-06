extends SceneTree
var game: Node2D
var checks := 0
var failures := 0
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run_checks")
func frame() -> void:
	RosterTest.ready(game)
	if game!=null and game.race_start_pending: game._process(0)
	game.sync_menu_size(); game.queue_redraw()
	for i in 4: game._process(.1); await process_frame
	await RenderingServer.frame_post_draw
func key(code: Key,shift: bool=false,ctrl: bool=false) -> void:
	var event := InputEventKey.new(); event.keycode=code; event.pressed=true; event.shift_pressed=shift; event.ctrl_pressed=ctrl
	game.handle_key_input(event)
func capture(name: String) -> void:
	for i in game.buttons.size():
		var a: Dictionary=game.buttons[i]
		if game.is_portrait(): check(a.rect.size.y>=64,"Small touch target: "+str(a.id))
		for j in range(i+1,game.buttons.size()): check(not a.rect.intersects(game.buttons[j].rect),"Overlapping targets: "+str(a.id)+" / "+str(game.buttons[j].id))
	DirAccess.make_dir_recursive_absolute("res://validation/qol")
	root.get_texture().get_image().save_png("res://validation/qol/"+name+("_phone" if game.is_portrait() else "_desktop")+".png")
func click(id: String) -> void:
	var control: Control=game.native_workshop.targets.get(id)
	if is_instance_valid(control):
		var ancestor:=control.get_parent()
		while ancestor!=null and not ancestor is ScrollContainer: ancestor=ancestor.get_parent()
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await frame()
	for item in game.buttons:
		if item.id == id:
			var e := InputEventScreenTouch.new(); e.index=3; e.pressed=true; e.position=game.to_global(item.rect.get_center()); game._input(e); e.pressed=false; game._input(e)
			await frame(); return
	check(false,"Missing action: "+id)
func run_checks() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false); game.set_physics_process(false); await frame()
	game.profile.credits=10000000
	game.profile.xp=100000
	for id in GameCatalog.CAR_IDS: game.profile.buy_vehicle(id,false)
	for phone in [false,true]:
		game.get_window().size=Vector2i(390,844) if phone else Vector2i(1200,760)
		game.go_garage(); await frame()
		await click("tab_performance"); await click("hub_category_0"); await click("hw_pick_forged")
		key(KEY_TAB,true,true); await frame(); key(KEY_TAB,false,true); await frame(); await click("hub_category_0")
		check(game.workshop.selected_hardware=="forged" and game.workshop.mode=="hardware","Dock exit lost upgrade selection")
		var back := InputEventMouseButton.new(); back.button_index=MOUSE_BUTTON_XBUTTON1; back.pressed=true; game._input(back); await frame()
		check(game.menu.hub.categories,"Mouse Back did not close component")
		game.go_garage(); await frame(); game.glass.focused=""; key(KEY_TAB,true)
		var ids: Array=[]
		for b in game.buttons:
			if not b.get("disabled",false) and not ids.has(b.id): ids.append(b.id)
		check(game.glass.focused==str(ids[-1]),"Reverse Tab skipped last action")
		game.profile.select_vehicle(GameCatalog.CAR_IDS[-1]); game.refresh_car(); await frame(); await click("hub_owned")
		check(game.menu.hub.owned_page==int((game.profile.garage.size()-1)/4),"Active car page not opened")
		var active: String=game.profile.vehicle_id; key(KEY_LEFT); await frame()
		check(game.menu.hub.owned_selection!=active and game.profile.vehicle_id==active,"Owned keyboard preview equipped or failed")
		game.go_garage(); await frame(); await click("tab_dealer"); await click("shop_class_E"); key(KEY_HOME); await frame()
		check(game.dealer_index==GameCatalog.CAR_IDS.find(game.menu.dealer.filtered()[0]),"Dealer Home failed")
		key(KEY_END); await frame(); check(game.dealer_index==GameCatalog.CAR_IDS.find(game.menu.dealer.filtered()[-1]),"Dealer End failed")
		await click("shop_classes"); check(game.menu.dealer.class_picker,"Class picker not opened"); capture("dealer_classes")
		await click("shop_class_S"); check(game.menu.dealer.class_filter==6,"Class selection failed")
		game.go_garage(); await frame(); await click("tab_style")
		var money: int=game.profile.credits; var look: Dictionary=game.profile.appearance_for(active).duplicate(true)
		check(not game.action_enabled("custom_install"),"Installed cosmetic accepts purchase")
		var original: int=int(look.paint); game.action("custom_category_paint"); game.action("custom_pick_%d"%((original+1)%6)); await frame()
		check(game.menu.customize.has_preview() and game.action_enabled("custom_discard"),"Discard unavailable for changed preview"); capture("cosmetic_preview")
		await click("custom_discard")
		check(not game.menu.customize.has_preview() and game.profile.credits==money and game.profile.appearance_for(active)==look,"Discard mutated save or did not revert")
		game.profile.credits=100
		check(game.missing_credits(700)=="Need $600 more","Shortfall is full price")
		game.go_garage(); game.action("race_menu"); game.wager=50; await frame(); await click("bet_clear")
		check(game.wager==0 and not game.action_enabled("bet_clear") and game.profile.credits==100,"No wager changed money or failed"); capture("no_wager")
		game.profile.credits=1000000
	var f:=FileAccess.open("res://validation/qol_ui_results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":failures==0,"checks":checks,"window_sizes":2},"  ")); f.close()
	print("QOL UI: ","PASS" if failures==0 else "FAIL"," / ",checks," checks")
	game.stop_presentation_audio(); await create_timer(.12).timeout
	game.queue_free(); await process_frame; await process_frame; call_deferred("quit",0 if failures==0 else 1)

