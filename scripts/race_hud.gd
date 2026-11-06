class_name RaceHUD
extends RefCounted

# Read-only dashboard: all hit targets route through the existing race input path.
const BLUE := GlassPalette.BLUE
const DIM := GlassPalette.MUTED
const WHITE := GlassPalette.INK
const ORANGE := GlassPalette.ORANGE
const GREEN := GlassPalette.GREEN
const RED := Color("ff6d69")
const CLUTCH_AMBER := Color("ffca79")
const GEARBOX_VIOLET := Color("efa0ed")
const SPLITS := {402.336:"1/4 MI",304.8:"1000 FT",201.168:"1/8 MI",100.0:"100 M",18.288:"60 FT"}
const CONTROL_ART := {
	"gas":preload("res://assets/ui/race_controls/throttle.svg"),
	"brake":preload("res://assets/ui/race_controls/brake.svg"),
	"clutch":preload("res://assets/ui/race_controls/clutch.svg"),
	"down":preload("res://assets/ui/race_controls/down.svg"),
	"up":preload("res://assets/ui/race_controls/up.svg"),
}
const BOTTLE := preload("res://assets/ui/race_controls/bottle.svg")
const CHARGE := preload("res://assets/ui/race_controls/charge.svg")
var g: Node2D
var styles: Dictionary = {}
var readings: Dictionary = {}
var status: PanelContainer
var event_text: Label
var distance_text: Label
var elapsed_text: Label
var gap_text: Label
var progress: ProgressBar
var status_layout := -1

func _init(game: Node2D) -> void:
	g = game
	status = PanelContainer.new()
	status.hide()
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.theme = AutomotiveUI.theme_resource()
	var skin := AutomotiveUI.surface(Color("07131ef2"),Color("284652"),13)
	skin.content_margin_top = 4
	skin.content_margin_bottom = 4
	status.add_theme_stylebox_override("panel",skin)
	g.add_child(status)
	var row := AutomotiveUI.row(status,12)
	var event := AutomotiveUI.column(row,0)
	event_text = AutomotiveUI.label("",19,BLUE)
	distance_text = AutomotiveUI.label("",15,DIM,true)
	event.add_child(event_text)
	event.add_child(distance_text)
	elapsed_text = AutomotiveUI.label("",35,WHITE,true)
	elapsed_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(elapsed_text)
	gap_text = AutomotiveUI.label("",20,GREEN,true)
	gap_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(gap_text)
	progress = ProgressBar.new()
	progress.show_percentage = false
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.add_theme_stylebox_override("background", AutomotiveUI.surface(Color("172e3c"),Color.TRANSPARENT,2))
	progress.add_theme_stylebox_override("fill", AutomotiveUI.surface(BLUE,Color.TRANSPARENT,2))
	for style in ["background","fill"]:
		var box: StyleBoxFlat = progress.get_theme_stylebox(style)
		box.set_border_width_all(0)
		box.content_margin_top=0
		box.content_margin_bottom=0
	# A non-Control host keeps the rail outside the panel's row layout.
	var host := Node2D.new()
	status.add_child(host)
	host.add_child(progress)

func hide_status() -> void:
	status.hide()

func surface(r: Rect2, active: bool = false, warm: bool = false, radius: int = 15) -> void:
	var key := Vector3i(int(active),int(warm),radius)
	if not styles.has(key):
		var fill := Color("653621f5") if active and warm else (Color("193849f0") if active else (Color("2b201df0") if warm else Color("07131eea")))
		var s := AutomotiveUI.surface(fill,Color(ORANGE if warm else BLUE,.85 if active else .28),radius)
		s.shadow_color = Color(0,0,0,.22); s.shadow_size = 5; s.shadow_offset = Vector2(0,3)
		styles[key] = s
	g.draw_style_box(styles[key],r)
	g.draw_line(r.position+Vector2(20,1),Vector2(r.end.x-20,r.position.y+1),Color(ORANGE if warm else BLUE,.3 if active else .12),1,true)

func text(value: String,p: Vector2,size: int = 16,c: Color = WHITE,mono: bool = false) -> void:
	g.draw_string(AutomotiveUI.NUMBERS if mono else AutomotiveUI.DISPLAY,p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,c)

func centered(value: String,p: Vector2,size: int,c: Color = WHITE,mono: bool = false) -> void:
	var f: Font = AutomotiveUI.NUMBERS if mono else AutomotiveUI.DISPLAY
	text(value,p-Vector2(f.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x*.5,0),size,c,mono)

func control(id: String,label: String,r: Rect2,binding: String = "",warm: bool = false,selected: bool = false,enabled: bool = true) -> void:
	var held: bool = g.controls.value(id)>0 if RaceControls.HOLD_ACTIONS.has(id) else selected
	var hover: bool = r.has_point(g.get_local_mouse_position()) and not OS.has_feature("mobile") and not (g.screen=="race" and g.race_touch_layout())
	if not g.glass.states.has(id): g.glass.states[id] = {"hot":0.0,"pulse":0.0,"hover":false}
	g.glass.states[id].hover = hover
	var pulse: float = g.glass.states[id].pulse
	var physical: bool = g.screen=="race" and (CONTROL_ART.has(id) or id=="nitrous")
	var active := enabled and (held or selected or hover or pulse>0)
	var phone: bool = g.is_portrait() or g.race_touch_layout()
	g.buttons.append({"id":id,"rect":r,"disabled":not enabled})
	if physical:
		var pressed := enabled and (pulse>0 or (RaceControls.HOLD_ACTIONS.has(id) and held))
		hardware_control(id,label,r,binding if not phone else "",active,pressed,selected and enabled,enabled)
		return
	var radius := 10 if id.begins_with("manual_") else 15
	var face := r.grow(-maxf(pulse*1.5,2.0 if held else 0.0)) if not g.profile.reduced_motion else r
	surface(face,active,warm and enabled,radius)
	var ink := (ORANGE if warm else BLUE) if held or selected else WHITE
	if not enabled: ink = Color("52616d")
	var size := 24 if phone else 18
	var shown_label:=label
	while size>(20 if phone else 14) and AutomotiveUI.DISPLAY.get_string_size(shown_label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>r.size.x-24: size-=1
	while shown_label.length()>4 and AutomotiveUI.DISPLAY.get_string_size(shown_label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>r.size.x-24: shown_label=shown_label.left(shown_label.length()-4)+"..."
	centered(shown_label,r.get_center()+Vector2(0,6 if phone or binding=="" else 0),size,ink)
	if binding!="" and not phone: centered(binding,Vector2(r.get_center().x,r.end.y-10),11,DIM,true)
	if RaceControls.HOLD_ACTIONS.has(id):
		var level: float = g.controls.value(id)
		if level>.01: g.draw_line(Vector2(r.position.x+15,r.end.y-5),Vector2(r.position.x+15+(r.size.x-30)*level,r.end.y-5),Color(ORANGE if warm else BLUE,.9),3,true)

# The hardware artwork moves inside a stationary hit rectangle.
func hardware_control(id: String,label: String,r: Rect2,binding: String,active: bool,pressed: bool,selected: bool,enabled: bool) -> void:
	var warm := id=="gas" or id=="brake"
	surface(r,active,warm and pressed,14)
	var accent := ORANGE if warm else BLUE
	if pressed or selected:
		g.draw_line(r.position+Vector2(12,r.size.y-4),r.end-Vector2(12,4),Color(accent,.68),2,true)
	if id=="nitrous":
		nitrous_bottle(r,label,binding,pressed,enabled)
		return
	var paddle := id=="up" or id=="down"
	var side_label := not paddle and r.size.x/r.size.y>1.65 and r.size.x>=(130 if binding.is_empty() else 104)
	var area := r.grow(-5)
	if side_label: area.size.x *= .42
	elif not paddle: area.size.y -= 24 if binding.is_empty() else 20
	elif not binding.is_empty(): area.size.x -= 22
	var texture: Texture2D = CONTROL_ART[id]
	var art := fit_art(texture,area)
	if pressed and not g.profile.reduced_motion:
		art = art.grow(-1.5)
		art.position.y += 2
	if active and g.profile.effects_quality>0:
		AutomotiveUI.glow(g,art.grow(7),Color(accent,.26 if pressed or selected else .13))
	var light := Color(1,.89,.80) if pressed and warm else (Color(.78,.96,1) if pressed or selected else Color.WHITE)
	g.draw_texture_rect(texture,art,false,light)
	var ink := accent if pressed or selected else WHITE
	if paddle:
		if not binding.is_empty(): centered(binding,Vector2(r.end.x-19,r.get_center().y+4),12,DIM,true)
		return
	if side_label:
		var x := lerpf(area.end.x,r.end.x,.47)
		centered(label,Vector2(x,r.get_center().y+(5 if binding.is_empty() else 0)),14 if r.size.x<130 else 16,ink)
		if not binding.is_empty(): centered(binding,Vector2(x,r.get_center().y+15),11,DIM,true)
	else:
		var caption := label if binding.is_empty() else label+"  "+binding
		centered(caption,Vector2(r.get_center().x,r.end.y-9),17 if r.size.y>=80 else 12,ink)

func nitrous_bottle(r: Rect2,state: String,binding: String,pressed: bool,enabled: bool) -> void:
	var fraction: float = clampf(g.car.nitrous_remaining/maxf(g.car.nitrous_capacity(),.001),0,1) if enabled else 0.0
	var spraying: bool = enabled and g.car.nitrous_active
	var area := Rect2(r.position+Vector2(8,4),Vector2(r.size.x*.56,r.size.y-8))
	var bottle := fit_art(BOTTLE,area)
	if pressed and not g.profile.reduced_motion: bottle.position.y += 2
	if spraying and g.profile.effects_quality>0:
		AutomotiveUI.glow(g,bottle.grow(7),Color(BLUE,.32))
	g.draw_texture_rect(BOTTLE,bottle,false,Color.WHITE if enabled else Color(.65,.70,.75))
	if fraction>0:
		# Crop the charge at a moving meniscus while retaining the fixed metal shell.
		var edge := lerpf(13.0,124.0,fraction)/160.0
		var fill := Rect2(bottle.position,Vector2(bottle.size.x*edge,bottle.size.y))
		var source := Rect2(Vector2.ZERO,Vector2(CHARGE.get_width()*edge,CHARGE.get_height()))
		g.draw_texture_rect_region(CHARGE,fill,source,Color(1.2,1.2,1.2) if spraying else Color.WHITE)
		if fraction>.08 and fraction<.80:
			g.draw_line(Vector2(fill.end.x,bottle.position.y+bottle.size.y*.28),
				Vector2(fill.end.x,bottle.position.y+bottle.size.y*.72),Color(.64,.94,1,.65),1,true)
	var x := lerpf(area.end.x,r.end.x,.48)
	var title := "SPRAY" if spraying else "N₂O"
	centered(title,Vector2(x,r.get_center().y-4),19 if r.size.y>=80 else 16,BLUE if spraying else WHITE)
	var value := "%.1f s" % g.car.nitrous_remaining if enabled else state
	centered(value,Vector2(x,r.get_center().y+15),16 if r.size.y>=80 else 13,BLUE if enabled else DIM,true)
	if not binding.is_empty(): centered(binding,Vector2(bottle.get_center().x,r.end.y-5),10,DIM,true)

static func fit_art(texture: Texture2D,area: Rect2) -> Rect2:
	var pixels := texture.get_size()
	var extent := pixels*minf(area.size.x/pixels.x,area.size.y/pixels.y)
	return Rect2(area.get_center()-extent*.5,extent)

func sample() -> Dictionary:
	var c: Drivetrain = g.car
	var target := c.good_shift_min()
	if c.gear>0 and c.gear<=c.shift_map.size(): target = float(c.shift_map[c.gear-1])
	return {"rpm":c.rpm,"speed":c.speed*(3.6 if g.profile.metric_speed else Drivetrain.MPH_PER_MPS),"target":target,"gear":("R" if c.gear<0 else ("N" if c.gear==0 else str(c.gear))),"boost":c.boost,"nitrous":c.nitrous_remaining,"engaging":c.shift_left>0,"queued":c.queued_shift,"limiter":c.limiter}

func draw(portrait: bool = false) -> void:
	readings = sample()
	var w: float = 600 if portrait else g.race_view_size().x
	g.draw_race_world()
	top(w,portrait)
	stage(w,portrait)
	boss_intro(w,portrait)
	if portrait: lane_summary(w)
	dashboard(w,portrait)
	if g.debug_physics and OS.is_debug_build(): g.draw_telemetry()
	if g.paused_race: pause(w,portrait)

func boss_intro(w: float,portrait: bool) -> void:
	if not bool(g.active_contract.get("boss",false)) or g.countdown<=1.5: return
	var area:=Rect2(w*.5-232,198 if portrait else 148,464,68)
	surface(area)
	var gold:=Championships.TROPHY
	g.draw_line(area.position+Vector2(22,0),Vector2(area.end.x-22,area.position.y),Color(gold,.55),2,true)
	centered("CLASS %s / CHAMPIONSHIP BOSS"%g.active_contract.series,area.get_center()-Vector2(0,9),16,gold,true)
	centered(str(g.active_contract.name)+" / "+str(g.active_contract.nickname),area.get_center()+Vector2(0,17),22,WHITE)

func lane_summary(w: float) -> void:
	var x := w-20
	var staged: bool = g.countdown>0
	var last_split := "—"
	for marker in SPLITS:
		if g.split_times.has(marker):
			last_split = "%s   %.3f s"%[SPLITS[marker],g.staging.elapsed(g.split_times[marker])]
			break
	text("LANE 01  /  "+("STAGING" if staged else g.distance_label(g.active_distance)),Vector2(20,624),16,BLUE,true)
	var detail := "LAST SPLIT  "+last_split if not staged else ("ASSISTED" if g.staging.assisted else "MANUAL")
	var width := AutomotiveUI.NUMBERS.get_string_size(detail,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
	text(detail,Vector2(x-width,624),16,DIM,true)
	g.draw_line(Vector2(20,646),Vector2(x,646),Color(BLUE,.16),1,true)

func top(w: float,p: bool) -> void:
	var touch: bool = g.race_touch_layout() and not p
	var pause_size := Vector2(90,90) if touch else (Vector2(76,76) if p else Vector2(48,44))
	var pause_rect := Rect2(Vector2(w-pause_size.x-18,12),pause_size)
	control("pause","Ⅱ",pause_rect)
	var right := pause_rect.position.x-10
	if OS.is_debug_build() and not p and not touch:
		control("telemetry","F3",Rect2(right-48,12,48,44),"",false,g.debug_physics)
		right-=58
	var h := 77.0 if p or touch else 59.0
	status.position = Vector2(18,12)
	status.size = Vector2(right-18,h)
	status.visible = not g.paused_race
	var layout := 2 if touch else (1 if p else 0)
	if layout!=status_layout:
		status_layout=layout
		event_text.get_parent().size_flags_stretch_ratio=1.38 if p else 1.0
		gap_text.size_flags_stretch_ratio=.76 if p else 1.0
		elapsed_text.size_flags_stretch_ratio=1.12 if p else 1.0
		event_text.add_theme_font_size_override("font_size",23 if touch else (16 if p else 19))
		distance_text.add_theme_font_size_override("font_size",19 if touch else 15)
		elapsed_text.add_theme_font_size_override("font_size",41 if touch else (27 if p else 35))
		gap_text.add_theme_font_size_override("font_size",24 if touch else 20)
	var track := "TEST TRACK" if g.practice_mode else str(TrackPresentation.spec(g.race_track_index()).name).to_upper()
	if not g.practice_mode and g.active_contract.has("id"):
		track = str(g.active_contract.event_name).to_upper()
		if p and bool(g.active_contract.get("boss",false)):
			track = "CLASS %s BOSS"%g.active_contract.series
	event_text.text = track
	var meters := clampf(g.car.distance,0.0,g.active_distance)
	distance_text.text = "%d / %d m"%[floori(meters),roundi(g.active_distance)] if p else "%s  ·  %d/%d m"%[g.distance_label(g.active_distance),floori(meters),roundi(g.active_distance)]
	var total: float = g.player_finish if g.player_finish>0 else g.car.elapsed
	elapsed_text.text = "%.3f s"%g.staging.elapsed(total) if g.staging.released[0] else "0.000 s"
	var gap: float = g.car.distance-g.rival.distance
	gap_text.text = "SOLO" if g.practice_mode else ("%+.1f m"%gap if absf(gap)>=.05 else "EVEN")
	gap_text.add_theme_color_override("font_color",DIM if g.practice_mode or absf(gap)<.05 else (GREEN if gap>0 else ORANGE))
	var rail := Rect2(34,12+h-7,right-50,2)
	progress.position = rail.position-status.position
	progress.size = rail.size
	progress.max_value = g.active_distance
	progress.value = meters

func stage(w: float,p: bool) -> void:
	var touch: bool = g.race_touch_layout() and not p
	var y := 104.0 if p or touch else 78.0
	var message := ""
	var tint := GREEN
	if g.staging.red_light: message="RED LIGHT"; tint=ORANGE
	elif g.finish_hold_left>0: message="FINISH"
	elif g.staging.released[0] and g.player_reaction>=0 and g.player_reaction<=.30 and g.car.elapsed-g.player_reaction<.85:
		message="PERFECT LAUNCH"
	elif g.countdown<=0 and g.car.elapsed<.45: message="GO"
	if message!="":
		var chip := Rect2(w*.5-124,y,248,42)
		surface(chip,false,g.staging.red_light)
		var flash: float = maxf(g.feedback.start_flash,g.feedback.finish_flash)
		if message=="PERFECT LAUNCH": flash = 1-clampf((g.car.elapsed-g.player_reaction)/.85,0,1)
		if not g.profile.reduced_motion and g.profile.effects_quality>0:
			AutomotiveUI.glow(g,chip,Color(tint,flash*.28))
		centered(message,chip.get_center()+Vector2(0,7),21,tint,true)
	if g.countdown<=0: return
	var assist := Rect2(18,y,132,76 if p else (90 if touch else 44))
	control("staging_assist","ASSIST" if g.staging.assisted else "MANUAL",assist,"",false,g.staging.assisted)
	var panel := Rect2(assist.end.x+8,y,276,51)
	surface(panel)
	var base := panel.position+Vector2(13,17)
	for i in 2:
		var on: bool = g.staging.beam(0,i==0)
		g.draw_circle(base+Vector2(i*112,0),4,BLUE if on else Color("394857"))
		text("PRE-STAGE" if i==0 else "STAGE",base+Vector2(10+i*112,5),15,WHITE if on else DIM)
	var hint := ""
	if not g.staging.beam(0): hint="Ease forward to stage"
	elif g.car.has_transbrake: hint="Release transbrake on green"
	elif g.car.control_mode=="hpattern": hint="Release clutch on green"
	elif g.staging.assisted: hint="Launch on green"
	else: hint="Release brake on green"
	text(hint,base+Vector2(0,25),15,WHITE)
	var lamp := RaceStaging.lamp(g.countdown)
	var lamps := Rect2(panel.end.x+12,y,124,51)
	surface(lamps)
	for i in 3:
		var center := lamps.position+Vector2(30+i*32,25)
		var lit := i == lamp
		if lit and g.profile.effects_quality>0:
			AutomotiveUI.glow(g,Rect2(center-Vector2.ONE*18,Vector2.ONE*36),Color(ORANGE,.48))
		g.draw_circle(center,6,ORANGE if lit else Color("304050"),true,-1,true)

func tach(center: Vector2,width: float,p: bool) -> void:
	var c: Drivetrain = g.car
	var maximum := ceilf((c.redline_rpm+300)/1000)*1000
	var steps := int(maximum/1000)
	var rpm: float = c.rpm if g.profile.reduced_motion else g.feedback.visual_rpm
	var start := center.x-width*.5
	var fraction := clampf(rpm/maximum,0,1)
	var capable: bool = c.gear>0 and c.gear<c.gear_ratios.size() and c.control_mode!="automatic"
	var shift_fill := clampf((c.rpm-(float(readings.target)-1500))/1500,0,1) if capable and g.show_shift_guide and c.shift_left<=0 else 0.0
	for i in 9:
		var lit := shift_fill>=(i+1)/9.0
		var ink := BLUE if i<6 else (GREEN if c.shift_recommended() else ORANGE)
		g.draw_rect(Rect2(center.x-87+i*20,center.y-48,14,5),ink if lit else Color("263c4b"))
	var bar_y := center.y-29
	for i in 24:
		var t := i/24.0
		var length := width/24.0-2
		var x := start+i*width/24.0
		var red := (i+.5)/24.0*maximum>=c.redline_rpm
		var ink := ORANGE if red or c.limiter else BLUE
		g.draw_rect(Rect2(x,bar_y,length,14),Color(ink,.36 if red else .16))
		var fill := clampf((fraction-t)*24,0,1)*length
		if fill>0: g.draw_rect(Rect2(x,bar_y,fill,14),ink)
	for i in steps+1:
		var x := start+width*i/steps
		centered(str(i),Vector2(x,center.y+5),18 if g.race_touch_layout() and not p else (15 if p else 12),ORANGE if i*1000>=c.redline_rpm else DIM,true)
	centered("%04d RPM"%roundi(c.rpm),center+Vector2(0,39),31,ORANGE if c.limiter else WHITE,true)
	var hint := "RPM × 1000"
	var tint := DIM
	var f: RaceFeedback = g.feedback
	if f.grind_notice>0: hint="GEAR GRIND · HOLD CLUTCH"; tint=RED
	elif f.gearbox_warning>.10: hint="TRANSMISSION SLIPPING"; tint=GEARBOX_VIOLET
	elif f.clutch_warning>.10: hint="CLUTCH SLIP"; tint=CLUTCH_AMBER
	elif f.traction_lost: hint="WHEELSPIN"; tint=ORANGE
	elif f.traction_recovered>0: hint="GRIP RECOVERED"; tint=GREEN
	elif c.limiter: hint="REV LIMITER"; tint=ORANGE
	elif g.shift_notice_left>0: hint=g.shift_notice; tint=ORANGE
	elif g.shift_flash>0 and c.shift_message!="":
		hint=c.shift_message; tint=GREEN if hint=="PERFECT SHIFT" else BLUE
	elif capable and c.shift_recommended() and g.show_shift_guide: hint="SHIFT WINDOW"; tint=GREEN
	centered(hint,center+Vector2(0,61),18 if p or g.race_touch_layout() else 15,tint,true)
	if f.traction_lost or f.traction_recovered>0:
		var level := clampi(ceili(c.wheelspin*5.0),1,5) if f.traction_lost else 5
		var pulse := .75+.25*sin(g.clock*16) if f.traction_lost and not g.profile.reduced_motion else 1.0
		for i in 5:
			var ink := ORANGE if f.traction_lost else GREEN
			g.draw_rect(Rect2(center+Vector2(-42+i*17,69),Vector2(14,4)),Color(ink,pulse if i<level else .19))

func dashboard(w: float,p: bool) -> void:
	var c: Drivetrain = g.car
	var touch: bool = g.race_touch_layout()
	var cx := w*.5
	if touch and not p and c.control_mode=="hpattern": cx+=42
	var dial_y := 764.0 if p else 634.0
	var width := 256.0 if p else (320.0 if touch else 284.0)
	var cluster := Rect2(cx-(282 if p else 268),dial_y-70,564 if p else 536,154)
	surface(cluster)
	tach(Vector2(cx,dial_y),width,p)
	var gear_pos := Vector2(cx-(204 if p else 218),dial_y+12)
	var speed_pos := Vector2(cx+(204 if p else 218),dial_y+12)
	var perfect: bool = g.shift_flash>0 and c.shift_message=="PERFECT SHIFT"
	var gear_color := GREEN if perfect else (BLUE if c.shift_left>0 else WHITE)
	var offset: float = 0.0 if g.profile.reduced_motion else 7.0*c.shift_direction*g.feedback.shift_pulse
	centered(str(readings.gear),gear_pos+Vector2(0,offset),52,gear_color,true)
	centered("GEAR",gear_pos+Vector2(0,24),15,DIM)
	var mode := "AUTO" if c.control_mode=="automatic" else c.transmission_kind.to_upper()
	var gear_status := mode
	if g.shift_flash>.46 and c.shift_message not in ["NEUTRAL","DRIVE"]: gear_status="↑ UPSHIFT" if c.shift_direction>0 else "↓ DOWNSHIFT"
	elif c.queued_shift!=0: gear_status="QUEUED "+("+" if c.queued_shift>0 else "−")
	centered(gear_status,gear_pos+Vector2(0,45),13,gear_color if g.shift_flash>.46 or perfect else DIM)
	var speed: float = readings.speed if g.profile.reduced_motion else g.feedback.visual_mph*(1.609344 if g.profile.metric_speed else 1.0)
	centered("%03d"%roundi(speed),speed_pos,44,WHITE,true)
	centered("KM/H" if g.profile.metric_speed else "MPH",speed_pos+Vector2(0,24),15,BLUE)
	g.buttons.append({"id":"race_units","rect":Rect2(speed_pos-Vector2(52,48),Vector2(104,92))})
	if c.base_boost>0 or c.turbo_stage>0:
		centered("%.2f BAR"%c.boost,speed_pos+Vector2(0,47),13,BLUE,true)
	var left := 20.0
	var right := w-286
	var row := 940.0 if p else (612.0 if touch else 608.0)
	var ch := 88.0 if p else (128.0 if touch else 60.0)
	var columns := 3 if c.control_mode=="hpattern" else 2
	if c.control_mode=="hpattern":
		var count: int = c.gear_ratios.size()
		columns = ceili(count/2.0)
		var gate_width := 288.0 if touch and not p else 252.0
		var cell: float = gate_width/columns
		var gate_y := row if p else (548.0 if touch else 590.0)
		var gate_step := 78.0 if p else (96.0 if touch else 54.0)
		var gate_h := 70.0 if p else (90.0 if touch else 48.0)
		# Connected H gate, with numbered direct-selection pads on each branch.
		g.draw_line(Vector2(left+cell*.5,gate_y+gate_step-5),Vector2(left+gate_width-cell*.5,gate_y+gate_step-5),Color(BLUE,.4),2,true)
		for gear in range(1,count+1):
			var col := int((gear-1)/2); var rr := (gear-1)%2
			control("manual_%d"%gear,str(gear),Rect2(left+col*cell,gate_y+rr*gate_step,cell-5,gate_h),"",false,c.gear==gear)
		control("manual_0","N",Rect2(24,842,92,72) if p else Rect2(left+gate_width+8,548 if touch else 590,112 if touch else 48,90 if touch else 48),"",false,c.gear==0)
	elif c.control_mode in ["paddle","sequential"]:
		control("down","",Rect2(left,row,120,ch),"Q")
		control("up","",Rect2(left+132,row,120,ch),"E",false,g.show_shift_guide and c.shift_recommended())
	var no_aux: bool = c.has_converter or c.transmission_kind=="dct"
	var pedal_y := (1050.0 if no_aux and not c.has_transbrake else 1182.0) if p else row
	var pedal_h := (222.0 if no_aux and not c.has_transbrake else 90.0) if p else ch
	var aux := Rect2(left,1100,252,70) if p else Rect2(left,row+70,252,58)
	if touch and not p:
		if c.control_mode=="hpattern": aux=Rect2(left+296,648,112,90)
		elif c.has_transbrake: aux=Rect2(left,row,202,ch)
		else: aux=Rect2(left+264,row,132,ch)
	elif not p and c.control_mode=="hpattern": aux=Rect2(left,700,252,44)
	if c.has_transbrake:
		control("transbrake","TRANSBRAKE",aux,"B",false,g.transbrake_input())
	elif not no_aux:
		control("clutch","CLUTCH",aux,"SHIFT",false,g.clutch_input()>.01)
	if p:
		control("brake","BRAKE",Rect2(left,pedal_y,252,pedal_h),"S")
		right=312
		control("gas","THROTTLE",Rect2(right,1050,264,222),"W",true)
	else:
		control("brake","BRAKE",Rect2(right,row+(16 if touch else 0),108,ch-(16 if touch else 0)),"S")
		control("gas","THROTTLE",Rect2(right+119,row,147,ch),"W",true)
	var nr := Rect2(right,940 if p else (514 if touch else row+ch+10),264 if p else 262,88 if p else (90 if touch else 58))
	var nitrous_lock: String = g.nitrous_lock_reason()
	var available: bool = c.nitrous_remaining>.001 and nitrous_lock==""
	control("nitrous","EMPTY" if nitrous_lock=="" else nitrous_lock,nr,"SPACE",false,c.nitrous_active,available)

func pause(w: float,p: bool) -> void:
	g.draw_rect(Rect2(0,0,w,1300 if p else 760),Color("02080eed")); g.buttons.clear()
	var x := w*.5-160
	centered("RACE PAUSED",Vector2(w*.5,355 if p else 282),28)
	if OS.is_debug_build(): control("telemetry","DATA",Rect2(w*.5+184,270 if p else 222,90,90),"",false,g.debug_physics)
	var large: bool = p or g.race_touch_layout()
	var y := 410 if p else 320
	var step := 100 if large else 80
	var height := 90 if large else 62
	control("resume","RESUME",Rect2(x,y,320,height),"",true)
	control("garage","END TEST" if g.practice_mode else "FORFEIT $%d / GARAGE"%g.active_stake,Rect2(x,y+step,320,height))
	control("race_units","UNITS: "+("KM/H" if g.profile.metric_speed else "MPH"),Rect2(x,y+step*2,154,height))
	control("race_guide","GUIDE: "+("ON" if g.show_shift_guide else "OFF"),Rect2(x+166,y+step*2,154,height),"",false,g.show_shift_guide)
	control("effects_quality","EFFECTS: "+["LOW","MEDIUM","HIGH"][g.profile.effects_quality],Rect2(x,y+step*3,320,height))
