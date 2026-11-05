class_name LiquidGlass
extends RefCounted

# One style cache for the immediate-mode screens and the native floating dock.
# The only screen read is the optional modal backdrop. Low quality uses tint only.
const PALETTE: GlassPalette = preload("res://assets/ui/liquid_glass.tres")
const THEME: Theme = preload("res://assets/ui/glass_theme.tres")
const MENU_SCENES := {
	"performance":preload("res://assets/ui/tuning_bay.svg"),
	"dealer":preload("res://assets/ui/dealer_hall.svg"),
	"style":preload("res://assets/ui/mod_studio.svg"),
	"races":preload("res://assets/ui/pit_lane.svg"),
}
static var frosted_scenes: Dictionary = {}
var legacy := false
var reduced_motion := false
var states: Dictionary = {}
var styles: Dictionary = {}
var pointer_down := false
var focused := ""
var backdrop: ImageTexture
var sheet_age := 1.0
var curve_fades: Dictionary = {}

func curve_alpha(rect: Rect2,key: String) -> float:
	var location := str(rect)
	if not curve_fades.has(location) or curve_fades[location].key != key:
		if curve_fades.size() > 16: curve_fades.clear()
		curve_fades[location] = {"key":key,"age":0.0}
	return 1.0 if reduced_motion else lerpf(.65,1.0,float(curve_fades[location].age))

func capture_backdrop(g: Node2D) -> void:
	backdrop = null
	sheet_age = 1.0 if reduced_motion else 0.0
	if legacy or g.profile.effects_quality == 0 or DisplayServer.get_name() == "headless": return
	var image := g.get_viewport().get_texture().get_image()
	if image == null or image.is_empty(): return
	# A single cached, downsampled backdrop per opening; no live per-control blur.
	var downsample := maxi(2,roundi(PALETTE.backdrop_blur*3))
	image.resize(maxi(1,image.get_width()/downsample),maxi(1,image.get_height()/downsample),Image.INTERPOLATE_LANCZOS)
	backdrop = ImageTexture.create_from_image(image)

func surface(g: CanvasItem,r: Rect2,fill: Color = PALETTE.surface,edge: Color = PALETTE.edge,radius: int = 20,shadow: bool = true) -> void:
	if fill == GlassPalette.SURFACE: fill = PALETTE.surface
	if fill == Color("151e2bf5"): fill = PALETTE.modal_surface
	if edge == GlassPalette.EDGE: edge = PALETTE.edge
	if legacy:
		g.draw_rect(r,fill); g.draw_rect(r,edge,false,1); return
	if fill==PALETTE.surface or fill==PALETTE.modal_surface:
		AutomotiveUI.glass_material("sheet" if fill==PALETTE.modal_surface else "panel").draw(g.get_canvas_item(),r)
		return
	var key := str(fill)+str(edge)+str(radius)+str(shadow)
	if not styles.has(key):
		var style := StyleBoxFlat.new()
		style.bg_color = fill; style.border_color = edge; style.set_border_width_all(1 if edge.a > 0 else 0)
		style.set_corner_radius_all(radius); style.corner_detail = 12; style.anti_aliasing = true
		if shadow:
			style.shadow_color = PALETTE.shadow; style.shadow_size = PALETTE.shadow_size; style.shadow_offset = Vector2(0,4)
		styles[key] = style
	styles[key].draw(g.get_canvas_item(),r)
	# Short diagnostic corner accents, not a costly bloom pass.
	if edge.a > .08 and r.size.x > 120:
		var accent := Color(GlassPalette.BLUE,.32)
		if edge.r > edge.b: accent = Color(PALETTE.orange,.55)
		g.draw_line(r.position+Vector2(12,0),r.position+Vector2(minf(52,r.size.x*.22),0),accent,1.5,true)
		g.draw_line(Vector2(r.end.x-12,r.end.y),Vector2(r.end.x-minf(52,r.size.x*.22),r.end.y),accent,1.5,true)
	# A narrow specular edge is cheap, stable, and never blurs text.
	if edge.a > 0 and r.size.x > radius*2:
		g.draw_line(r.position+Vector2(radius,1),Vector2(r.end.x-radius,r.position.y+1),Color(1,1,1,.065),1,true)

func button(g: Node2D,id: String,r: Rect2,primary: bool,selected: bool,enabled: bool) -> Rect2:
	var hover := r.has_point(g.get_local_mouse_position()-g.ui_offset) and enabled
	if not states.has(id): states[id] = {"hot":0.0,"pulse":0.0,"hover":false}
	states[id].hover = hover or focused == id
	var hot: float = states[id].hot
	var pulse: float = states[id].pulse
	var fill := PALETTE.surface
	var edge := PALETTE.edge
	if primary: fill = PALETTE.primary; edge = Color(PALETTE.orange,.5)
	elif selected: fill = PALETTE.selected; edge = Color(PALETTE.orange,.36)
	elif hot > .08: fill = PALETTE.raised
	if not enabled: fill = PALETTE.disabled; edge = Color("ffffff0c")
	var shown := r.grow(-pulse*pulse*2.6) if enabled and not reduced_motion else r
	if legacy:
		surface(g,shown,fill,edge,mini(PALETTE.radius,roundi(r.size.y*.42)),r.size.y > 36)
	else:
		var material:="disabled" if not enabled else ("warm" if primary else ("selected" if selected else ("hover" if hot>.08 else "clear")))
		AutomotiveUI.glass_material(material).draw(g.get_canvas_item(),shown)
	if enabled and pulse > .01 and not reduced_motion and not legacy:
		AutomotiveUI.glow(g,Rect2(shown.position,Vector2(shown.size.x,shown.size.y*.65)),Color(PALETTE.ink,pulse*.14))
	if hot > .01 and enabled and shown.size.x > 36:
		g.draw_line(shown.position+Vector2(18,1),Vector2(shown.end.x-18,shown.position.y+1),Color(1,1,1,hot*.17),1,true)
	return shown

func press(id: String) -> void:
	if states.has(id): states[id].pulse = 1.0

func animate(dt: float,buttons: Array) -> bool:
	var active: Dictionary = {}; var changed := false
	if sheet_age < 1:
		sheet_age = 1.0 if reduced_motion else minf(1,sheet_age+dt/PALETTE.motion_seconds); changed = true
	for fade in curve_fades.values():
		if fade.age < 1:
			fade.age = 1.0 if reduced_motion else minf(1,float(fade.age)+dt/PALETTE.motion_seconds); changed = true
	for item in buttons: active[item.id] = true
	for id in states.keys():
		if not active.has(id): states.erase(id); continue
		var state: Dictionary = states[id]
		var hot := 1.0 if state.hover else 0.0
		var next := hot if reduced_motion else move_toward(float(state.hot),hot,dt/PALETTE.motion_seconds)
		var pulse := 0.0 if reduced_motion else maxf(0,float(state.pulse)-dt/.16)
		changed = changed or absf(next-float(state.hot)) > .001 or pulse != float(state.pulse)
		state.hot = next; state.pulse = pulse
	return changed

func background(g: Node2D,size: Vector2) -> void:
	g.draw_rect(Rect2(Vector2.ZERO,size),PALETTE.background)
	if not legacy and g.screen!="race":
		var section: String=g.tab if g.screen=="garage" else "races"
		var sheet: bool=g.menu.hub.dyno_open or (section=="performance" and not g.menu.hub.categories)
		var tex:=menu_scene(g,section,true,sheet)
		if tex!=null:
			draw_cover(g,tex,Rect2(Vector2.ZERO,size))
			var tint:=Color(.025,.034,.049,.34 if section in ["garage","owned"] else .41)
			if section=="driver": tint.a=.63
			g.draw_rect(Rect2(Vector2.ZERO,size),tint)
			var top_shade:=Color(.025,.032,.047,.54)
			g.draw_polygon(PackedVector2Array([Vector2.ZERO,Vector2(size.x,0),Vector2(size.x,size.y*.24),Vector2(0,size.y*.24)]),PackedColorArray([top_shade,top_shade,Color.TRANSPARENT,Color.TRANSPARENT]))
			if g.profile.effects_quality > 0:
				AutomotiveUI.glow(g,Rect2(size*Vector2(.24,-.36),size*Vector2(1.2,1.0)),Color(.27,.52,.78,.15))
				AutomotiveUI.glow(g,Rect2(size*Vector2(-.42,.48),size*Vector2(1.15,.92)),Color(.04,.08,.14,.58))
			return
	for i in 9:
		var x := size.x*float(i)/8
		g.draw_line(Vector2(x,0),Vector2(x-size.x*.12,size.y),Color(GlassPalette.BLUE,.025),1,true)
	g.draw_line(Vector2(28,68),Vector2(size.x-28,68),Color(GlassPalette.BLUE,.24),1,true)
	# Cached, low-opacity broad lighting: no per-panel screen copies or particles.
	for i in 5:
		var k := 5-i
		_halo(g,size,k)

static func menu_scene(g: Node2D,section: String,soft: bool=false,sheet: bool=false) -> Texture2D:
	var source: Texture2D=MENU_SCENES.get(section,g.showroom_texture)
	if source==null or not soft: return source
	# Frost the static scene once, rather than sample the screen behind every card.
	var key:=source.resource_path+str(sheet)
	if not frosted_scenes.has(key):
		var scene:=source.get_image()
		if scene==null or scene.is_empty(): return source
		var width:=96 if sheet else 220
		scene.resize(width,roundi(width*float(scene.get_height())/scene.get_width()),Image.INTERPOLATE_LANCZOS)
		frosted_scenes[key]=ImageTexture.create_from_image(scene)
	return frosted_scenes[key]

static func draw_cover(canvas: CanvasItem,texture: Texture2D,bounds: Rect2,tint: Color=Color.WHITE) -> void:
	var pixels:=texture.get_size()
	var factor:=maxf(bounds.size.x/pixels.x,bounds.size.y/pixels.y)
	var region:=bounds.size/factor
	canvas.draw_texture_rect_region(texture,bounds,Rect2((pixels-region)*.5,region),tint)

func _halo(g: Node2D,size: Vector2,k: int) -> void:
	g.draw_circle(Vector2(size.x*.87,-size.y*.12),float(k)*size.x*.22,Color(.30,.40,.51,.008),true,-1,true)

func modal(g: Node2D,r: Rect2,quality: int) -> void:
	if not legacy and quality > 0 and backdrop != null: g.draw_texture_rect(backdrop,r,false,Color(.72,.76,.83))
	g.draw_rect(r,Color(.018,.027,.044,.64 if backdrop != null and quality > 0 else .82))

func icon(g: CanvasItem,key: String,p: Vector2,s: float,color: Color) -> void:
	if color == GlassPalette.ORANGE: color = PALETTE.orange
	if color == GlassPalette.MUTED: color = PALETTE.muted
	var w := 1.7; var c := p+Vector2(s,s)*.5; var radius := s*.35
	match key:
		"garage":
			g.draw_polyline(PackedVector2Array([p+Vector2(1,s*.43),p+Vector2(s*.5,1),p+Vector2(s-1,s*.43),p+Vector2(s-1,s-1),p+Vector2(1,s-1),p+Vector2(1,s*.43)]),color,w,true)
			g.draw_line(p+Vector2(s*.3,s*.6),p+Vector2(s*.7,s*.6),color,w,true)
		"performance", "engine":
			g.draw_arc(c,radius,.35,PI*1.8,20,color,w,true); g.draw_line(c,c+Vector2(.55,-.65)*radius,color,w,true)
		"Engine internals":
			g.draw_rect(Rect2(p+Vector2(s*.17,s*.1),Vector2(s*.66,s*.30)),color,false,w)
			g.draw_line(p+Vector2(s*.17,s*.23),p+Vector2(s*.83,s*.23),color,w,true)
			g.draw_line(p+Vector2(s*.42,s*.43),p+Vector2(s*.54,s*.71),color,w,true)
			g.draw_line(p+Vector2(s*.62,s*.43),p+Vector2(s*.71,s*.71),color,w,true)
			g.draw_circle(p+Vector2(s*.63,s*.81),s*.12,color,false,w,true)
		"style":
			g.draw_polyline(PackedVector2Array([p+Vector2(s*.43,s*.51),p+Vector2(s*.81,s*.08),p+Vector2(s*.94,s*.21),p+Vector2(s*.58,s*.64)]),color,w,true)
			g.draw_polyline(PackedVector2Array([p+Vector2(s*.42,s*.5),p+Vector2(s*.61,s*.69),p+Vector2(s*.36,s*.91),p+Vector2(s*.08,s*.94),p+Vector2(s*.14,s*.68),p+Vector2(s*.42,s*.5)]),color,w,true)
		"dealer":
			g.draw_polyline(PackedVector2Array([p+Vector2(1,s*.65),p+Vector2(s*.2,s*.65),p+Vector2(s*.3,s*.3),p+Vector2(s*.7,s*.3),p+Vector2(s*.8,s*.65),p+Vector2(s-1,s*.65),p+Vector2(s-1,s*.85),p+Vector2(1,s*.85),p+Vector2(1,s*.65)]),color,w,true)
		"races":
			g.draw_line(p+Vector2(s*.2,s),p+Vector2(s*.2,0),color,w,true)
			g.draw_polyline(PackedVector2Array([p+Vector2(s*.2,1),p+Vector2(s*.9,s*.2),p+Vector2(s*.65,s*.55),p+Vector2(s*.2,s*.4)]),color,w,true)
		"driver":
			g.draw_circle(c+Vector2(0,-s*.2),s*.18,color,false,w,true); g.draw_arc(c+Vector2(0,s*.38),s*.36,PI,TAU,16,color,w,true)
		"Intake":
			g.draw_polyline(PackedVector2Array([p+Vector2(s*.1,s*.2),p+Vector2(s*.9,s*.2),p+Vector2(s*.6,s*.6),p+Vector2(s*.6,s*.9),p+Vector2(s*.4,s*.9),p+Vector2(s*.4,s*.6),p+Vector2(s*.1,s*.2)]),color,w,true)
		"Exhaust":
			g.draw_polyline(PackedVector2Array([p+Vector2(1,s*.25),p+Vector2(s*.6,s*.25),p+Vector2(s*.6,s*.7),p+Vector2(s,s*.7)]),color,w,true)
			g.draw_line(p+Vector2(1,s*.45),p+Vector2(s*.38,s*.45),color,w,true)
			g.draw_arc(p+Vector2(s*.9,s*.7),s*.16,-PI*.5,PI*.5,10,color,w,true)
		"Fuel system", "Nitrous":
			g.draw_polyline(PackedVector2Array([p+Vector2(s*.35,s*.1),p+Vector2(s*.65,s*.1),p+Vector2(s*.65,s*.23),p+Vector2(s*.8,s*.38),p+Vector2(s*.8,s*.9),p+Vector2(s*.2,s*.9),p+Vector2(s*.2,s*.38),p+Vector2(s*.35,s*.23),p+Vector2(s*.35,s*.1)]),color,w,true)
			g.draw_line(p+Vector2(s*.36,s*.52),p+Vector2(s*.64,s*.52),color,w,true)
		"ECU / electronics":
			g.draw_rect(Rect2(p+Vector2(s*.25,s*.25),Vector2(s*.5,s*.5)),color,false,w)
			for i in 3:
				var at := s*(.32+i*.18)
				g.draw_line(p+Vector2(at,0),p+Vector2(at,s*.2),color,w,true); g.draw_line(p+Vector2(at,s*.8),p+Vector2(at,s),color,w,true)
				g.draw_line(p+Vector2(0,at),p+Vector2(s*.2,at),color,w,true); g.draw_line(p+Vector2(s*.8,at),p+Vector2(s,at),color,w,true)
		"Forced induction":
			g.draw_arc(c,radius,.15,TAU-.2,24,color,w,true); g.draw_arc(c,radius*.45,.5,PI*1.8,14,color,w,true)
			g.draw_polyline(PackedVector2Array([c+Vector2(radius,0),p+Vector2(s*.95,s*.17),p+Vector2(s*.7,s*.17)]),color,w,true)
		"Differential / gearing":
			g.draw_circle(c,s*.22,color,false,w,true)
			for sign in [-1,1]:
				g.draw_line(c+Vector2(sign*s*.23,0),c+Vector2(sign*s*.46,0),color,w,true)
				g.draw_line(c+Vector2(sign*s*.46,-s*.2),c+Vector2(sign*s*.46,s*.2),color,w,true)
			g.draw_line(c+Vector2(0,s*.23),c+Vector2(0,s*.48),color,w,true)
		"Suspension":
			var points := PackedVector2Array([p+Vector2(s*.5,0),p+Vector2(s*.5,s*.15)])
			for i in 6: points.append(p+Vector2(s*(.25 if i%2 == 0 else .75),s*(.22+i*.11)))
			points.append(p+Vector2(s*.5,s*.9)); points.append(p+Vector2(s*.5,s)); g.draw_polyline(points,color,w,true)
		"Cooling":
			g.draw_rect(Rect2(p+Vector2(s*.1,s*.2),Vector2(s*.8,s*.6)),color,false,w)
			for i in 4: g.draw_line(p+Vector2(s*(.25+i*.17),s*.3),p+Vector2(s*(.25+i*.17),s*.7),color,w,true)
		"Weight reduction":
			g.draw_circle(p+Vector2(s*.5,s*.22),s*.15,color,false,w,true)
			g.draw_polyline(PackedVector2Array([p+Vector2(s*.25,s*.4),p+Vector2(s*.75,s*.4),p+Vector2(s*.9,s*.9),p+Vector2(s*.1,s*.9),p+Vector2(s*.25,s*.4)]),color,w,true)
		"Brakes":
			g.draw_arc(c,radius,.7,TAU-.7,20,color,w,true); g.draw_circle(c,s*.09,color,true,-1,true)
			g.draw_line(p+Vector2(s*.8,s*.23),p+Vector2(s*.8,s*.76),color,w*2,true)
		"Transmission", "Clutch / converter", "Tires / wheels":
			g.draw_circle(c,radius,color,false,w,true); g.draw_circle(c,radius*.35,color,false,w,true)
			for i in 5:
				var angle := TAU*i/5; var direction := Vector2(cos(angle),sin(angle))
				g.draw_line(c+direction*radius*.4,c+direction*radius*.9,color,w,true)
		_:
			g.draw_arc(c,radius,0,TAU,20,color,w,true)
			var n := posmod(int(key.hash()),4)
			for i in n+2:
				var angle := TAU*i/(n+2); g.draw_line(c,c+Vector2(cos(angle),sin(angle))*radius,color,w,true)
