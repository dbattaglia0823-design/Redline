class_name RaceHUD
extends RefCounted

# Read-only dashboard: all hit targets route through the existing race input path.
const BLUE := GlassPalette.BLUE
const DIM := GlassPalette.MUTED
const WHITE := GlassPalette.INK
const ORANGE := GlassPalette.ORANGE
const GREEN := GlassPalette.GREEN
var g: Node2D
var styles: Dictionary = {}
var readings: Dictionary = {}

func _init(game: Node2D) -> void: g = game

func surface(r: Rect2, active: bool = false, warm: bool = false) -> void:
	var key := str(active)+str(warm)
	if not styles.has(key):
		var s := StyleBoxFlat.new()
		s.bg_color = Color("523023ed") if active and warm else (Color("193849ee") if active else Color("07131eea"))
		s.border_color = Color(ORANGE if warm else BLUE,.85 if active else .28)
		s.set_border_width_all(1); s.set_corner_radius_all(18)
		s.shadow_color = Color(0,0,0,.22); s.shadow_size = 5; s.shadow_offset = Vector2(0,3)
		styles[key] = s
	g.draw_style_box(styles[key],r)
	g.draw_line(r.position+Vector2(20,1),Vector2(r.end.x-20,r.position.y+1),Color(ORANGE if warm else BLUE,.3 if active else .12),1,true)

func text(value: String,p: Vector2,size: int = 16,c: Color = WHITE,mono: bool = false) -> void:
	g.text_at(value,p.x,p.y,size,c,mono)

func centered(value: String,p: Vector2,size: int,c: Color = WHITE,mono: bool = false) -> void:
	var f: Font = g.mono if mono else g.font
	text(value,p-Vector2(f.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x*.5,0),size,c,mono)

func control(id: String,label: String,r: Rect2,binding: String = "",warm: bool = false,selected: bool = false,enabled: bool = true) -> void:
	var held: bool = g.controls.value(id)>0 if RaceControls.HOLD_ACTIONS.has(id) else selected
	var hover: bool = r.has_point(g.get_local_mouse_position()) and not OS.has_feature("mobile")
	if not g.glass.states.has(id): g.glass.states[id] = {"hot":0.0,"pulse":0.0,"hover":false}
	g.glass.states[id].hover = hover
	var pulse: float = g.glass.states[id].pulse
	surface(r.grow(-pulse*1.5) if not g.profile.reduced_motion else r,held or selected or (hover and enabled) or pulse>0,warm and enabled)
	var ink := (ORANGE if warm else BLUE) if held or selected else WHITE
	if not enabled: ink = Color("52616d")
	var phone: bool = g.is_portrait() or g.race_touch_layout()
	var size := 24 if phone else 18
	var shown_label:=label
	while size>(20 if phone else 14) and g.font.get_string_size(shown_label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>r.size.x-24: size-=1
	while shown_label.length()>4 and g.font.get_string_size(shown_label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>r.size.x-24: shown_label=shown_label.left(shown_label.length()-4)+"..."
	centered(shown_label,r.get_center()+Vector2(0,6 if phone or binding=="" else 0),size,ink)
	if binding!="" and not phone: centered(binding,Vector2(r.get_center().x,r.end.y-10),11,DIM,true)
	if RaceControls.HOLD_ACTIONS.has(id):
		var level: float = g.controls.value(id)
		if id=="gas": level = g.car.throttle
		elif id=="clutch": level = 1-g.car.clutch_engagement
		if level>.01: g.draw_line(Vector2(r.position.x+15,r.end.y-5),Vector2(r.position.x+15+(r.size.x-30)*level,r.end.y-5),Color(ORANGE if warm else BLUE,.9),3,true)
	g.buttons.append({"id":id,"rect":r,"disabled":not enabled})

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
	dashboard(w,portrait)
	if g.debug_physics and OS.is_debug_build(): g.draw_telemetry()
	if g.paused_race: pause(w,portrait)

func top(w: float,p: bool) -> void:
	var h := 96 if p else (108 if g.race_touch_layout() else 52)
	surface(Rect2(16,10,w-32,h))
	var track := "TEST TRACK" if g.practice_mode else str(TrackPresentation.spec(g.race_track_index()).name)
	if not g.practice_mode and g.active_contract.has("id"):
		track="CLASS "+str(g.active_contract.series)+(" / FINAL" if int(g.active_contract.round)==4 else " / RIVAL" if int(g.active_contract.round)==3 else " / HEAT %d"%(int(g.active_contract.round)+1))
		if str(g.active_contract.series)=="OPEN": track=str(g.active_contract.event_name).to_upper()
	text(track,Vector2(32,34),17 if p else (20 if g.race_touch_layout() else 13),BLUE)
	text(g.distance_label(g.active_distance),Vector2(32,64 if p else 49),17 if p else (18 if g.race_touch_layout() else 12),DIM)
	var time: float = g.player_finish if g.finish_hold_left>0 else g.car.elapsed
	centered("%.3f"%time,Vector2(284 if p else w*.5,65 if p else 40),40 if g.race_touch_layout() and not p else 34,WHITE,true)
	if not p: text("s",Vector2(w*.5+63,40),14,DIM)
	var gap: float = g.car.distance-g.rival.distance
	var lead := ("+" if gap>=0 else "-")+"%.1f m"%absf(gap)
	text("PRACTICE" if g.practice_mode else lead,Vector2(365 if p else w-287,72 if p else 31),24 if g.race_touch_layout() and not p else 19,GREEN if gap>=0 else ORANGE,true)
	if not p: text("%d / %d m"%[mini(int(g.car.distance),int(g.active_distance)),roundi(g.active_distance)],Vector2(w-287,49),12,DIM,true)
	var r := Rect2(32,h-1,(w-64 if p else w-386),3)
	g.draw_rect(r,Color(BLUE,.12)); g.draw_rect(Rect2(r.position,Vector2(r.size.x*clampf(g.car.distance/g.active_distance,0,1),3)),BLUE)
	control("pause","II",Rect2(w-116,12,90,90) if g.race_touch_layout() and not p else (Rect2(w-100,16,76,76) if p else Rect2(w-78,12,50,44)))
	if OS.is_debug_build() and not p and not g.race_touch_layout(): control("telemetry","F3",Rect2(w-136,12,50,44),"",false,g.debug_physics)

func stage(w: float,p: bool) -> void:
	if g.countdown>0:
		var r := Rect2(24,120 if p else (126 if g.race_touch_layout() else 92),340 if p else 310,52)
		surface(r)
		for i in 2:
			var on: bool = g.staging.beam(0,i==0)
			g.draw_circle(r.position+Vector2(17+i*119,17),3,GREEN if on else DIM)
			text("PRE-STAGE" if i==0 else "STAGE",r.position+Vector2(27+i*119,22),12,GREEN if on else DIM)
		var hint := "Clutch + gas / release on green" if g.car.control_mode=="hpattern" else ("Gas + transbrake / release on green" if g.car.has_transbrake else ("Hold gas / watch tree" if g.staging.assisted else "Brake + gas / release on green"))
		text(hint,r.position+Vector2(14,43),15 if p else 13,DIM)
		control("staging_assist","ASSIST" if g.staging.assisted else "MANUAL",Rect2(24,180 if p else (186 if g.race_touch_layout() else 152),140,72 if p else (90 if g.race_touch_layout() else 52)),"",false,g.staging.assisted)
	var message := ""
	var tint := GREEN
	if g.staging.red_light: message="RED LIGHT"; tint=ORANGE
	elif g.finish_hold_left>0: message="FINISH"
	elif g.countdown<=0 and g.car.elapsed<.5: message="GO"
	if message!="": centered(message,Vector2(w*.5,204 if p else 130),28,tint,true)

func tach(center: Vector2,radius: float,p: bool) -> void:
	var c: Drivetrain = g.car
	var maximum: float = ceilf((c.redline_rpm+400)/1000)*1000
	var steps := int(maximum/1000)
	var actual := clampf(g.feedback.visual_rpm/maximum,0,1)
	g.draw_arc(center,radius,PI,TAU,64,Color(BLUE,.12),9,true)
	var red := PI+PI*c.redline_rpm/maximum
	g.draw_arc(center,radius,red,TAU,16,Color(ORANGE,.8 if c.limiter else .45),9,true)
	g.draw_arc(center,radius,PI,PI+actual*PI,64,ORANGE if c.limiter else BLUE,5,true)
	for i in steps+1:
		var angle: float = PI+PI*i/steps
		var v := Vector2(cos(angle),sin(angle))
		g.draw_line(center+v*(radius-12),center+v*(radius-18),ORANGE if i*1000>=c.redline_rpm else DIM,1,true)
		centered(str(i),center+v*(radius-30)+Vector2(0,5),20 if g.race_touch_layout() and not p else (17 if p else 12),DIM,true)
	var needle := Vector2(cos(PI+actual*PI),sin(PI+actual*PI))
	g.draw_line(center+needle*42,center+needle*(radius-22),ORANGE,2,true)
	centered("%04d"%roundi(c.rpm),center-Vector2(0,25),36 if p or g.race_touch_layout() else 29,ORANGE if c.limiter else WHITE,true)
	centered("RPM x 1000",center-Vector2(0,6),12,DIM)
	var target: float = readings.target
	var capable: bool = c.gear>0 and c.gear<c.gear_ratios.size()
	var fraction := clampf((c.rpm-(target-1700))/1700,0,1) if capable and g.show_shift_guide else 0.0
	for i in 9:
		var lit: bool = fraction >= (i+1)/9.0
		var color := GREEN if i<6 else ORANGE
		var pos := center+Vector2((i-4)*16,-radius-18)
		g.draw_circle(pos,4,color if lit else Color(BLUE,.14))
	var hint := "LIMITER" if c.limiter else ("SHIFT" if c.upshift_ready() and g.show_shift_guide else "")
	if g.shift_notice_left>0: hint=g.shift_notice
	elif g.shift_flash>0: hint=c.shift_message
	if hint.length()>26: hint=hint.left(26)
	centered(hint,center+Vector2(0,22),13,ORANGE if c.limiter or g.shift_notice_left>0 else GREEN)

func dashboard(w: float,p: bool) -> void:
	var c: Drivetrain = g.car
	var top_y := 604 if p else (548 if g.race_touch_layout() else 582)
	surface(Rect2(16,top_y,w-32,(680 if p else 746-top_y)))
	var cx := w*.5
	var touch: bool = g.race_touch_layout()
	# A narrow landscape screen needs room for the manual clutch beside the gate.
	if touch and not p and (c.has_transbrake or (not c.has_converter and c.transmission_kind!="dct")): cx+=84
	tach(Vector2(cx,850 if p else 721),145 if p else (132 if touch else 112),p)
	var gear_pos := Vector2(91,760) if p else Vector2(cx-(172 if touch else 201),667)
	centered(str(readings.gear),gear_pos,62 if p else 53,ORANGE if c.shift_left>0 else WHITE,true)
	centered("GEAR",gear_pos+Vector2(0,24),18 if touch else 12,DIM)
	var status := "ENGAGING" if c.shift_left>0 else ("QUEUED" if c.queued_shift!=0 else c.transmission_kind.to_upper())
	centered(status,gear_pos+Vector2(0,45),11,ORANGE if c.shift_left>0 else DIM)
	if c.queued_shift!=0: centered("QUEUED "+("+" if c.queued_shift>0 else "-"),gear_pos+Vector2(0,62),12,BLUE)
	var speed_pos := Vector2(484,760) if p else Vector2(cx+183,667)
	centered("%03d"%roundi(g.feedback.visual_mph*(1.609344 if g.profile.metric_speed else 1.0)),speed_pos,49 if p else 44,WHITE,true)
	centered("KM/H" if g.profile.metric_speed else "MPH",speed_pos+Vector2(0,24),18 if touch else 12,BLUE)
	g.buttons.append({"id":"race_units","rect":Rect2(speed_pos-Vector2(65,58),Vector2(130,90))})
	if c.base_boost>0 or c.turbo_stage>0: centered("%.2f BAR"%c.boost,speed_pos+Vector2(0,46),12,DIM,true)
	if c.wheelspin>.15 and c.throttle>.1: centered("TRACTION",Vector2(cx,905 if p else 741),12,ORANGE)
	var left := 24.0
	var right := w-286
	var row := 940.0 if p else (586.0 if touch else 594.0)
	var ch := 88.0 if p else (146.0 if touch else 62.0)
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
		control("manual_0","N",Rect2(24,842,92,72) if p else Rect2(left+gate_width+8,548 if touch else 590,90 if touch else 48,90 if touch else 48),"",false,c.gear==0)
	elif c.control_mode!="automatic":
		control("down","-",Rect2(left,row,120,ch),"Q")
		control("up","+",Rect2(left+132,row,120,ch),"E",true,g.show_shift_guide and c.upshift_ready())
	else:
		centered("AUTO",Vector2(left+126,row+38),24,BLUE,true)
		centered("%d-SPEED / SHIFT MAP"%c.gear_ratios.size(),Vector2(left+126,row+63),12,DIM)
	var no_aux: bool = c.has_converter or c.transmission_kind=="dct"
	var pedal_y := (1050.0 if no_aux and not c.has_transbrake else 1182.0) if p else row
	var pedal_h := (222.0 if no_aux and not c.has_transbrake else 90.0) if p else ch
	var aux_y := 1100.0 if p else (700.0 if c.control_mode=="hpattern" and not touch else (row+74 if not touch else row))
	var aux_x := left if p or not touch else left+396
	if c.has_transbrake:
		control("transbrake","TRANSBRAKE",Rect2(aux_x,aux_y,252 if p or not touch else 145,70 if p else (ch if touch else (44 if c.control_mode=="hpattern" else 58))),"B",false,g.transbrake_input())
	elif not c.has_converter and c.transmission_kind!="dct":
		control("clutch","CLUTCH",Rect2(aux_x,aux_y,252 if p or not touch else 145,70 if p else (ch if touch else (44 if c.control_mode=="hpattern" else 58))),"SHIFT",false,g.clutch_input()>.01)
	if p:
		control("brake","BRAKE",Rect2(left,pedal_y,252,pedal_h),"S")
		right=312
		control("gas","THROTTLE",Rect2(right,1050,264,222),"W",true)
	else:
		control("brake","BRAKE",Rect2(right,row,114,ch),"S")
		control("gas","THROTTLE",Rect2(right+126,row,136,ch),"W",true)
	var nr := Rect2(right,940 if p else (490 if touch else row+ch+10),264 if p else 262,88 if p else (90 if touch else 58))
	var kit_allowed: bool=g.practice_mode or not g.active_contract.has("id") or c.nitrous_stage>0 or c.hardware.parts.values().has("progressive")
	var available: bool = c.nitrous_remaining>.001 and kit_allowed
	control("nitrous","N2O  %.1fs"%c.nitrous_remaining if available else ("N2O / FIT KIT" if not kit_allowed else "N2O  UNAVAILABLE"),nr,"SPACE",false,c.nitrous_active,available)
	if available:
		g.draw_line(nr.position+Vector2(16,nr.size.y-5),Vector2(nr.position.x+16+(nr.size.x-32)*clampf(c.nitrous_remaining/c.nitrous_capacity(),0,1),nr.end.y-5),GREEN,2,true)

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
