extends "res://tests/test_main_navigation.gd"

class CarArt extends Node2D:
	var model := "miata"
	var car := Drivetrain.new()
	var look := VehicleAppearance.normalize({})
	func _draw() -> void:
		VehicleRenderer.draw(self,Vector2.ZERO,1000.0/232.0,model,look,car,true,Vector2.ZERO,0,false,2)

func capture(art: Node2D) -> Image:
	art.queue_redraw()
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func run() -> void:
	check(VehicleAppearance.normalize({}).design==1,"New default is not six spoke")
	check(VehicleAppearance.PRICES.design[1]==0,"Default six spoke is not free")
	var p:=DriverProfile.new()
	p.appearance.design=0; p.snapshot_vehicle()
	p.garage.mustang={"paint":0,"wheels":0,"stages":GameCatalog.blank_stages(),"hardware":GameCatalog.factory_build("mustang"),"appearance":VehicleAppearance.normalize({"design":5,"rim":4,"caliper":2})}
	p.save()
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DriverProfile.SAVE_PATH))
	saved.erase("wheel_default_version"); saved.erase("integrity"); saved.erase("save_format")
	var file:=FileAccess.open(DriverProfile.SAVE_PATH,FileAccess.WRITE); file.store_string(JSON.stringify(saved)); file.close()
	p=DriverProfile.new(); p.load_profile()
	check(p.appearance.design==1 and p.owned_appearance.has("design:1"),"Existing factory wheels did not migrate to owned six spokes")
	check(p.garage.mustang.appearance.design==5 and p.garage.mustang.appearance.rim==4,"Migration changed a chosen custom wheel")
	check(p.install_appearance("design",0).begins_with("Equipped") or p.appearance.design==0,"Split five cannot be selected independently")
	p.save(); p=DriverProfile.new(); p.load_profile()
	check(p.appearance.design==0,"Versioned save changed an explicitly chosen split five")
	root.size=Vector2i(1000,360); root.content_scale_size=Vector2i(1000,360)
	var art:=CarArt.new(); root.add_child(art)
	var sheet:=Image.create(1500,720,false,Image.FORMAT_RGBA8); sheet.fill(Color("192129"))
	var closeups:=Image.create(1400,1080,false,Image.FORMAT_RGBA8); closeups.fill(Color("192129"))
	DirAccess.make_dir_recursive_absolute("res://.qa/default-wheels/screens")
	for i in GameCatalog.CAR_IDS.size():
		var id: String=GameCatalog.CAR_IDS[i]
		art.model=id; art.car.configure_vehicle(GameCatalog.spec(id)); art.car.configure_build(GameCatalog.factory_build(id),id,false); art.car.reset()
		var still:=await capture(art)
		var d:=VehicleAppearance.definition(id)
		for axle in 2:
			var source:=VehicleAppearance.texture(d.stock_wheels[axle])
			var radii: Array=d.get("wheel_radii",[d.radius,d.radius])
			var tire:=RimArt.tire_only(source,float(d.rim_radius[axle])/float(radii[axle]),float(radii[axle])).get_image()
			check(tire.get_pixel(tire.get_width()/2,tire.get_height()/2).a==0,"Baked hub remains in tire layer: "+id)
			check(tire.get_pixel(tire.get_width()/2,0).a==0,"Bodywork remains above tire: "+id)
			var center:=VehicleAppearance.visual_wheel_anchor(d,axle)
			var r:=ceili(float(radii[axle])+3)
			var crop:=still.get_region(Rect2i(Vector2i(center)-Vector2i.ONE*r,Vector2i.ONE*r*2)); crop.resize(130,130,Image.INTERPOLATE_LANCZOS)
			closeups.blit_rect(crop,Rect2i(0,0,130,130),Vector2i((i%5)*280+axle*140,(i/5)*180+22))
		var tile:=still.duplicate(); tile.resize(300,108,Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(tile,Rect2i(0,0,300,108),Vector2i((i%5)*300,(i/5)*120))
		art.car.wheel_angle=.38; art.car.rolling_wheel_angle=.56
		var rotated:=await capture(art)
		check(still.get_data()!=rotated.get_data(),"Default wheels do not rotate: "+id)
	sheet.save_png("res://.qa/default-wheels/screens/roster.png")
	closeups.save_png("res://.qa/default-wheels/screens/wheel_fit.png")
	art.queue_free(); await process_frame
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_physics_process(false)
	game.profile=DriverProfile.new(); game.refresh_car(); game.toast_left=0
	for dimensions in [Vector2i(1200,760),Vector2i(390,844)]:
		root.size=dimensions; game.go_garage(); await frame()
		root.get_texture().get_image().save_png("res://.qa/default-wheels/screens/garage_%d.png"%dimensions.x)
	game.stop_presentation_audio()
	print("SIX-SPOKE DEFAULT / 30 VEHICLES / SEPARATE RIMS / MIGRATION: ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
