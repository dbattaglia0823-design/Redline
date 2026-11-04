class_name TrackPresentation
extends RefCounted

const TRACKS := [
	{"name":"DOCKSIDE DRAGWAY","night":false,"accent":"db8652"},
	{"name":"MIDNIGHT MOTORPLEX","night":true,"accent":"64a7ba"},
	{"name":"CITY FINALS / REDLINE PARK","night":true,"accent":"b58acb"}]

static func spec(index: int) -> Dictionary: return TRACKS[clampi(index,0,2)]
static func tile(g: Node2D,path: String,area: Rect2,width: float,scroll: float,color: Color = Color.WHITE) -> void:
	var texture := VehicleAppearance.texture("res://assets/strip/"+path+".svg")
	if texture == null: return
	var offset := fposmod(scroll,width)
	for i in range(-1,ceili(area.size.x/width)+1): g.draw_texture_rect(texture,Rect2(area.position+Vector2(i*width-offset,0),Vector2(width,area.size.y)),false,color)

static func draw(g: Node2D) -> void:
	var portrait: bool = g.is_portrait()
	var width := 600.0 if portrait else 1200.0
	var top := 140.0 if portrait else 83.0
	var road := 300.0 if portrait else 347.0
	var bottom := 490.0 if portrait else 549.0
	var ppm := 6.0 if portrait else 12.0
	var scroll: float = g.feedback.visual_distance*ppm
	var night: bool = spec(g.event_index).night
	var accent := Color(str(spec(g.event_index).accent))
	var sky := VehicleAppearance.texture("res://assets/strip/sky_"+("night" if night else "day")+".svg")
	if sky: g.draw_texture_rect(sky,Rect2(0,top,width,road-top),false)
	# Horizon and distant industrial silhouettes sit behind the grandstands.
	for i in (8 if g.profile.effects_quality == 0 else 15):
		var x := fposmod(i*112-scroll*.055,width+150)-100
		var h: float = 14+(i*17)%41
		g.draw_rect(Rect2(x,road-60-h,81,h+15),Color("1b2b3c") if night else Color("70818a"))
	tile(g,"stands",Rect2(0,road-131,width,104),624,scroll*.24,Color(.4,.5,.65) if night else Color(.83,.86,.87))
	# Finite floodlight fixtures, simple translucent cones rather than real-time lights.
	for i in range(-1,ceili(width/360)+1):
		var x := i*360-fposmod(scroll*.3,360)
		g.draw_line(Vector2(x,road-20),Vector2(x,road-193),Color("263b4c"),4)
		g.draw_line(Vector2(x-19,road-194),Vector2(x+19,road-194),Color("162634"),9)
		g.draw_line(Vector2(x-16,road-195),Vector2(x+16,road-195),Color("dfeaf1") if night else Color("a8b7bc"),3)
		if night and g.profile.effects_quality > 0:
			g.draw_colored_polygon(PackedVector2Array([Vector2(x-17,road-190),Vector2(x-85,bottom),Vector2(x+90,bottom),Vector2(x+17,road-190)]),Color(.65,.80,1,.035))
	tile(g,"barrier",Rect2(0,road-25,width,25),384,scroll*.6,Color(.55,.65,.76) if night else Color.WHITE)
	tile(g,"asphalt",Rect2(0,road,width,bottom-road),384,scroll,Color(.64,.71,.81) if night else Color(.91,.92,.91))
	var middle := road+(bottom-road)*.5
	for y in [road+2,middle,bottom-3]: g.draw_line(Vector2(0,y),Vector2(width,y),Color("bac1b9") if not night else Color("7e919d"),2)
	# Rubber tracks and repaired seams are world-anchored, not arbitrary animated streaks.
	for lane in 2:
		for i in (6 if g.profile.effects_quality == 0 else 16):
			var x := fposmod(i*137-scroll,width+240)-180
			var y := road+30+lane*(bottom-road)*.5+(i*7)%29
			g.draw_line(Vector2(x,y),Vector2(x+95+(i*11)%80,y+2),Color(0.025,.035,.05,.18),2+i%3,true)
		if g.profile.effects_quality == 2 and g.car.speed > 35:
			for i in 8:
				var x := fposmod(i*191-scroll,width+150)-100
				g.draw_line(Vector2(x,road+25+lane*90+i%30),Vector2(x+clampf(g.car.speed*.45,12,42),road+25+lane*90+i%30),Color(.7,.76,.8,.045),1)
	var origin: Vector2 = g.race_origins()[0]
	var start_x: float = origin.x+382.8-g.car.distance*ppm
	var finish_x: float = origin.x+382.8+(g.active_distance-g.car.distance)*ppm
	if start_x > -1400 and start_x < width+100:
		g.draw_rect(Rect2(start_x-95,road+4,95,bottom-road-8),Color(0,0,0,.15))
		g.draw_rect(Rect2(start_x,road,4,bottom-road),Color("e4e5d5"))
		g.draw_rect(Rect2(start_x-18,road,2,bottom-road),accent)
		tree(g,Vector2(start_x+(44 if portrait else 64),road-158),.79 if portrait else 1.0)
	if finish_x > -380 and finish_x < width+250:
		for row in 14:
			for col in 2: g.draw_rect(Rect2(finish_x+col*10,road+row*(bottom-road)/14,10,(bottom-road)/14),Color("f0eee0") if (row+col)%2==0 else Color("111c27"))
		g.draw_line(Vector2(finish_x,road-80),Vector2(finish_x,road),accent,3)
		g.text_at("FINISH",finish_x+8,road-60,15,accent)
		board(g,Vector2(clampf(finish_x+35,16,width-240),road-173),night)
	g.draw_rect(Rect2(0,bottom-2,width,3),accent)

static func tree(g: Node2D,p: Vector2,s: float) -> void:
	g.draw_rect(Rect2(p+Vector2(29,4)*s,Vector2(6,175)*s),Color("222e37"))
	g.draw_rect(Rect2(p,Vector2(64,151)*s),Color("111a22"))
	for lane in 2:
		var x := p.x+(18+lane*28)*s
		for j in 2:
			var lit: bool = g.staging.beam(lane,j==0)
			g.draw_circle(Vector2(x,p.y+(12+j*14)*s),4*s,Color("e4ecdf") if lit else Color("34434b"))
		for lamp in 5:
			var active: bool = lamp == RaceStaging.lamp(g.countdown) if lamp < 4 else lane == 0 and g.staging.red_light
			if lane == 0 and g.staging.red_light and lamp < 4: active = false
			var c: Color = Color("f2ae43") if lamp<3 else (Color("7ce5a5") if lamp==3 else Color("fa5145"))
			var center := Vector2(x,p.y+(48+lamp*22)*s)
			if active and g.profile.effects_quality > 0: g.draw_circle(center,10*s,Color(c,.1))
			g.draw_circle(center,7*s,c if active else Color("273039"))
	g.text_at("STAGE",p.x,p.y-8,11,Color("d8e2de"))
	g.text_at("P",p.x+2*s,p.y+15*s,8,Color("d8e2de"))
	g.text_at("S",p.x+2*s,p.y+29*s,8,Color("d8e2de"))

static func board(g: Node2D,p: Vector2,night: bool) -> void:
	g.draw_rect(Rect2(p,Vector2(224,110)),Color("101e2a"))
	g.draw_rect(Rect2(p,Vector2(224,110)),Color("677a86"),false,2)
	g.text_at("REDLINE / TIMING",p.x+10,p.y+19,13,Color("a3b4b9"))
	for lane in 2:
		var total: float = g.player_finish if lane == 0 else g.rival_finish
		var label := "--.---" if total <= 0 else "%.3f" % g.staging.elapsed(total,lane)
		if lane == 0 and g.staging.red_light: label = "RED"
		g.text_at(("YOU   " if lane==0 else "RIVAL ")+label,p.x+10,p.y+51+lane*32,22,Color("a8e5b0") if night else Color("d7e3b2"))
