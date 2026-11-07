extends "res://tests/test_qol_ui.gd"

func snap(id: String,view: String) -> void:
	await frame()
	var folder := "studio_roster" if "--roster-review" in OS.get_cmdline_user_args() else "vehicle_art"
	var path := ProjectSettings.globalize_path("res://validation/"+folder+"/"+id)
	DirAccess.make_dir_recursive_absolute(path)
	check(root.get_texture().get_image().save_png(path+"/"+view+".png")==OK,id+" / "+view+" capture")

func run_checks() -> void:
	var roster_review := "--roster-review" in OS.get_cmdline_user_args()
	root.size=Vector2i(1200,760)
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.set_process(false); game.set_physics_process(false); await frame()
	game.profile=DriverProfile.new(); game.profile.credits=10000000; game.profile.xp=100000
	for id in RosterData.IDS:
		if not game.profile.garage.has(id): game.profile.buy_vehicle(id,false)
	var rows: Array=[]
	for id in RosterData.IDS:
		game.go_garage(); game.profile.select_vehicle(id); game.refresh_car()
		var appearance: Dictionary=game.profile.appearance.duplicate(true)
		var stages: Array=game.profile.stages.duplicate()
		var hardware: Dictionary=game.profile.hardware.duplicate(true)
		var money: int=game.profile.credits
		check(VehicleAppearance.validate(id).is_empty(),id+" manifest/anchors")
		await snap(id,"garage")
		var views := ["garage","race"]
		if not roster_review or id in ["miata","supra","mustang"]:
			game.action("tab_performance"); await snap(id,"upgrades")
			game.action("hub_owned"); game.menu.hub.owned_selection=id; await snap(id,"collection")
			game.action("tab_dealer"); game.menu.dealer.enter_class(GameCatalog.engine_class(id)); game.dealer_index=RosterData.IDS.find(id); await snap(id,"dealer")
			game.go_garage(); game.action("tab_style"); await snap(id,"customize")
			# Preview only, with no economy or mechanical side effects.
			game.menu.customize.candidate.paint=4; game.menu.customize.candidate.finish=2; game.menu.customize.candidate.tint=2
			game.menu.customize.candidate.stance=1; game.menu.customize.candidate.decal=2
			await snap(id,"appearance_preview")
			views.append_array(["upgrades","collection","dealer","customize","appearance_preview"])
		game.go_garage(); game.start_practice(); await frame()
		if roster_review:
			game.input_override=Vector2(.85,0)
			for i in 475: game._physics_process(1.0/120)
			game.input_override=Vector2(-1,-1)
			check(game.car.speed>0,id+" did not launch in the race capture")
		else:
			game.car.wheel_omega=90; game.car.wheel_angle=.7; game.car.rolling_wheel_angle=.2
			game.car.speed=10
		await snap(id,"race")
		game.go_garage()
		check(game.profile.appearance==appearance and game.profile.stages==stages and game.profile.hardware==hardware and game.profile.credits==money,id+" rendering/preview changed saved build")
		check(VehicleAppearance.cached_bytes()<=VehicleAppearance.CACHE_BYTES,id+" persistent texture cache exceeds mobile budget")
		rows.append({"id":id,"views_captured":views,"render_checks":true,"artistic_approval":"REVIEW REQUIRED"})
	for id in ["miata","supra","mustang"]:
		for paint in 6:
			for finish in ["gloss","matte","metallic"]:
				var path: String=str(VehicleAppearance.definition(id).body)%[paint,finish]
				check(VehicleAppearance.texture(path)!=null,"Missing high resolution preview variant")
				check(VehicleAppearance.cached_bytes()<=VehicleAppearance.CACHE_BYTES,"Preview session exceeded texture budget")
				await frame()
	for resolution in [Vector2i(390,844),Vector2i(844,390),Vector2i(667,375)]:
		game.get_window().size=resolution
		for id in ["miata","supra","mustang"]:
			game.go_garage(); game.profile.select_vehicle(id); game.refresh_car()
			await snap(id,"garage_%dx%d"%[resolution.x,resolution.y])
			game.action("tab_style"); await snap(id,"customize_%dx%d"%[resolution.x,resolution.y])
			game.go_garage(); game.start_practice(); await snap(id,"race_%dx%d"%[resolution.x,resolution.y])
	game.stop_presentation_audio(); game.go_garage()
	var file:=FileAccess.open("res://validation/vehicle_visual_checklist.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures==0,"checks":checks,"roster":rows,"limits":"Native rendering/capture checks; screenshots still require artistic review. No physical iPhone claim."},"  "));file.close()
	print("VEHICLE PRESENTATION: ",checks," / ","PASS" if failures==0 else "FAIL")
	game.queue_free(); await process_frame; await process_frame; quit(0 if failures==0 else 1)
