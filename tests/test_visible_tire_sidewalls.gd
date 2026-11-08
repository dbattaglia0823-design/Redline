extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	# A replacement car must provide a real rubber annulus around each
	# customizable rim, not just a wheel face over a hidden back-layer tire.
	var replacements := 0
	for id in GameCatalog.CAR_IDS:
		var d: Dictionary=VehicleAppearance.definition(id)
		if int(d.get("art_pipeline_version",0)) < 2: continue
		replacements += 1
		var radii: Array=d.get("wheel_radii",[d.radius,d.radius])
		var rims: Array=d.get("rim_radius",[])
		var wheels: Array=d.get("stock_wheels",[])
		check(rims.size()==2,id+": expected two wheel rim radii")
		check(wheels.size()==2,id+": expected two authored tires")
		if rims.size()!=2 or wheels.size()!=2: continue
		for axle in 2:
			var path: String=str(wheels[axle])
			check(ResourceLoader.exists(path),id+": missing tire source "+str(axle))
			if not ResourceLoader.exists(path): continue
			var source: Texture2D=VehicleAppearance.texture(path)
			check(source!=null,id+": tire source failed to load")
			if source==null: continue
			var radius: float=float(radii[axle])
			var rim_fraction: float=float(rims[axle])/radius
			check(rim_fraction>0.0 and rim_fraction<0.86,id+": rim has no visible rubber band")
			var texture: Texture2D=RimArt.tire_only(source,rim_fraction,radius)
			var img: Image=texture.get_image()
			var center: Vector2=Vector2(img.get_size())*.5
			check(img.get_pixelv(Vector2i(center)).a<.01,id+": tire mask covers baked brake hub")
			var outer: float=minf(center.x,center.y)*radius/(radius+2.0)
			var band: float=outer*(rim_fraction+(1.0-rim_fraction)*.52)
			var visible := 0
			for step in 24:
				var direction:=Vector2.RIGHT.rotated(TAU*float(step)/24.0)
				var pos:=Vector2i((center+direction*band).round())
				if img.get_pixelv(pos).a>.20: visible+=1
			check(visible>=8,id+": insufficient authored rubber around wheel "+str(axle)+" ("+str(visible)+"/24)")
	check(VehicleAppearance.validate(id).is_empty(),id+": invalid tire geometry")
	check(replacements==30,"Expected all 30 replacement cars to have tire sidewalls")
	print("REPLACEMENT TIRE SIDEWALL ASSETS: ","PASS" if failures==0 else "FAIL"," / ",checks," checks")
	quit(0 if failures==0 else 1)
