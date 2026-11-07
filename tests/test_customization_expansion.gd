extends "res://tests/test_customization_ui.gd"

func choose(index: int,touch: bool) -> void:
	var id:="custom_pick_"+str(index)
	var target: Control=game.native_workshop.targets[id]
	var ancestor:=target.get_parent()
	while ancestor!=game.native_workshop and ancestor!=null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(target)
		ancestor=ancestor.get_parent()
	await frame()
	await click(id,touch)
	game.toast_left=0
	await frame()

func run() -> void:
	check(VehicleAppearance.OPTIONS.design.size()==12,"Missing expanded rim designs")
	check(VehicleAppearance.OPTIONS.rim.size()==9,"Missing wheel finishes")
	check(VehicleAppearance.OPTIONS.tint.size()==5,"Missing darker tint")
	check(not VehicleAppearance.OPTIONS.has("sidewall") and not VehicleAppearance.OPTIONS.has("decal"),"Retired cosmetic categories remain")
	var p:=DriverProfile.new()
	p.credits=1000000
	p.xp=100000
	p.appearance.sidewall=2
	p.appearance.decal=2
	p.owned_appearance.append_array(["sidewall:2","decal:2"])
	p.save()
	var loaded:=DriverProfile.new()
	loaded.load_profile()
	check(not loaded.appearance.has("sidewall") and not loaded.appearance.has("decal"),"Old cosmetics were not removed during save migration")
	var credits:=loaded.credits
	loaded.install_appearance("sidewall",1)
	loaded.install_appearance("decal",1)
	check(loaded.credits==credits,"A retired cosmetic can still be purchased")
	for pair in [["design",11],["rim",8],["tint",4]]:
		check(loaded.install_appearance(pair[0],pair[1]).begins_with("Installed"),"New cosmetic cannot be installed")
	var paid:=loaded.credits
	loaded.install_appearance("rim",0)
	loaded.install_appearance("rim",8)
	check(loaded.credits==paid,"Owned finish charged again")
	p.load_profile()
	check(p.appearance.design==11 and p.appearance.rim==8 and p.wheels==8 and p.appearance.tint==4,"New option IDs were lost on save/load")
	check(p.buy_vehicle("gtr"),"Cannot prepare closed-roof tint preview")
	check(p.appearance.design==0 and p.appearance.rim==0,"A new car inherited another car's cosmetics")
	check(p.select_vehicle("miata") and p.appearance.rim==8,"Vehicle switching lost the new rim finish")
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.profile=p
	game.profile.reduced_motion=true
	game.refresh_car()
	DirAccess.make_dir_recursive_absolute("res://.qa/customization-expansion/screens")
	for dimensions in [Vector2i(1200,760),Vector2i(390,844),Vector2i(844,390)]:
		root.size=dimensions
		game.go_garage()
		await frame()
		game.action("tab_style")
		await frame()
		await click("custom_group_wheels",dimensions.x<1000)
		check(not game.native_workshop.targets.has("custom_category_sidewall"),"Sidewall control remains")
		await choose(9,dimensions.x<1000)
		check(stage().look.design==9,"New rim card did not preview")
		await click("custom_category_rim",dimensions.x<1000)
		await choose(3,dimensions.x<1000)
		await frame()
		root.get_texture().get_image().save_png("res://.qa/customization-expansion/screens/chrome_%d.png"%dimensions.x)
		await choose(4,dimensions.x<1000)
		root.get_texture().get_image().save_png("res://.qa/customization-expansion/screens/satin_%d.png"%dimensions.x)
		await choose(3,dimensions.x<1000)
		await click("custom_install",dimensions.x<1000)
		await choose(8,dimensions.x<1000)
		await click("custom_install",dimensions.x<1000)
		check(game.profile.appearance.rim==8,"New wheel finish did not equip")
		await click("custom_group_paint",dimensions.x<1000)
		await click("custom_trim",dimensions.x<1000)
		check(not game.native_workshop.targets.has("custom_category_decal"),"Livery control remains")
	game.go_garage()
	game.profile.select_vehicle("gtr")
	game.refresh_car()
	game.action("tab_style")
	await frame()
	game.menu.customize.action("custom_group_tint")
	game.menu.customize.action("custom_pick_4")
	game.toast_left=0
	root.size=Vector2i(390,844)
	await frame()
	check(stage().look.tint==4,"Dark tint did not preview")
	root.get_texture().get_image().save_png("res://.qa/customization-expansion/screens/privacy_tint.png")
	game.stop_presentation_audio()
	print("EXPANDED CUSTOMIZATION / RETIRED OPTIONS / SAVE MIGRATION / PURCHASE / UI: ",checks," / ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
