extends SceneTree

var game: Node2D
var failures:=0
var checks:=0

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func frame() -> void:
	game.sync_menu_size()
	game.queue_redraw()
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw

func click(id: String,touch: bool=false) -> void:
	var point:=Vector2.INF
	for entry in game.buttons:
		if entry.id==id and not entry.get("disabled",false):
			point=game.to_global(entry.rect.get_center())
			break
	check(point!=Vector2.INF,"Unavailable action "+id)
	if point==Vector2.INF: return
	for pressed in [true,false]:
		if touch:
			var event:=InputEventScreenTouch.new()
			event.index=3
			event.position=point
			event.pressed=pressed
			root.push_input(event,true)
		else:
			var event:=InputEventMouseButton.new()
			event.button_index=MOUSE_BUTTON_LEFT
			event.position=point
			event.pressed=pressed
			root.push_input(event,true)
	await frame()

func screenshot(name: String) -> void:
	root.get_texture().get_image().save_png("res://.qa/customization_studio/"+name+".png")

func stage() -> CustomizationStage:
	for child in game.native_workshop.find_children("*","Control",true,false):
		if child is CustomizationStage and not child.is_queued_for_deletion(): return child
	return null

func bounds(name: String) -> void:
	var canvas:=Rect2(Vector2.ZERO,Vector2(root.content_scale_size))
	for entry in game.buttons:
		check(canvas.encloses(entry.rect),"Offscreen "+name+" / "+entry.id)
	var studio_targets: Array=game.buttons.filter(func(item): return str(item.id).begins_with("custom_"))
	for i in studio_targets.size():
		for j in range(i+1,studio_targets.size()):
			check(not studio_targets[i].rect.intersects(studio_targets[j].rect),"Overlapping "+name+" / "+studio_targets[i].id+" / "+studio_targets[j].id)
	var groups: Array=game.buttons.filter(func(item): return str(item.id).begins_with("custom_group_"))
	check(groups.size()==4,"Studio needs four primary groups")

func run() -> void:
	root.size=Vector2i(1200,760)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.profile=DriverProfile.new()
	game.profile.credits=18500
	game.profile.xp=10000000
	game.profile.save()
	game.refresh_car()
	DirAccess.make_dir_recursive_absolute("res://.qa/customization_studio")
	await frame()
	await click("hub_owned")
	await click("tab_style")
	check(game.tab=="style" and stage()!=null,"Design studio did not open")
	bounds("desktop")
	var balance: int=game.profile.credits
	var saved:=FileAccess.get_file_as_string(DriverProfile.SAVE_PATH)
	await click("custom_pick_1")
	await click("custom_category_finish")
	await click("custom_pick_2")
	var custom: CustomizationView=game.menu.customize
	check(custom.candidate.paint==1 and custom.candidate.finish==2 and stage().look.finish==2,"Paint and finish did not preview together")
	check(FileAccess.get_file_as_string(DriverProfile.SAVE_PATH)==saved and game.profile.credits==balance,"Preview changed save or balance")
	screenshot("desktop_finishes")
	await click("custom_category_paint")
	screenshot("desktop_paint")
	await click("custom_category_finish")
	await click("custom_compare")
	check(stage().look==game.profile.appearance_for(game.profile.vehicle_id),"Installed comparison did not use saved appearance")
	await click("custom_install")
	check(game.profile.appearance.finish==2 and game.profile.credits==balance-450 and custom.candidate.paint==1,"Finish purchase did not preserve the other draft")
	await click("custom_group_wheels")
	await click("custom_pick_4")
	await create_timer(.5).timeout
	await frame()
	check(stage().pose.x>.99 and stage().look.design==4,"Wheel studio did not zoom to the draft wheel")
	await click("custom_zoom_in")
	await create_timer(.5).timeout
	await frame()
	check(stage().pose.y>1.1,"Zoom did not move the camera")
	screenshot("desktop_wheel")
	await click("custom_group_calipers")
	await click("custom_pick_1")
	await click("custom_install")
	check(game.profile.appearance.caliper==1 and stage().look.design==4,"Caliper purchase did not preserve wheel draft")
	await click("custom_camera")
	await create_timer(.5).timeout
	await frame()
	check(stage().pose.x<.01,"Full car override did not move the camera")
	var restored:=DriverProfile.new()
	restored.load_profile()
	check(restored.appearance.caliper==1 and restored.appearance.finish==2 and restored.paint==0,"Save loaded draft rather than installed parts")

	root.size=Vector2i(390,844)
	await frame()
	await click("custom_group_paint",true)
	await click("custom_pick_4",true)
	await frame()
	bounds("phone paint")
	screenshot("phone_paint")
	await click("custom_group_wheels",true)
	await click("custom_category_rim",true)
	await click("custom_pick_1",true)
	await create_timer(.5).timeout
	await frame()
	check(stage().pose.x>.99 and stage().look.rim==1,"Phone rim card failed to preview")
	screenshot("phone_wheel")
	await click("custom_group_tint",true)
	await click("custom_pick_2",true)
	check(stage().look.tint==2,"Phone tint sample failed to preview")
	await create_timer(.5).timeout
	await frame()
	screenshot("phone_tint")
	root.size=Vector2i(844,390)
	await frame()
	await click("custom_group_paint",true)
	await click("custom_trim",true)
	await create_timer(.5).timeout
	await frame()
	bounds("short landscape trim")
	screenshot("landscape_studio")
	await click("custom_trim",true)
	await click("custom_group_wheels",true)
	await click("custom_category_design",true)
	await click("custom_pick_4",true)
	await click("custom_install",true)
	check(game.profile.appearance.design==4 and game.profile.owned_appearance.has("design:4"),"Short landscape Deep dish purchase failed")

	game.profile.reduced_motion=true
	for dimensions in [Vector2i(360,780),Vector2i(667,375),Vector2i(1920,1080)]:
		root.size=dimensions
		await frame()
		bounds(str(dimensions))
	game.toast_left=0
	game.profile.credits=100000000
	root.size=Vector2i(1200,760)
	var roster_count:=0
	for id in GameCatalog.CAR_IDS:
		var switched: bool=game.profile.select_vehicle(id) if game.profile.garage.has(id) else game.profile.buy_vehicle(id)
		check(switched,"Could not switch to "+id)
		if not switched: continue
		game.refresh_car()
		custom.open()
		custom.action("custom_group_paint")
		custom.action("custom_pick_4")
		await frame()
		check(stage()!=null and stage().look.paint==4,"Paint preview failed on "+id)
		custom.action("custom_group_wheels")
		custom.action("custom_pick_2")
		custom.action("custom_group_calipers")
		custom.action("custom_pick_1")
		await frame()
		check(stage()!=null and stage().pose.x==1 and stage().look.design==2 and stage().look.caliper==1,"Wheel preview failed on "+id)
		if id in ["gtr","chiron"]: screenshot(id+"_wheel")
		roster_count+=1
	check(VehicleAppearance._textures.size()<=32,"Texture cache exceeded its cap")
	game.stop_presentation_audio()
	game.queue_free()
	await process_frame
	print("CUSTOMIZATION STUDIO: ",checks," checks / ",roster_count," vehicles / ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
