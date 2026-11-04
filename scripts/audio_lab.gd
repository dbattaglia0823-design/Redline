class_name AudioLab
extends CanvasLayer

var game: Node2D
var panel: PanelContainer
var root_control: Control
var content: VBoxContainer
var advanced: VBoxContainer
var vehicle_picker: OptionButton
var build_picker: OptionButton
var family_picker: OptionButton
var mode_picker: OptionButton
var values: Dictionary={}
var flags: Dictionary={}
var status: Label
var title: Label
var preview:=Drivetrain.new()
var selected_source: Drivetrain
var time:=0.0
var playing:=true
var compact:=false
var _building:=false
var _saved_layers: Dictionary={}
var _layout_size:=Vector2.ZERO
var layer_toggles: Dictionary={}
var play_toggle: CheckButton

func setup(owner_game: Node2D) -> void:
	game=owner_game; layer=100; visible=false
	root_control=Control.new(); root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(root_control)
	var dim:=ColorRect.new(); dim.color=Color(0,0,0,.84); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root_control.add_child(dim)
	panel=PanelContainer.new(); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); panel.offset_left=24; panel.offset_top=24; panel.offset_right=-24; panel.offset_bottom=-24; root_control.add_child(panel)
	var style:=StyleBoxFlat.new(); style.bg_color=Color("0c1925"); style.border_color=Color("2c607b"); style.set_border_width_all(1); style.set_corner_radius_all(18); style.content_margin_left=22; style.content_margin_right=22; style.content_margin_top=18; style.content_margin_bottom=18; panel.add_theme_stylebox_override("panel",style)
	var theme:=Theme.new(); theme.default_font_size=19
	for kind in ["Button","OptionButton","CheckButton"]:
		var normal:=style.duplicate(); normal.bg_color=Color("132b3a"); normal.content_margin_top=8; normal.content_margin_bottom=8
		theme.set_stylebox("normal",kind,normal); var hover:=normal.duplicate(); hover.border_color=Color("e47e42"); theme.set_stylebox("hover",kind,hover); theme.set_stylebox("pressed",kind,hover)
	panel.theme=theme
	var scroll:=ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; panel.add_child(scroll)
	content=VBoxContainer.new(); content.size_flags_horizontal=Control.SIZE_EXPAND_FILL; content.add_theme_constant_override("separation",12); scroll.add_child(content)
	var head:=HBoxContainer.new(); content.add_child(head)
	title=Label.new(); title.text="AUDIO LAB"; title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; head.add_child(title)
	var play:=CheckButton.new(); play.text="Play"; play.button_pressed=true; play.toggled.connect(func(v): playing=v); head.add_child(play)
	play_toggle=play
	var close:=Button.new(); close.text="Close"; close.custom_minimum_size=Vector2(100,48); close.pressed.connect(hide_lab); head.add_child(close)
	vehicle_picker=OptionButton.new(); vehicle_picker.custom_minimum_size.y=48
	for id in RosterData.IDS: vehicle_picker.add_item(str(GameCatalog.spec(id).name))
	vehicle_picker.item_selected.connect(func(_i): if not _building: selected_source=null; rebuild())
	content.add_child(vehicle_picker)
	build_picker=OptionButton.new(); build_picker.custom_minimum_size.y=48
	for name in ["Factory build","Installed build","Intake + exhaust audition","Selected upgrade"]: build_picker.add_item(name)
	build_picker.item_selected.connect(func(_i): if not _building: rebuild()); content.add_child(build_picker)
	mode_picker=OptionButton.new()
	for name in ["Manual state","RPM sweep / lift","Physics acceleration run"]: mode_picker.add_item(name)
	mode_picker.selected=1; mode_picker.item_selected.connect(func(_i): time=0; preview.reset(); preview.running=true); content.add_child(mode_picker)
	advanced=VBoxContainer.new(); advanced.add_theme_constant_override("separation",12); content.add_child(advanced)
	family_picker=OptionButton.new(); family_picker.add_item("Engine family: automatic")
	for name in ["i4_na","i4_vtec","i4_turbo","h4_na","h4_turbo","i6_na","i6_turbo","vr6_na","v6_na","v6_tt","v8_cross","v8_flat","v8_super","v8_flat_tt","v10_na","h6_na","h6_turbo","w16_tt"]: family_picker.add_item(name)
	family_picker.item_selected.connect(func(_i): rebuild()); advanced.add_child(family_picker)
	for row in [["RPM",500,11500,850],["Throttle",0,1,.8],["Load",-1,1,.7],["Boost bar",0,3,0],["Gear",0,10,1],["Clutch engagement",0,1,1]]:
		var line:=HBoxContainer.new(); advanced.add_child(line)
		var label:=Label.new(); label.text=row[0]; label.custom_minimum_size.x=155; line.add_child(label)
		var slider:=HSlider.new(); slider.min_value=row[1]; slider.max_value=row[2]; slider.step=1 if row[0] in ["RPM","Gear"] else .01; slider.value=row[3]; slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL; slider.custom_minimum_size.y=48; line.add_child(slider); values[row[0]]=slider
	var state_row:=HBoxContainer.new(); advanced.add_child(state_row)
	for name in ["Shifting","Limiter","Nitrous"]:
		var toggle:=CheckButton.new(); toggle.text=name; state_row.add_child(toggle); flags[name]=toggle
	var layer_grid:=GridContainer.new(); layer_grid.columns=2; advanced.add_child(layer_grid)
	for name in ["exhaust","intake","mechanical","induction","tires","nitrous","environment"]:
		var toggle:=CheckButton.new(); toggle.text=name.capitalize(); toggle.button_pressed=true; layer_grid.add_child(toggle)
		layer_toggles[name]=toggle
		toggle.toggled.connect(func(v): game.sound.layers[name]=v)
	status=Label.new(); status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; content.add_child(status)

static func copy_car(source: Drivetrain) -> Drivetrain:
	var c:=Drivetrain.new(); c.configure_vehicle(source._base_spec.duplicate(true))
	c.configure([source.engine_stage,source.turbo_stage,source.tire_stage,source.weight_stage,source.gearbox_stage,source.exhaust_stage,source.brake_stage,source.nitrous_stage])
	c.configure_build(source.hardware.duplicate(true),str(source._base_spec.get("id","kaze")),false); c.reset(); c.running=true
	return c

func open_lab(source: Drivetrain=null,simple: bool=false) -> void:
	if not simple and not (OS.is_debug_build() or OS.has_feature("editor")): return
	_building=true; compact=simple; selected_source=copy_car(source) if source!=null else null
	vehicle_picker.selected=maxi(0,RosterData.IDS.find(game.profile.vehicle_id)); vehicle_picker.visible=not compact
	build_picker.selected=3 if source!=null else 1; family_picker.selected=0; mode_picker.selected=1
	build_picker.set_item_disabled(2,compact); mode_picker.visible=not compact
	advanced.visible=not compact; title.text="SOUND PREVIEW" if compact else "AUDIO LAB / DEVELOPMENT"
	_saved_layers=game.sound.layers.duplicate(); _building=false; visible=true; playing=true
	play_toggle.set_pressed_no_signal(true)
	for name in layer_toggles: layer_toggles[name].set_pressed_no_signal(game.sound.layers.get(name,true))
	_layout_size=Vector2.ZERO
	game.controls.clear(); game.sound.preview_active=true; rebuild()

func hide_lab() -> void:
	if not visible: return
	visible=false; game.sound.preview_active=false; game.sound.preview_car=null; game.sound.layers=_saved_layers.duplicate()
	game.sound.update_vehicle(game.car); game.queue_redraw()

func rebuild() -> void:
	if _building or game==null: return
	var id: String=RosterData.IDS[vehicle_picker.selected]
	var levels:=GameCatalog.blank_stages(); var build:=GameCatalog.factory_build(id)
	if build_picker.selected==3 and selected_source!=null:
		preview=copy_car(selected_source)
	else:
		if build_picker.selected==1 and game.profile.garage.has(id):
			var entry: Dictionary=game.profile.garage[id]
			levels=game.profile.stages.duplicate() if id==game.profile.vehicle_id else entry.stages.duplicate()
			build=game.profile.hardware.duplicate(true) if id==game.profile.vehicle_id else entry.hardware.duplicate(true)
		if build_picker.selected==2:
			levels[5]=3; build.parts["intake"]="plenum"; build.parts["exhaust"]="headers"
			build.owned_parts.append("plenum"); build.owned_parts.append("headers")
		preview=Drivetrain.new(); preview.configure_vehicle(GameCatalog.spec(id)); preview.configure(levels); preview.configure_build(build,id,false); preview.reset(); preview.running=true
	if family_picker.selected>0: preview._base_spec["audio_family_override"]=family_picker.get_item_text(family_picker.selected)
	time=0; game.sound.preview_car=preview

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and RaceControls.key_code(event) in [KEY_ESCAPE,KEY_F7]:
		hide_lab(); get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	if not visible or game==null: return
	var area:=get_viewport().get_visible_rect().size
	if area!=_layout_size:
		_layout_size=area
		panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		panel.size=Vector2(minf(760,area.x-48),minf(260,area.y-48)) if compact else area-Vector2(48,48)
		panel.position=(area-panel.size)*.5
	if playing: time+=minf(dt,.1)
	if mode_picker.selected==2:
		if playing:
			if preview.shift_map.is_empty(): preview.rebuild_shift_map()
			var contract: Dictionary={"reaction":.25,"pedal":1.0,"skill":2,"shift_error":0,"traction_skill":.8}
			RaceAI.step(preview,contract,minf(dt,.1))
			if preview.distance>=402.336: preview.reset(); preview.running=true
	else:
		if mode_picker.selected==1:
			var phase:=fmod(time,12.0)
			preview.rpm=lerpf(preview.idle_rpm,preview.redline_rpm,smoothstep(0,1,phase/6)) if phase<6 else lerpf(preview.redline_rpm,preview.idle_rpm,smoothstep(0,1,(phase-6)/6))
			preview.throttle=.92 if phase<6 else .02; preview.engine_load=.75 if phase<6 else -.35
			preview.boost=preview.boost_target(preview.rpm,preview.throttle); preview.clutch_engagement=1
		else:
			preview.rpm=values.RPM.value; preview.throttle=values.Throttle.value; preview.engine_load=values.Load.value; preview.boost=values["Boost bar"].value; preview.clutch_engagement=values["Clutch engagement"].value
		preview.gear=clampi(int(values.Gear.value),0,preview.gear_ratios.size())
		preview.shift_left=.1 if flags.Shifting.button_pressed else 0
		preview.fuel_cut=flags.Limiter.button_pressed or (flags.Shifting.button_pressed and preview.control_mode!="hpattern")
		preview.combustion_fraction=.15 if flags.Limiter.button_pressed else (preview.shift_retention if flags.Shifting.button_pressed and preview.control_mode!="hpattern" else 1.0)
		if flags.Shifting.button_pressed and preview.control_mode=="hpattern": preview.clutch_engagement=0; preview.throttle=0
		preview.nitrous_active=flags.Nitrous.button_pressed; preview.nitrous_delivery=1 if preview.nitrous_active else 0
		preview.engine_torque=preview.full_engine_torque(preview.rpm)*preview.throttle if preview.throttle>.1 else -preview.base_torque*.15
	game.sound.preview_car=preview; game.sound.update_vehicle(preview,not playing)
	game.sound.pump()
	status.text="%s / %.0f RPM / load %.2f / %.2f bar\nOriginal synthesized loops + live effects"%[EngineAudioProfile.resolve(preview).family,preview.rpm,preview.engine_load,preview.boost]

