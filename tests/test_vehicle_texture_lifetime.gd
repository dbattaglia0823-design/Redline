extends SceneTree

class RetainedCars extends Node2D:
	var draws := 0
	var models := ["miata", "mustang"]
	func _draw() -> void:
		draws += 1
		draw_rect(Rect2(0,0,640,280),Color("14212a"))
		for i in models.size():
			VehicleRenderer.draw(self,Vector2(18,12+i*130),2.4,models[i],VehicleAppearance.normalize({}),null,false,Vector2.ZERO,0,false,1)

var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func rendered() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func churn_cache() -> void:
	# Visit more artwork than the LRU can hold, on later frames than the cards.
	for index in RosterData.IDS.size():
		var model: String=RosterData.IDS[index]
		var d := VehicleAppearance.definition(model)
		VehicleAppearance.texture(str(d.body) % [3,"metallic"])
		VehicleAppearance.texture(d.layers.tint)
		RimArt.face(index%12,index%9,512)
		await process_frame
	VehicleAppearance.texture(str(VehicleAppearance.definition("gr86").body) % [1,"matte"])
	await process_frame

func previews(node: Node) -> Array[VehiclePreview]:
	var result: Array[VehiclePreview]=[]
	if node is VehiclePreview: result.append(node)
	for child in node.get_children(): result.append_array(previews(child))
	return result

func selector_frame(game: Node2D) -> void:
	game.sync_menu_size()
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw

func selector_switches() -> void:
	var game: Node2D=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.profile.credits=10000000
	game.profile.xp=100000
	game.profile.reduced_motion=true
	for id in ["gr86","mustang","supra_gr"]: game.profile.buy_vehicle(id,false)
	game.glass.reduced_motion=true
	for dimensions in [Vector2i(1200,760),Vector2i(393,852)]:
		root.size=dimensions
		game.go_garage()
		await selector_frame(game)
		game.action("hub_owned")
		for i in 12:
			var id: String=["miata","gr86","mustang","supra_gr"][i%4]
			game.action("hub_pick_"+id)
			await selector_frame(game)
			check(game.menu.hub.owned_selection==id,"Selector failed to switch to "+id)
		var views := previews(game.native_workshop)
		check(views.size()>=5,"Expected hero and four vehicle thumbnails")
		var bodies: Array[WeakRef]=[]
		for view in views:
			var path := str(VehicleAppearance.definition(view.model).body) % [int(view.look.paint),["gloss","matte","metallic"][int(view.look.finish)]]
			bodies.append(weakref(VehicleAppearance.texture(path)))
		var before := root.get_texture().get_image()
		await churn_cache()
		await RenderingServer.frame_post_draw
		for body in bodies: check(body.get_ref()!=null,"Selector lost displayed vehicle artwork under cache pressure")
		var after := root.get_texture().get_image()
		# Compare each vehicle region; unrelated HUD animations may continue.
		var pixel_scale := Vector2(after.get_size())/Vector2(root.content_scale_size)
		for view in views:
			var bounds := view.get_global_rect()
			var crop := Rect2i(bounds.position*pixel_scale,bounds.size*pixel_scale).intersection(Rect2i(Vector2i.ZERO,after.get_size()))
			if crop.has_area(): check(before.get_region(crop).get_data()==after.get_region(crop).get_data(),"Displayed selector vehicle changed after cache eviction: "+view.model)
		after.save_png("res://.qa/texture-lifetime/selector_%d.png"%dimensions.x)
	game.stop_presentation_audio()
	game.queue_free()
	await process_frame

func run() -> void:
	root.size=Vector2i(640,280)
	var cards := RetainedCars.new()
	root.add_child(cards)
	var before := await rendered()
	var draws := cards.draws
	var path := str(VehicleAppearance.definition("miata").body) % [0,"gloss"]
	var body: WeakRef = weakref(VehicleAppearance._textures[path])
	await churn_cache()
	check(not VehicleAppearance._textures.has(path),"Cache churn must evict the original body")
	check(body.get_ref()!=null,"Retained thumbnail lost its body texture after cache eviction")
	var after := await rendered()
	check(cards.draws==draws,"Regression must exercise retained draw commands without redrawing cards")
	check(before.get_data()==after.get_data(),"Thumbnail artwork changed/turned white after cache eviction")
	DirAccess.make_dir_recursive_absolute("res://.qa/texture-lifetime")
	before.save_png("res://.qa/texture-lifetime/before.png")
	after.save_png("res://.qa/texture-lifetime/after.png")
	# Redrawing releases the previous selection, rather than growing a per-view cache.
	cards.models=["gr86"]
	cards.queue_redraw()
	await rendered()
	check(body.get_ref()==null,"Redrawing retained obsolete vehicle artwork")
	cards.queue_free()
	await process_frame
	await selector_switches()
	print("RETAINED VEHICLE TEXTURES / MULTI-CAR CACHE EVICTION: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
