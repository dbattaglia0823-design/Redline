class_name TrackPresentation
extends RefCounted

const TRACKS := [
	{"name":"DOCKSIDE DRAGWAY","art":"dockside","night":false,"accent":"db8652"},
	{"name":"MIDNIGHT MOTORPLEX","art":"midnight","night":true,"accent":"64a7ba"},
	{"name":"REDLINE PARK","art":"redline","night":false,"accent":"d95149"}]

static func spec(index: int) -> Dictionary: return TRACKS[clampi(index,0,2)]
# Location artwork has its own bounded cache; it must not evict vehicle layers.
static var _location := ""
static var _art: Texture2D
static var _surfaces: Dictionary = {}

static func surface(path: String) -> Texture2D:
	if not _surfaces.has(path): _surfaces[path] = load("res://assets/strip/"+path+".svg")
	return _surfaces[path]

static func tile(g: Node2D,path: String,area: Rect2,width: float,scroll: float,color: Color = Color.WHITE) -> void:
	var texture := surface(path)
	var offset := fposmod(scroll,width)
	for i in range(-1,ceili(area.size.x/width)+1):
		g.draw_texture_rect(texture,Rect2(area.position+Vector2(i*width-offset,0),Vector2(width,area.size.y)),false,color)

# Mirroring at the panorama edge avoids hard repeat seams. Keep architecture
# and sky intact so floodlights cannot split or float as the camera moves.
# The facility, near wall, track and apron each have a separate depth rate.
static func panorama(g: Node2D,key: String,area: Rect2,scroll: float,portrait: bool) -> void:
	if _location != key or _art == null:
		_art = load("res://assets/strip/"+key+"_panorama.png")
		_location = key
	if _art == null: return
	var source := Rect2(0,0,_art.get_width(),_art.get_height())
	var w := maxf(740 if portrait else 1120,source.size.x*area.size.y/source.size.y)
	var travel := scroll*.23
	var first := floori(travel/w)
	for i in range(-1,ceili(area.size.x/w)+1):
		var x := i*w-fposmod(travel,w)
		if (first+i)%2 != 0:
			g.draw_set_transform(g.feedback.camera_offset+Vector2(x+w,area.position.y),0,Vector2(-1,1))
			g.draw_texture_rect_region(_art,Rect2(0,0,w,area.size.y),source)
			g.draw_set_transform(g.feedback.camera_offset)
		else:
			g.draw_texture_rect_region(_art,Rect2(x,area.position.y,w,area.size.y),source)

static func glow(g: Node2D,rect: Rect2,color: Color) -> void:
	g.draw_texture_rect(surface("soft_glow"),rect,false,color)

static func draw(g: Node2D) -> void:
	var portrait: bool = g.is_portrait()
	var width: float = g.race_view_size().x
	var top := 116.0 if portrait else (120.0 if g.race_touch_layout() else 64.0)
	var road := 300.0 if portrait else 347.0
	var bottom := 580.0 if portrait else (546.0 if g.race_touch_layout() else 580.0)
	var ppm := 6.0 if portrait else 12.0
	var scroll: float = g.feedback.visual_distance*ppm
	var location := spec(g.race_track_index())
	var night: bool = location.night
	var accent := Color(str(location.accent))
	panorama(g,str(location.art),Rect2(0,top,width,road-top),scroll,portrait)
	# Near safety wall, rubbered racing surface and drainage apron move faster
	# than buildings. Everything derives from distance, so paused views stay still.
	tile(g,str(location.art)+"_wall",Rect2(0,road-20,width,20),480,scroll*.65)
	tile(g,"race_surface",Rect2(0,road,width,bottom-road),1024,scroll,Color(.58,.67,.78) if night else Color(.91,.91,.87))
	var middle := road+(bottom-road)*.5
	# Paint is deliberately sparse in the racing lanes; the two tire grooves
	# remain visible at speed rather than turning the strip into a highway.
	if g.profile.effects_quality > 0:
		for i in range(-1,ceili(width/500)+1):
			var x := i*500-fposmod(scroll*.65,500)
			glow(g,Rect2(x-90,road-10,250,bottom-road+20),Color(.48,.72,1,.12) if night else Color(1,.76,.48,.055))
			if night:
				glow(g,Rect2(x-20,road+14,115,12),Color(.55,.8,1,.16))
	# Close apron and drainage cover provide another depth cue without hiding cars.
	g.draw_rect(Rect2(0,bottom-17,width,17),Color("172028") if night else Color("414343"))
	for i in range(-1,ceili(width/192)+1):
		var x := i*192-fposmod(scroll*1.08,192)
		g.draw_line(Vector2(x,bottom-15),Vector2(x+130,bottom-15),Color("788080"),1)
		if g.profile.effects_quality > 0:
			for slot in 5: g.draw_line(Vector2(x+slot*7,bottom-11),Vector2(x+slot*7-3,bottom-4),Color("10171b"),3)
	if g.profile.effects_quality == 2 and g.car.speed > 35 and not g.profile.reduced_motion:
		for i in 10:
			var x := fposmod(i*191-scroll*1.08,width+180)-120
			var y := bottom-24-float(i%3)*5
			g.draw_line(Vector2(x,y),Vector2(x+minf(g.car.speed*.5,48),y),Color(.8,.85,.88,.065),1,true)
	var origin: Vector2 = g.race_origins()[0]
	var start_x: float = origin.x+382.8-g.car.distance*ppm
	var finish_x: float = origin.x+382.8+(g.active_distance-g.car.distance)*ppm
	if start_x > -1400 and start_x < width+100:
		g.draw_rect(Rect2(start_x-95,road+4,95,bottom-road-21),Color(0,0,0,.22))
		for lane in 2:
			var y: float = road+30+lane*(bottom-road)*.5
			g.draw_line(Vector2(start_x-110,y),Vector2(start_x-12,y),Color("b9b8a6"),3)
			g.text_at("0"+str(lane+1),start_x-80,y+27,18,Color("a5aaa4"))
		g.text_at(str(location.name),maxf(12,start_x-330),road-25,15,accent,true)
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
	g.draw_rect(Rect2(p-Vector2(3,3)*s,Vector2(70,157)*s),Color("617079"))
	g.draw_rect(Rect2(p,Vector2(64,151)*s),Color("111a22"))
	g.draw_line(p+Vector2(32,0)*s,p+Vector2(32,151)*s,Color("34444e"),s)
	g.draw_line(p+Vector2(7,154)*s,p+Vector2(58,154)*s,Color("283842"),5*s)
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
			g.draw_circle(center+Vector2(0,1)*s,9*s,Color("070d12"))
			if active and g.profile.effects_quality > 0: glow(g,Rect2(center-Vector2.ONE*23*s,Vector2.ONE*46*s),Color(c,.7))
			g.draw_circle(center,7*s,c if active else Color("273039"))
			g.draw_arc(center,7.5*s,PI,TAU,12,Color("52616b"),s,true)
			if active: g.draw_circle(center-Vector2(1.5,2)*s,2*s,Color(1,1,.9,.75))
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
