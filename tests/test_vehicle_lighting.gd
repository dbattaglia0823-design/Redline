extends SceneTree

var failures := 0
var checks := 0

class Fixture extends Node2D:
	var model: String
	var car: Drivetrain
	var look: Dictionary
	var baseline := false
	var quality := 2

	func _draw() -> void:
		VehicleRenderer.draw(self,Vector2.ZERO,1000.0/232.0,model,look,car,false,Vector2.ZERO,0,false,quality,false,false,null,1.0,true)
		if baseline: material=null

func _initialize() -> void: call_deferred("run")

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func capture(art: Fixture) -> Image:
	art.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func run() -> void:
	root.size=Vector2i(1000,360)
	root.content_scale_size=Vector2i(1000,360)
	root.transparent_bg=true
	DirAccess.make_dir_recursive_absolute("res://.qa/vehicle-lighting/roster")
	var sheets: Array[Image]=[]
	for finish in 3:
		var sheet:=Image.create(1500,816,false,Image.FORMAT_RGBA8)
		sheet.fill(Color("20272c"))
		sheets.append(sheet)
	var art:=Fixture.new()
	root.add_child(art)
	var report: Array=[]
	for index in GameCatalog.CAR_IDS.size():
		var id: String=GameCatalog.CAR_IDS[index]
		art.model=id
		art.car=Drivetrain.new()
		art.car.configure_vehicle(GameCatalog.spec(id))
		art.car.configure(GameCatalog.blank_stages())
		art.car.configure_build(GameCatalog.factory_build(id),id,false)
		var signatures: Array=[]
		var model_alpha:=true
		for finish in 3:
			art.look=VehicleAppearance.normalize({"paint":index%6,"finish":finish,"design":(index+finish)%5,"rim":index%3,"caliper":index%4,"tint":finish})
			art.baseline=true
			var before:=await capture(art)
			art.baseline=false
			var after:=await capture(art)
			var original:=before.get_data()
			var lit:=after.get_data()
			var same_alpha:=true
			var difference:=0
			for pixel in range(0,lit.size(),64):
				if abs(int(lit[pixel+3])-int(original[pixel+3]))>1: same_alpha=false
				if lit[pixel+3]>240:
					difference+=absi(int(lit[pixel])-int(original[pixel]))+absi(int(lit[pixel+1])-int(original[pixel+1]))+absi(int(lit[pixel+2])-int(original[pixel+2]))
			check(same_alpha,id+" lighting altered the artwork silhouette")
			model_alpha=model_alpha and same_alpha
			check(difference>0,id+" showroom shader did not affect the vehicle")
			signatures.append(lit.hex_encode().sha256_text())
			after.resize(300,108,Image.INTERPOLATE_LANCZOS)
			sheets[finish].blend_rect(after,Rect2i(0,0,300,108),Vector2i((index%5)*300,(index/5)*136))
		check(signatures[0]!=signatures[1] and signatures[1]!=signatures[2],id+" finish/customization variants render identically")
		report.append({"model":id,"paint":index%6,"finishes":3,"silhouette_preserved":model_alpha})
	for finish in 3: sheets[finish].save_png("res://.qa/vehicle-lighting/roster/finish_%d.png"%finish)
	for quality in [0,1,2]:
		art.quality=quality
		var result:=await capture(art)
		check(not result.is_empty(),"Missing lighting quality "+str(quality))
	var file:=FileAccess.open("res://.qa/vehicle-lighting/roster/results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures==0,"checks":checks,"vehicles":report},"  "))
	print("SHOWROOM LIGHTING / 30 VEHICLES / FINISHES / RIMS / TINT / ALPHA: ",checks," / ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
