extends Node2D

const BG := GlassPalette.BG
const PANEL := GlassPalette.SURFACE
const EDGE := GlassPalette.EDGE
const INK := GlassPalette.INK
const MUTED := GlassPalette.MUTED
const ORANGE := GlassPalette.ORANGE
const GREEN := GlassPalette.GREEN
const PAINTS := [Color("eb704e"), Color("b8d6cb"), Color("e8dfc6"), Color("7b93cf"), Color("e7b44d"), Color("c68aad")]
const PAINT_NAMES := ["EMBER", "SEAFOAM", "BONE", "INDIGO", "SAFFRON", "ORCHID"]
const PART_NAMES = GameCatalog.PART_NAMES
const EVENT_NAMES: Array[String] = ["DOCKSIDE RUN", "MIDNIGHT CLUB", "CITY FINALS"]
const EVENT_LEVELS: Array[int] = [1, 3, 5]
const FINISH := 402.336

var font: Font
var mono: Font
var profile := DriverProfile.new()
var car := Drivetrain.new()
var rival := Drivetrain.new()
var sound: EngineAudio
var audio_lab: AudioLab
var screen := "garage"
var tab := "garage"
var clock := 0.0
var buttons: Array[Dictionary] = []
var controls := RaceControls.new()
var gamepad := GamepadControls.new()
var staging := RaceStaging.new()
var countdown := 3.0
var player_finish := 0.0
var rival_trap_speed := 0.0
var rival_finish := 0.0
var result_win := false
var result_record := false
var result_improvement := 0.0
var recovery_prompted := false
var rival_telemetry := RunTelemetry.new()
var result_bonus := 0
var result_reward := 0
var result_xp := 0
var previous_level := 1
var event_index := 0
var toast := ""
var toast_left := 0.0
var toast_confirmed := false
var shift_flash := 0.0
var audio_shift_serial := 0
var paused_race := false
var rival_shift_delay := 0.0
var finish_speed := 0.0
var input_override := Vector2(-1.0, -1.0)
var menu: GarageView
var workshop: UpgradeWorkshop
var selected_part := 0
var dealer_index := 0
var selected_opponent := 0
var wager := 0
var dragging_wager := ""
var active_contract: Dictionary = {}
var active_distance := FINISH
var active_stake := 0
var result_base_pay := 0
var result_bet_return := 0
var player_reaction := -1.0
var perfect_shifts := 0
var split_times: Dictionary = {}
var car_textures: Dictionary = {}
var workshop_texture: Texture2D
var sky_texture: Texture2D
var debug_physics := false
var feedback := RaceFeedback.new()
var rival_feedback := RaceFeedback.new()
var show_shift_guide := true
var shift_notice := ""
var shift_notice_left := 0.0
var seen_shift_request := 0
var finish_hold_left := 0.0
var shutting_down := false
var menu_dirty := true
var navigation_key := ""
var navigation_age := 1.0
var safe_insets := Vector4.ZERO
var career_board: CareerBoard
var tuning: TuningLab
var practice_mode := false
var manual_tree_armed := true
var run_telemetry := RunTelemetry.new()
var race_hud: RaceHUD
var mobile: MobileView
var glass := LiquidGlass.new()
var dock: GlassDock
var showroom_texture: Texture2D
var ui_offset := Vector2.ZERO
var native_workshop: WorkshopScreen
var display_font := AutomotiveUI.DISPLAY
var preview_states: Dictionary = {}

func _ready() -> void:
	gamepad.setup(self)
	font = AutomotiveUI.BODY
	mono = AutomotiveUI.NUMBERS
	profile.load_profile()
	glass.reduced_motion = profile.reduced_motion
	refresh_car()
	selected_opponent = mini(4, int(profile.career_wins[0]))
	workshop_texture = load("res://assets/workshop.svg")
	showroom_texture = load("res://assets/ui/showroom_premium.png")
	sky_texture = load("res://assets/sky.svg")
	menu = GarageView.new(self)
	mobile = MobileView.new(self)
	race_hud = RaceHUD.new(self)
	tuning = TuningLab.new(self)
	career_board = CareerBoard.new(self)
	workshop = UpgradeWorkshop.new(self)
	sound = EngineAudio.new()
	add_child(sound)
	sound.enabled = not profile.muted
	audio_lab=AudioLab.new(); add_child(audio_lab); audio_lab.setup(self)
	dock = GlassDock.new(); add_child(dock); dock.setup(self)
	native_workshop=RacingScreen.new(); add_child(native_workshop); native_workshop.setup(self)
	RenderingServer.set_default_clear_color(glass.PALETTE.background)
	get_window().size_changed.connect(sync_menu_size)
	get_tree().auto_accept_quit = false
	call_deferred("show_save_recovery")

func show_save_recovery() -> void:
	if not profile.save_blocked or recovery_prompted: return
	recovery_prompted=true
	var dialog := ConfirmationDialog.new()
	dialog.title="Progress recovery"
	dialog.exclusive=true
	dialog.dialog_text="The progress file could not be read. Restore the last verified backup?" if profile.recovery_available else "The progress file could not be read. Saving is paused to protect it."
	dialog.ok_button_text="Restore backup" if profile.recovery_available else "Close"
	dialog.cancel_button_text="Continue without saving"
	add_child(dialog)
	dialog.confirmed.connect(func():
		if profile.recovery_available:
			if profile.recover_backup():
				refresh_car()
				sound.enabled=not profile.muted
				glass.reduced_motion=profile.reduced_motion
				show_toast("Progress restored",true)
			else: show_toast("Backup restore failed. Progress file protected.")
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.get_label().autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	dialog.popup_centered(Vector2i(mini(460,get_window().size.x-24),160))

func is_portrait() -> bool: return get_window().size.x < get_window().size.y*.85

func race_view_size() -> Vector2i:
	if is_portrait(): return Vector2i(600,1300)
	var pixels := Vector2(get_window().size)
	return Vector2i(maxi(1200,roundi(pixels.x/maxf(1,pixels.y)*760)),760)

func race_touch_layout() -> bool:
	return OS.has_feature("mobile") or get_window().size.y < 600

func sync_menu_size() -> void:
	var target := race_view_size() if screen == "race" else (Vector2i(600,1300) if is_portrait() else Vector2i(1200,760))
	var catalog: bool=tab=="performance" and not menu.hub.dyno_open and (menu.hub.categories or workshop.mode in ["basic","hardware","transmission"])
	if (screen=="results" or (screen=="garage" and (catalog or tab in ["garage","dealer","owned","style","races"]))) and (not glass.legacy or screen=="results" or tab in ["races","style","garage"]) and not is_portrait() and get_window().size.y<500:
		target=race_view_size()
	if get_window().content_scale_size != target:
		get_window().content_scale_size = target
		controls.clear(); dragging_wager = ""; menu_dirty = true
		glass.backdrop = null
	var insets := safe_insets
	if OS.has_feature("mobile"):
		var area := DisplayServer.get_display_safe_area()
		var pixels := Vector2(get_window().size)
		if area.has_area() and pixels.x>0 and pixels.y>0:
			insets = Vector4(maxf(0,area.position.x),maxf(0,area.position.y),maxf(0,pixels.x-area.end.x),maxf(0,pixels.y-area.end.y))
			insets *= Vector4(target.x/pixels.x,target.y/pixels.y,target.x/pixels.x,target.y/pixels.y)
	var factor := minf((target.x-insets.x-insets.z)/target.x,(target.y-insets.y-insets.w)/target.y)
	var next_scale := Vector2.ONE*maxf(.5,factor)
	var next_position := Vector2(insets.x,insets.y)+(Vector2(target)-Vector2(insets.x+insets.z,insets.y+insets.w)-Vector2(target)*next_scale)*.5
	if scale!=next_scale or position!=next_position:
		scale=next_scale
		position=next_position
		controls.clear()
		dragging_wager=""
		menu_dirty=true

func race_track_index() -> int:
	return clampi(int(active_contract.get("track_index",event_index)),0,2) if screen=="race" else event_index

func rival_paint_index() -> int:
	return int(active_contract.get("paint_index",(event_index+selected_opponent+3)%6))%6

func rival_appearance() -> Dictionary:
	return VehicleAppearance.normalize({},rival_paint_index(),0 if active_contract.has("id") else 2)

func race_origins() -> Array[Vector2]:
	var player := Vector2(70,335) if is_portrait() else Vector2(210,410)
	# Actual distance gap controls position; a trailing rival must be able to leave the view.
	var rival_origin := Vector2(player.x+(rival.distance-car.distance)*TrackPresentation.pixels_per_meter(is_portrait()),200 if is_portrait() else 310)
	return [player,rival_origin]

func current_contract() -> Dictionary:
	return career_board.contract() if career_board!=null else {}

func normalize_wager() -> void:
	wager = clampi(wager,0,mini(profile.credits,int(current_contract().get("max_bet",0))))

func launch_guidance() -> String:
	if not staging.assisted: return "Hold brake/clutch; release on green"
	if car.has_transbrake: return "Hold gas + transbrake; release transbrake on green"
	if car.control_mode == "automatic": return "Hold gas on green / automatic shifts"
	if car.control_mode == "hpattern": return "Hold clutch + gas; select 1; release clutch on green"
	return "Hold gas; tap + when the shift light turns green"

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		controls.clear()
		gamepad.reset_navigation()
		car.cancel_shift_request()
		dragging_wager = ""
		# Desktop races keep running while unfocused; mobile app suspension still pauses safely.
		if OS.has_feature("mobile") and screen == "race" and input_override.x < 0.0:
			paused_race = true
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if finish_hold_left > 0.0 and screen == "race": complete_race()
		request_quit()

func stop_presentation_audio() -> void:
	if is_instance_valid(sound):
		sound.shutdown()
		sound.stop()
		sound.playback = null
		sound.stream = null

func request_quit() -> void:
	if shutting_down: return
	shutting_down = true
	profile.save()
	controls.clear()
	set_process(false); set_physics_process(false)
	stop_presentation_audio()
	# Let the native audio callback retire before scene and device destruction.
	await get_tree().create_timer(.12).timeout
	get_tree().quit()

func gas_input() -> float:
	if input_override.x >= 0.0: return clampf(input_override.x, 0.0, 1.0)
	return controls.value("gas")

func _exit_tree() -> void:
	stop_presentation_audio()
	# Release shared GPU resources while the rendering server is still alive.
	VehicleAppearance._textures.clear()

func brake_input() -> float:
	if input_override.y >= 0.0: return clampf(input_override.y, 0.0, 1.0)
	return controls.value("brake")

func clutch_input() -> float:
	if car.has_converter or car.transmission_kind == "dct": return 0.0
	return 0.0 if input_override.x >= 0.0 else controls.value("clutch")

func transbrake_input() -> bool:
	return car.has_transbrake and controls.value("transbrake") > 0.0

func nitrous_input() -> bool:
	return nitrous_lock_reason()=="" and input_override.x<0.0 and controls.value("nitrous")>0.0

func nitrous_lock_reason() -> String:
	if screen=="race" and not practice_mode and active_contract.get("rule","")=="motor_only": return "MOTOR ONLY"
	if not car.has_nitrous(): return "NO KIT"
	return ""

func set_race_paused(value: bool) -> void:
	menu_dirty = true
	car.cancel_shift_request()
	paused_race = value
	controls.clear()
	dragging_wager = ""

func _process(dt: float) -> void:
	gamepad.tick(self,dt)
	show_save_recovery()
	sync_menu_size()
	clock += dt
	glass.reduced_motion = profile.reduced_motion
	if glass.animate(dt,buttons): menu_dirty = true
	if dock != null and dock.animate(dt): menu_dirty = true
	if menu != null: menu.dealer.age = 1.0 if profile.reduced_motion else minf(1.0,menu.dealer.age+dt*6.0)
	var had_toast := toast_left > 0
	toast_left = maxf(0.0, toast_left - dt)
	var key := str([screen,tab,menu.hub.categories,workshop.mode,menu.hub.dyno_open,
		menu.dealer.class_picker,menu.dealer.details,menu.customize.category,career_board.active,career_board.picker])
	if key != navigation_key:
		navigation_key = key
		navigation_age = 0
		preview_states.clear()
		menu_dirty = true
	navigation_age = 1.0 if glass.reduced_motion else minf(1,navigation_age+dt/maxf(.01,glass.PALETTE.motion_seconds))
	if screen == "garage":
		normalize_wager()
		if RaceAI.advance_estimates(): menu_dirty = true
		if PerformanceClasses.advance(): menu_dirty = true
	if not paused_race:
		shift_flash = maxf(0.0, shift_flash - dt)
		shift_notice_left = maxf(0.0,shift_notice_left-dt)
		if screen == "race":
			feedback.set_quality(profile.effects_quality); rival_feedback.set_quality(profile.effects_quality)
			feedback.update(dt,car,false,GameCatalog.spec(profile.vehicle_id),race_origins()[0],profile.reduced_motion,TrackPresentation.pixels_per_meter(is_portrait()))
			rival_feedback.update(dt,rival,false,GameCatalog.spec(str(active_contract.get("model","kaze"))),race_origins()[1],profile.reduced_motion,TrackPresentation.pixels_per_meter(is_portrait()))
	if is_instance_valid(sound):
		sound.pump()
	if tuning!=null and ((screen=="garage" and tab=="tuning") or screen=="practice_results"): tuning.update()
	if workshop != null and screen == "garage":
		var testing := workshop.lab != null and not workshop.lab.done
		workshop.update()
		if testing: menu_dirty = true
	if screen == "race" or menu_dirty or had_toast or navigation_age < 1 or (tab == "dealer" and menu.dealer.age < 1) or (workshop.lab != null and not workshop.lab.done):
		queue_redraw()
		menu_dirty = false

func _physics_process(dt: float) -> void:
	if screen != "race":
		car.step(dt,0.0,0.0,1.0)
		sync_race_audio()
		return
	if paused_race:
		sync_race_audio()
		return
	if finish_hold_left > 0.0:
		var previous_finish_rival := rival.distance
		car.step(dt,0.0)
		if not practice_mode: step_rival(dt)
		if not practice_mode and rival_finish == 0.0 and rival.distance >= active_distance:
			rival_finish = rival.elapsed-dt+dt*(active_distance-previous_finish_rival)/maxf(0.001,rival.distance-previous_finish_rival)
		finish_hold_left = maxf(0.0,finish_hold_left-dt)
		sync_race_audio()
		if finish_hold_left == 0.0: complete_race()
		return
	if countdown > 0.0:
		var staged_dt := minf(dt,countdown)
		var before := car.distance
		car.staging_motion = not staging.assisted
		car.step(staged_dt,gas_input(),brake_input(),clutch_input(),nitrous_input(),transbrake_input())
		staging.observe(0,before,car.distance,-countdown,staged_dt)
		if not staging.assisted and not manual_tree_armed:
			manual_tree_armed=staging.beam(0) or staging.red_light
			if not manual_tree_armed:
				sync_race_audio(); return
		if staging.released[0]: player_reaction = staging.reactions[0]
		if not practice_mode: rival.step(staged_dt,stage_pedal(rival),0.0,1.0)
		countdown = maxf(0,countdown-staged_dt)
		dt -= staged_dt
		if countdown <= 0.0:
			car.running = true; car.staging_motion = false
			rival.running = not practice_mode
			feedback.start_flash = 1.0
		sync_race_audio()
		if dt <= .00000001: return
	car.staging_motion = false
	var previous_speed := car.speed
	var previous_distance := car.distance
	var previous_time := car.elapsed
	var previous_rpm := car.rpm
	var previous_rival := rival.distance
	car.step(dt, gas_input(), brake_input(), clutch_input(), nitrous_input(), transbrake_input())
	staging.observe(0,previous_distance,car.distance,car.elapsed-dt,dt)
	if staging.released[0]: player_reaction = staging.reactions[0]
	run_telemetry.observe(car,previous_distance,previous_speed,previous_time,dt,staging,0,previous_rpm)
	if not practice_mode: step_rival(dt)
	for marker in [18.288,100.0,201.168,304.8,402.336]:
		if car.distance >= marker and not split_times.has(marker):
			split_times[marker] = car.elapsed-dt+dt*(marker-previous_distance)/maxf(0.001,car.distance-previous_distance)
	if rival.distance >= active_distance and rival_finish == 0.0:
		rival_finish = rival.elapsed-dt+dt*(active_distance-previous_rival)/maxf(0.001,rival.distance-previous_rival)
	if seen_shift_request != car.shift_request_serial:
		seen_shift_request = car.shift_request_serial
		if car.shift_request_status != "SHIFT ACCEPTED":
			shift_notice = car.shift_request_status
			shift_notice_left = 0.45
		else: shift_notice_left = 0.0
	if car.shift_serial != audio_shift_serial:
		audio_shift_serial = car.shift_serial
		shift_flash = 1.0
		if car.shift_message == "PERFECT SHIFT": perfect_shifts += 1
	if car.distance >= active_distance:
		player_finish = maxf(dt,car.elapsed-dt+dt*(active_distance-previous_distance)/maxf(0.001,car.distance-previous_distance))
		var fraction := clampf((active_distance-previous_distance)/maxf(0.001,car.distance-previous_distance),0.0,1.0)
		finish_speed = lerpf(previous_speed,car.speed,fraction)*Drivetrain.MPH_PER_MPS
		finish_hold_left = 0.55
		feedback.finish_flash = 1.0
		car.cancel_shift_request()
		controls.clear()
	if car.elapsed > 90.0 and screen == "race":
		show_toast("Run ended / stake forfeited")
		go_garage()
	sync_race_audio()

func sync_race_audio() -> void:
	sound.update_vehicle(car,paused_race)
	sound.loops.quality = profile.effects_quality
	sound.update_opponent(rival,rival.distance-car.distance,screen=="race" and not practice_mode,paused_race,profile.effects_quality)
	sound.atmosphere.set_state(staging,countdown,screen == "race",paused_race,sound.enabled,car.speed,finish_hold_left > 0,not staging.red_light and (rival_finish<=0 or player_finish<=rival_finish))

func show_toast(message: String,confirmed: bool = false) -> void:
	toast = message
	toast_confirmed = confirmed
	toast_left = 1.7
	menu_dirty = true

func toast_reveal() -> float:
	if profile.reduced_motion: return 1.0
	return minf(1-pow(clampf((toast_left-1.48)/.22,0,1),3),clampf(toast_left/.18,0,1))

func start_race() -> void:
	if screen=="practice_results": screen="garage"
	menu_dirty = true
	if screen=="race": return
	var contract := current_contract()
	var reason:=Championships.eligibility(profile,contract)
	if reason!="": show_toast(reason); return
	var stake := clampi(wager,0,mini(profile.credits,int(contract.max_bet)))
	wager = stake
	if not profile.begin_wager(stake,contract):
		show_toast(profile.save_error if profile.save_error!="" else "Race entry could not be saved / check your wager")
		return
	toast_left = 0
	practice_mode=false; manual_tree_armed=true
	active_contract = RaceAI.live_contract(contract,profile.races,selected_opponent)
	active_distance = float(contract.distance)
	active_contract.distance = active_distance
	active_stake = stake
	refresh_car()
	car.reset()
	RaceAI.configure(rival,active_contract)
	staging.reset(car,rival)
	run_telemetry.begin(car,active_distance)
	rival_telemetry.begin(rival,active_distance)
	rival_shift_delay = 0.0
	audio_shift_serial = car.shift_serial
	player_reaction = -1.0
	countdown = 3.0
	player_finish = 0.0
	rival_finish = 0.0
	rival_trap_speed = 0.0
	perfect_shifts = 0
	finish_speed = 0.0
	finish_hold_left = 0.0
	shift_notice_left = 0.0
	shift_flash = 0.0
	seen_shift_request = car.shift_request_serial
	feedback.reset(car)
	rival_feedback.reset(rival)
	split_times.clear()
	paused_race = false
	controls.clear()
	screen = "race"

func start_practice(length: float = 402.336) -> void:
	if screen=="race" or not profile.pending_wager.is_empty(): return
	practice_mode=true; active_distance=201.168 if length<300 else 402.336; active_stake=0
	tuning.length=active_distance
	active_contract={"model":profile.vehicle_id,"distance":active_distance,"name":"Test track"}
	refresh_car(); car.reset(); rival.reset(); rival.running=false
	staging.reset(car,rival); countdown=3; player_finish=0; rival_finish=0; finish_speed=0; finish_hold_left=0
	player_reaction=-1; shift_notice_left=0; shift_flash=0; paused_race=false; toast_left=0
	manual_tree_armed=staging.assisted
	if not staging.assisted: car.distance=-.30; staging.distances[0]=-.30
	feedback.reset(car); rival_feedback.reset(rival); run_telemetry.begin(car,active_distance)
	audio_shift_serial=car.shift_serial; seen_shift_request=car.shift_request_serial
	split_times.clear(); controls.clear(); screen="race"; menu_dirty=true

func complete_race() -> void:
	if practice_mode:
		if screen!="race" or player_finish<=0: return
		tuning.receive_run(run_telemetry); finish_hold_left=0; car.running=false; rival.running=false
		car.cancel_shift_request(); controls.clear(); screen="practice_results"; menu_dirty=true; return
	if screen != "race" or player_finish <= 0 or not is_finite(player_finish) or profile.pending_wager.is_empty(): return
	menu_dirty = true
	finish_hold_left = 0.0
	if rival_finish == 0.0:
		finish_rival_simulation()
	result_win = not staging.red_light and (rival_finish == 0.0 or player_finish <= rival_finish)
	previous_level = profile.level()
	var event_id := str(active_contract.get("id",""))
	var elapsed := staging.elapsed(player_finish)
	var quarter_record := active_distance>400 and active_distance<500 and (profile.best==0 or player_finish<profile.best)
	var event_record: Dictionary = profile.event_records.get(event_id,{})
	result_improvement=maxf(0.0,float(event_record.get("last_et",elapsed))-elapsed) if not staging.red_light else 0.0
	result_record = not staging.red_light and (quarter_record or (event_id!="" and elapsed<float(event_record.get("best_et",INF))))
	if not staging.red_light and quarter_record: profile.best=player_finish
	var payout:=profile.award_race(active_contract,result_win,staging.red_light,staging.elapsed(player_finish),player_reaction,finish_speed,int(active_contract.get("legacy_career",event_index)),int(active_contract.get("legacy_rival",selected_opponent)))
	if payout.is_empty(): return
	result_bonus=int(payout.bonus); result_base_pay=int(payout.base)-result_bonus; result_bet_return=int(payout.bet_return); result_reward=int(payout.reward); result_xp=int(payout.xp)
	if finish_speed == 0.0: finish_speed = car.speed*Drivetrain.MPH_PER_MPS
	car.running = false
	screen = "results"
	car.cancel_shift_request()
	controls.clear()

func go_garage() -> void:
	menu_dirty = true
	tab = "garage"
	if screen == "race" and finish_hold_left > 0.0: complete_race()
	if screen == "race": profile.forfeit_wager()
	screen = "garage"
	practice_mode=false
	finish_hold_left = 0.0
	car.reset()
	controls.clear()
	dragging_wager = ""
	paused_race = false

func paddle(direction: int) -> void:
	if screen != "race" or paused_race or finish_hold_left > 0.0: return
	glass.press("up" if direction>0 else "down")
	var status := car.request_shift(direction,clutch_input())
	seen_shift_request = car.shift_request_serial
	if status == "SHIFT ACCEPTED":
		shift_flash = 1.0
		shift_notice_left = 0.0
	else:
		shift_notice = status
		shift_notice_left = 0.45

func handle_key_input(event: InputEventKey) -> void:
	menu_dirty = true
	if input_override.x >= 0.0: return
	if screen == "race" and not paused_race:
		controls.handle_key(event)
	if not event.pressed or event.echo:
		return
	var code := RaceControls.key_code(event)
	if code==KEY_F7 and screen=="garage" and audio_lab!=null:
		audio_lab.open_lab(); return
	if screen == "garage" and code == KEY_TAB and event.ctrl_pressed and not menu.hub.dyno_open:
		var sections := ["garage","performance","style","dealer","races","driver"]
		var current := maxi(0,sections.find(tab))
		action("tab_"+str(sections[posmod(current+(-1 if event.shift_pressed else 1),sections.size())])); return
	if screen == "garage" and tab == "owned" and code in [KEY_LEFT,KEY_RIGHT]:
		menu.hub.browse_owned(-1 if code == KEY_LEFT else 1); return
	if screen == "garage" and tab == "dealer" and code in [KEY_HOME,KEY_END]:
		if menu.dealer.details: return
		menu.dealer.select_edge(code == KEY_END); return
	if screen != "race" and code in [KEY_ENTER,KEY_SPACE] and glass.focused != "":
		for item in buttons:
			if item.id == glass.focused and not item.get("disabled",false): action(str(item.id)); return
	if car.control_mode == "hpattern" and screen == "race":
		if code >= KEY_0 and code <= KEY_9: manual_gear(int(code-KEY_0)); return
		if code == KEY_N: manual_gear(0); return
	if screen == "garage" and tab == "dealer" and code in [KEY_LEFT,KEY_RIGHT]:
		if menu.dealer.details: return
		menu.dealer.navigate(-1 if code == KEY_LEFT else 1)
		return
	if code==KEY_ESCAPE and screen=="garage" and tab=="races" and career_board.active:
		if career_board.picker: go_garage()
		else: career_board.action("cb_back")
		return
	if code==KEY_ESCAPE and ((screen=="garage" and tab=="tuning") or screen=="practice_results"):
		tuning.action("tt_back"); return
	if code == KEY_ESCAPE and screen == "garage" and tab == "dealer":
		if menu.dealer.details: menu.dealer.details=false
		elif not menu.dealer.class_picker: menu.dealer.show_classes()
		else: go_garage()
		return
	match code:
		KEY_E, KEY_RIGHT: paddle(1)
		KEY_Q, KEY_LEFT: paddle(-1)
		KEY_ESCAPE:
			if screen == "race":
				set_race_paused(not paused_race)
			else:
				if not menu.hub.back(): go_garage()
		KEY_P:
			if screen == "race": set_race_paused(not paused_race)
		KEY_R:
			if screen == "results": start_race()
			elif screen == "practice_results": start_practice(tuning.length)
		KEY_ENTER:
			if screen == "results" or (screen == "garage" and tab == "races"): start_race()
			elif screen == "garage" and tab == "garage": tab = "races"
		KEY_M: action("sound")
		KEY_F3:
			if OS.is_debug_build(): debug_physics = not debug_physics
		KEY_F4: show_shift_guide = not show_shift_guide
		KEY_F6:
			if OS.has_feature("editor") or OS.is_debug_build():
				glass.legacy = not glass.legacy; glass.backdrop = null
				show_toast("Original surface comparison" if glass.legacy else "Liquid Glass")
		KEY_TAB:
			if screen != "race" and not buttons.is_empty():
				var ids: Array = []
				for item in buttons:
					if not item.get("disabled",false) and not ids.has(item.id): ids.append(item.id)
				if not ids.is_empty():
					var current := ids.find(glass.focused)
					glass.focused = str(ids[(ids.size()-1 if event.shift_pressed else 0) if current < 0 else posmod(current+(-1 if event.shift_pressed else 1),ids.size())])

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		gamepad.handle(self,event)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch:
		gamepad.active = false
	if audio_lab!=null and audio_lab.visible: return
	if tuning!=null and tuning.handle_input(event): return
	menu_dirty = true
	if input_override.x >= 0.0: return
	if native_workshop!=null and native_workshop.handle_scroll_touch(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		if native_workshop!=null and native_workshop.editing_catalog(event): return
		handle_key_input(event)
		if native_workshop!=null and native_workshop.visible and event.pressed and (event.keycode in [KEY_TAB,KEY_ENTER,KEY_SPACE] or event.physical_keycode in [KEY_TAB,KEY_ENTER,KEY_SPACE]):
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_XBUTTON1 and event.pressed:
		var back := InputEventKey.new(); back.keycode = KEY_ESCAPE; back.pressed = true
		handle_key_input(back); return
	if event is InputEventMouseMotion and dragging_wager.begins_with("mouse_"):
		set_wager_from_x(to_local(event.position).x)
	if event is InputEventScreenDrag and dragging_wager == "touch_%d" % event.index:
		set_wager_from_x(to_local(event.position).x)
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		if event.pressed:
			activate_at(to_local(event.position), "mouse_%d" % event.button_index, event.button_index == MOUSE_BUTTON_LEFT)
		else:
			controls.release("mouse_%d" % event.button_index)
			if dragging_wager == "mouse_%d" % event.button_index: dragging_wager = ""
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			activate_at(to_local(event.position), "touch_%d" % event.index)
		else:
			controls.release("touch_%d" % event.index)
			if dragging_wager == "touch_%d" % event.index: dragging_wager = ""

func activate_at(pos: Vector2, pointer: String, allow_menu: bool = true) -> void:
	for i in range(buttons.size() - 1, -1, -1):
		var b := buttons[i]
		if b.rect.has_point(pos):
			if b.get("disabled",false): return
			glass.press(str(b.id))
			if b.id=="tt_seek":
				tuning.drag_pointer=pointer; tuning.seek(pos.x); return
			if b.id == "bet_slider":
				dragging_wager = pointer
				set_wager_from_x(pos.x)
				return
			if RaceControls.HOLD_ACTIONS.has(b.id) and screen == "race" and not paused_race:
				controls.hold(pointer, b.id)
			elif allow_menu or (screen == "race" and b.id in ["up", "down"]):
				if b.has("native_control"):
					b.native_control.pressed.emit()
					get_viewport().set_input_as_handled()
				else: action(b.id)
			return

func action(id: String) -> void:
	if id=="garage_upgrades": id="tab_performance"
	if id=="garage_customize": id="tab_style"
	if native_workshop!=null and native_workshop.catalog_action(id):
		menu_dirty=true
		glass.focused=""
		return
	if id=="open_championships": tab="races"; career_board.open(); return
	if id.begins_with("cb_"): career_board.action(id); return
	if id=="open_tuning": tuning.open(); return
	if id.begins_with("tt_"): tuning.action(id); return
	if id == "race_units":
		profile.metric_speed = false; profile.save(); menu_dirty = true; return
	if id == "race_guide":
		show_shift_guide = not show_shift_guide; menu_dirty = true; return
	if id=="sound_preview" and screen=="garage":
		audio_lab.open_lab(menu.hub.studio.candidate(),true); return
	menu_dirty = true
	glass.focused = ""
	if id.begins_with("tab_"): dragging_wager = ""
	if id.begins_with("tab_") and tab == "performance" and not menu.hub.categories:
		menu.hub.studio.remember(menu.hub.selected)
	if id == "bet_clear": wager = 0; dragging_wager = ""; return
	if id == "reduced_motion":
		profile.reduced_motion = not profile.reduced_motion; glass.reduced_motion = profile.reduced_motion; profile.save(); return
	if id == "staging_assist":
		if screen == "race" and countdown > 0:
			staging.assisted = not staging.assisted
			if practice_mode and staging.assisted and car.distance<0: car.distance=0; staging.distances[0]=0; manual_tree_armed=true
		return
	if id == "effects_quality":
		profile.effects_quality = (profile.effects_quality+1)%3
		feedback.set_quality(profile.effects_quality); rival_feedback.set_quality(profile.effects_quality)
		profile.save()
		return
	if menu != null and menu.customize.action(id): return
	if menu != null and menu.dealer.action(id): return
	if menu != null and menu.hub.action(id): return
	if workshop != null and workshop.action(id): return
	if id.begins_with("manual_"):
		manual_gear(int(id.trim_prefix("manual_")))
		return
	if id.begins_with("tab_"):
		tab = id.trim_prefix("tab_")
		if tab=="dealer": menu.dealer.open()
		if tab=="races": career_board.open()
		if tab == "performance": menu.hub.categories = true
	elif id.begins_with("part_"):
		selected_part = int(id.trim_prefix("part_"))
		workshop.slot_index = 0
		workshop.parts_page = 0
	elif id.begins_with("install_"):
		var pieces := id.split("_")
		install_part(int(pieces[1]),int(pieces[2]))
	elif id.begins_with("upgrade_"):
		install_part(int(id.trim_prefix("upgrade_")))
	elif id.begins_with("paint_"):
		profile.paint = int(id.trim_prefix("paint_"))
		profile.save()
	elif id.begins_with("wheel_"):
		profile.wheels = int(id.trim_prefix("wheel_"))
		profile.save()
	elif id.begins_with("dealer_"):
		dealer_index = int(id.trim_prefix("dealer_"))
	else:
		match id:
			"race", "retry": start_race()
			"race_menu": tab = "races"; career_board.open()
			"next_rival":
				go_garage()
				tab = "races"
				selected_opponent = mini(4,int(profile.career_wins[event_index]))
				if career_board.active:
					career_board.select_next(result_win and result_bonus>0 and bool(active_contract.get("boss",false)))
			"results_upgrades": go_garage(); menu.hub.action("hub_upgrades")
			"garage": go_garage()
			"up": paddle(1)
			"down": paddle(-1)
			"pause": set_race_paused(true)
			"resume": set_race_paused(false)
			"bet_less": wager = maxi(0,wager-50)
			"bet_more": wager = mini(mini(profile.credits,int(current_contract().get("max_bet",0))),wager+50)
			"buy_car":
				var id_to_buy: String = GameCatalog.CAR_IDS[dealer_index]
				if profile.buy_vehicle(id_to_buy):
					refresh_car()
					show_toast(GameCatalog.spec(id_to_buy).name+" / added to garage",true)
				else: show_toast("Not enough credits, or vehicle already owned")
			"drive_car":
				if profile.select_vehicle(GameCatalog.CAR_IDS[dealer_index]):
					refresh_car()
					show_toast("Now driving "+GameCatalog.spec(profile.vehicle_id).name)
			"cycle_car":
				var owned: Array = []
				for candidate in GameCatalog.CAR_IDS:
					if profile.garage.has(candidate): owned.append(candidate)
				profile.select_vehicle(owned[(owned.find(profile.vehicle_id)+1)%owned.size()])
				refresh_car()
			"sound":
				profile.muted = not profile.muted
				sound.enabled = not profile.muted
				profile.save()
			"telemetry": debug_physics = not debug_physics

func fit_text(value: String,x: float,y: float,width: float,size: int=18,color: Color=INK) -> void:
	while size>11 and font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width: size-=1
	while value.length()>2 and font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width: value=value.left(value.length()-2)+"…"
	text_at(value,x,y,size,color)

func text_at(value: String, x: float, y: float, size: int = 18, color: Color = INK, use_mono: bool = false) -> void:
	if color in [INK,Color("f2eee4")]: color = glass.PALETTE.ink
	elif color == MUTED: color = glass.PALETTE.muted
	elif color == ORANGE: color = glass.PALETTE.orange
	elif color == GREEN: color = glass.PALETTE.green
	draw_string(mono if use_mono else (display_font if size >= 26 else font), Vector2(x, y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func box(rect: Rect2, fill: Color = PANEL, border: Color = EDGE) -> void:
	glass.surface(self,rect,fill,border,mini(22,roundi(rect.size.y*.38)))

func button(id: String, label: String, rect: Rect2, primary: bool = false, selected: bool = false) -> void:
	var enabled := action_enabled(id)
	var shown := glass.button(self,id,rect,primary,selected,enabled)
	var size := 20 if is_portrait() else 15
	while size > 11 and font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > rect.size.x-20: size -= 1
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text_at(label, shown.position.x + (shown.size.x - w) * 0.5, shown.position.y + shown.size.y * 0.5 + size*.34, size, Color("697482") if not enabled else INK)
	buttons.append({"id":id,"rect":Rect2(rect.position+ui_offset,rect.size),"disabled":not enabled})

func begin_sheet() -> void:
	ui_offset = Vector2(0,0 if glass.reduced_motion else 8*pow(1-glass.sheet_age,3))
	draw_set_transform(ui_offset)

func end_sheet() -> void:
	ui_offset = Vector2.ZERO; draw_set_transform(Vector2.ZERO)

func missing_credits(price: int) -> String:
	return "Need $%d more" % maxi(0,price-profile.credits)

func action_enabled(id: String) -> bool:
	if id.begins_with("tt_"): return tuning.enabled(id)
	if id == "hub_hp": return not menu.hub.show_hp or menu.hub.show_torque
	if id == "hub_torque": return not menu.hub.show_torque or menu.hub.show_hp
	if id == "lab_run": return workshop.lab == null or workshop.lab.done
	if id == "tune_reset": return profile.hardware.tune.has("shift_rpms")
	if id.begins_with("preset_"):
		for key in GarageHub.TUNE_KEYS.get(menu.hub.selected,[]):
			if workshop.tuning_enabled(key) and key not in ["ratio","shift"]: return true
		return false
	if id == "bet_clear": return wager > 0
	if id == "custom_discard": return menu.customize.has_preview()
	if id == "custom_zoom_in": return menu.customize.zoom_step<2
	if id == "custom_zoom_out": return menu.customize.zoom_step>-1
	if id.begins_with("shop_class_"): return not menu.dealer.class_ids(id.trim_prefix("shop_class_")).is_empty()
	if id in ["race","retry"]:
		if profile.save_blocked: return false
		return Championships.eligibility(profile,current_contract())==""
	if id == "bet_less": return wager > 0
	if id == "bet_more": return wager < mini(profile.credits,int(current_contract().get("max_bet",0)))
	if id.begins_with("install_"):
		var pieces := id.split("_"); var index := int(pieces[1]); var stage := int(pieces[2])
		var quote:=profile.upgrade_quote(index,stage)
		return quote.reason=="" and not quote.equipped and profile.credits>=int(quote.cost)
	if id == "hw_buy":
		var d := workshop.part_comparison(); var owned := workshop.selected_hardware == "" or VehicleParts.is_owned(profile.hardware,workshop.selected_hardware)
		return str(profile.hardware.parts.get(workshop.current_slot(),"")) != workshop.selected_hardware and d.reason == "" and (owned or profile.credits >= int(d.part.get("cost",0)))
	if id == "hub_equip": return menu.hub.owned_selection != profile.vehicle_id
	if id in ["buy_car","drive_car"]:
		var vehicle: String = GameCatalog.CAR_IDS[dealer_index]; var spec := GameCatalog.spec(vehicle)
		if id == "drive_car": return profile.garage.has(vehicle) and vehicle != profile.vehicle_id
		return not profile.garage.has(vehicle) and profile.credits >= int(spec.price) and profile.level() >= int(spec.get("unlock_level",1))
	if id == "tx_buy":
		var spec := TransmissionCatalog.spec(workshop.selected_trans)
		return workshop.selected_trans != str(profile.hardware.transmission) and TransmissionCatalog.compatible(workshop.selected_trans,profile.vehicle_id) and (profile.hardware.owned_transmissions.has(workshop.selected_trans) or (profile.transmission_unlock_stage() >= int(spec.stage) and profile.credits >= int(spec.cost)))
	if id == "tx_prev": return workshop.page > 0
	if id == "tx_next": return (workshop.page+1)*4 < workshop.available_transmissions().size()
	if id == "hw_prev": return workshop.parts_page > 0
	if id == "hw_next":
		var count := 1
		for part in VehicleParts.PARTS.values():
			if part.slot == workshop.current_slot(): count += 1
		return (workshop.parts_page+1)*3 < count
	if id == "hub_owned_prev": return menu.hub.owned_page > 0
	if id == "hub_owned_next": return (menu.hub.owned_page+1)*4 < menu.hub.owned_ids().size()
	if id == "shop_prev": return menu.dealer.page > 0
	if id == "shop_next": return (menu.dealer.page+1)*4 < menu.dealer.filtered().size()
	if id in ["shop_car_prev","shop_car_next"]: return menu.dealer.filtered().size() > 1
	if id == "tune_gear_prev": return workshop.gear_index > 0
	if id == "tune_gear_next": return workshop.gear_index < car.gear_ratios.size()-1
	if id.begins_with("tune_plus_") or id.begins_with("tune_minus_"):
		var key:=id.trim_prefix("tune_plus_").trim_prefix("tune_minus_")
		if not workshop.tuning_enabled(key): return false
		var plus:=id.begins_with("tune_plus_")
		if TuningSetup.EXTRA.has(key):
			var setting: Array=TuningSetup.EXTRA[key]
			var value := workshop.tune_default(key)
			return value<float(setting[2])-.0001 if plus else value>float(setting[1])+.0001
		if key=="shift" and workshop.gear_index>=car.gear_ratios.size()-1: return false
		if key=="launch_rpm": return car.launch_rpm<6000 if plus else car.launch_rpm>2200
		if key=="firmness": return car.shift_firmness<1+int(profile.stages[4])*.1-.0001 if plus else car.shift_firmness>.5001
		if key=="final_drive": return car.final_drive<5.5-.0001 if plus else car.final_drive>2.0+.0001
		if key=="boost": return car.boost_target(car.redline_rpm,1)<VehicleParts.boost_control_limit(profile.hardware,car.base_boost,car.turbo_stage)-.0001 if plus else car.boost_target(car.redline_rpm,1)>.0001
		if key=="redline": return car.redline_rpm<car._mechanical_redline-.01 if plus else car.redline_rpm>minf(6500,car._mechanical_redline-500)+.01
		return true
	if id == "custom_reset": return not profile.save_blocked and profile.pending_wager.is_empty()
	if id == "custom_install":
		if profile.save_blocked or not profile.pending_wager.is_empty(): return false
		var key: String = menu.customize.category; var choice: int = int(menu.customize.candidate.get(key,0))
		var cost := 0 if profile.owned_appearance.has(key+":"+str(choice)) else int(VehicleAppearance.PRICES[key][choice])
		return choice != int(profile.appearance_for(profile.vehicle_id)[key]) and VehicleAppearance.compatible(profile.vehicle_id,key,choice) and profile.credits >= cost
	return true

func draw_navigation() -> void:
	var hidden := (tuning!=null and tuning.name_edit!=null) or screen != "garage" or (tab == "performance" and not menu.hub.categories) or menu.hub.dyno_open
	dock.visible=not hidden
	if hidden: return
	var canvas:=get_window().content_scale_size
	var width:=minf(900.0,canvas.x-48) if canvas.x>1200 else minf(744.0,canvas.x-48)
	var short:=canvas.x>1200 and get_window().size.y<500
	var height:=100.0 if is_portrait() else (104.0 if short else 78.0)
	var y:=1160.0 if is_portrait() else (642.0 if short else 669.0)
	dock.present(Rect2((canvas.x-width)*.5,y,width,height),tab)

func _draw() -> void:
	ui_offset = Vector2.ZERO
	if screen != "race": race_hud.hide_status()
	if screen == "garage": normalize_wager()
	buttons.clear()
	var compact := is_portrait()
	dock.visible = false
	if native_workshop!=null: native_workshop.visible=native_workshop.supports()
	glass.background(self,Vector2(get_window().content_scale_size))
	if native_workshop!=null and native_workshop.supports():
		native_workshop.sync()
	elif screen=="garage" and tab=="races" and career_board.active:
		career_board.draw()
	elif screen=="practice_results" or (screen=="garage" and tab=="tuning"):
		tuning.draw()
	elif compact and mobile != null:
		mobile.draw()
	elif screen == "race":
		draw_race()
	elif screen == "results":
		draw_results()
	else:
		draw_garage()
	if toast_left > 0.0 and (native_workshop==null or not native_workshop.visible):
		var reveal := toast_reveal()
		var accent := GREEN if toast_confirmed else GlassPalette.BLUE
		var r := Rect2(24,52,552,48) if compact else Rect2(348,68,504,45)
		r.position.y -= 9*(1-reveal)
		glass.surface(self,r,Color(.06,.13,.18,.95*reveal),Color(accent,.52*reveal),14)
		draw_circle(r.position+Vector2(21,r.size.y*.5),3,Color(accent,reveal),true,-1,true)
		fit_text(toast,r.position.x+36,r.position.y+r.size.y*.5+6,r.size.x-52,18,Color(INK,reveal))
	if screen != "race" and navigation_age < 1 and not glass.reduced_motion:
		draw_rect(Rect2(Vector2.ZERO,Vector2(get_window().content_scale_size)),Color(BG,pow(1-navigation_age,3)*.23))
	if profile.save_error != "":
		text_at(profile.save_error, 36, 744, 14, ORANGE)

func draw_header() -> void:
	text_at("R /", 34, 48, 29, ORANGE)
	text_at("REDLINE", 98, 46, 23)
	text_at("STREET DIVISION", 230, 44, 11, MUTED, true)
	text_at("LV %02d" % profile.level(), 738, 43, 18, GREEN, true)
	text_at("$ %s" % str(profile.credits), 856, 43, 19, INK, true)
	button("sound", "SOUND OFF" if profile.muted else "SOUND ON", Rect2(1052, 20, 114, 37))

func draw_garage() -> void:
	menu.draw()







func draw_style() -> void:
	native_workshop.sync()

func draw_driver() -> void:
	button("reduced_motion","MOTION: REDUCED" if profile.reduced_motion else "MOTION: FULL",Rect2(738,103,210,48))
	button("effects_quality","EFFECTS: "+["LOW","MEDIUM","HIGH"][profile.effects_quality],Rect2(962,103,204,48))
	box(Rect2(36, 256, 1130, 399))
	text_at("STREET LICENSE", 65, 296, 13, ORANGE, true)
	text_at("DRIVER %02d" % profile.level(), 65, 360, 48)
	text_at("%d / %d XP" % [profile.xp, profile.next_level_xp()], 66, 403, 18, MUTED, true)
	draw_rect(Rect2(66, 429, 471, 7), EDGE)
	var base_xp := (profile.level() - 1) * (profile.level() - 1) * 150
	draw_rect(Rect2(66, 429, 471 * float(profile.xp - base_xp) / float(profile.next_level_xp() - base_xp), 7), ORANGE)
	text_at("Every finish earns credits and XP.", 66, 492, 19)
	text_at("LEVEL 03   MIDNIGHT CLUB", 66, 541, 15, GREEN if profile.level() >= 3 else MUTED, true)
	text_at("LEVEL 05   CITY FINALS", 66, 577, 15, GREEN if profile.level() >= 5 else MUTED, true)
	var values := [["RACES", str(profile.races)], ["WINS", str(profile.wins)], ["BEST 1/4 TOTAL", "--.---" if profile.best == 0.0 else "%.3f s" % profile.best]]
	for i in 3:
		text_at(values[i][0], 700, 332 + i * 100, 14, MUTED, true)
		text_at(values[i][1], 700, 378 + i * 100, 37, INK, true)
	var badges := [["FIRST WIN",profile.wins >= 1],["FIVE WINS",profile.wins >= 5],["CITY CHAMPION",int(profile.career_wins[2]) >= 5]]
	for i in badges.size(): text_at(str(badges[i][0]),66+i*345,624,16,GREEN if badges[i][1] else MUTED,true)

func draw_race_world() -> void:
	var camera := Vector2.ZERO if profile.reduced_motion else feedback.camera_offset
	draw_set_transform(camera)
	TrackPresentation.draw(self)
	draw_set_transform(Vector2.ZERO)
	var origins := race_origins()
	if not practice_mode:
		draw_car(origins[1]+camera,1.65,PAINTS[rival_paint_index()],rival.distance,2,rival_feedback.exhaust_glow > .18,str(active_contract.get("model","kaze")),rival.wheel_angle,rival.tire_radius,rival,rival_feedback.body_offset,rival_feedback.body_pitch,rival_appearance())
		if origins[1].x > 0 and origins[1].x < (370 if is_portrait() else 940): text_at("RIVAL",origins[1].x+70,origins[1].y+3,12,MUTED,true)
		draw_tire_smoke(rival_feedback)
	draw_car(origins[0]+camera,1.65,PAINTS[profile.paint],car.distance,profile.wheels,feedback.exhaust_glow > .18,profile.vehicle_id,car.wheel_angle,car.tire_radius,car,feedback.body_offset,feedback.body_pitch)
	draw_tire_smoke(feedback)


func draw_race() -> void:
	race_hud.draw(false)

func draw_tire_smoke(cloud: RaceFeedback) -> void:
	for particle in cloud.smoke:
		var age: float = clampf(particle.age/particle.life,0,1)
		var radius: float = (5.0+smoothstep(0,1,age)*36.0)*(.8+particle.strength*.4)
		var center: Vector2 = particle.position+(Vector2.ZERO if profile.reduced_motion else feedback.camera_offset)
		var night: bool = TrackPresentation.spec(race_track_index()).night
		var opacity: float = (.45+.55*sin(age*PI))*pow(1.0-age,.6)*particle.strength
		var extent:=Vector2(radius*float(particle.get("stretch",1.0)),radius)
		TrackPresentation.glow(self,Rect2(center-extent,extent*2),Color(.68,.73,.78,opacity*.48) if night else Color(.73,.71,.68,opacity*.44))

func draw_results() -> void:
	menu.draw_results()

func poly(points: Array, color: Color, origin: Vector2, scale_value: float) -> void:
	var transformed := PackedVector2Array()
	for point in points:
		transformed.append(origin + Vector2(point[0], point[1]) * scale_value)
	draw_colored_polygon(transformed, color)

func car_rect(origin: Vector2, scale_value: float, rect: Rect2, color: Color) -> void:
	draw_rect(Rect2(origin + rect.position * scale_value, rect.size * scale_value), color)

func draw_car(origin: Vector2, scale_value: float, paint: Color, _travel: float, rim: int, flame: bool = false, model: String = "", driven_angle: float = -1.0, _road_radius: float = 0.315, vehicle: Drivetrain = null, body_offset: Vector2 = Vector2.ZERO, pitch: float = 0.0, appearance_override: Dictionary = {}) -> void:
	var use_profile := model == "" or vehicle != null
	if model == "": model = profile.vehicle_id
	var paint_index := 2
	for i in PAINTS.size():
		if paint.is_equal_approx(PAINTS[i]): paint_index = i
	var look := profile.appearance_for(model) if use_profile else VehicleAppearance.normalize({},paint_index,rim)
	if not appearance_override.is_empty(): look = VehicleAppearance.normalize(appearance_override)
	var night: bool = screen == "race" and driven_angle >= 0 and TrackPresentation.spec(race_track_index()).night
	var reveal := 1.0
	if screen != "race" and scale_value >= 1.6 and not profile.reduced_motion:
		var key := str(origin)
		var choice := model+str(look)
		var state: Dictionary = preview_states.get(key,{"choice":"","start":-1.0})
		if state.choice != choice:
			state = {"choice":choice,"start":clock}
			preview_states[key] = state
		var remaining := pow(1-clampf((clock-float(state.start))/.24,0,1),3)
		origin += Vector2(13,3)*remaining
		reveal -= .25*remaining
		menu_dirty = menu_dirty or remaining > 0
	var braking: bool = brake_input() > .05 if vehicle == car else (vehicle != null and vehicle.braking_force > 50)
	var effects: RaceFeedback = null
	if screen=="race" and driven_angle>=0:
		effects = feedback if vehicle==car else (rival_feedback if vehicle==rival else null)
	VehicleRenderer.draw(self,origin,scale_value,model,look,vehicle,driven_angle >= 0,body_offset,pitch,flame,profile.effects_quality,night,braking,effects,reveal)

func refresh_car(plan: bool = true) -> void:
	menu_dirty = true
	if workshop != null: workshop.invalidate_test()
	car.configure_vehicle(GameCatalog.spec(profile.vehicle_id))
	car.configure(profile.stages)
	car.configure_build(profile.hardware,profile.vehicle_id,plan)

func install_part(index: int, tier: int = -1) -> void:
	if profile.upgrade(index,tier):
		refresh_car()
		show_toast("%s / tier %d installed" % [PART_NAMES[index],profile.stages[index]],true)
	else: show_toast("Already owned, or not enough credits")

func distance_label(value: float) -> String:
	if value < 150.0: return "328 FT"
	if value < 250.0: return "1/8 MILE"
	if value > 600.0: return "1/2 MILE"
	return "1/4 MILE"

func draw_workshop(rect: Rect2) -> void:
	if not glass.legacy and showroom_texture: LiquidGlass.draw_cover(self,showroom_texture,rect,Color(.83,.87,.93))
	elif workshop_texture: draw_texture_rect(workshop_texture,rect,false)
	else: draw_rect(rect,PANEL)
	if not glass.legacy:
		draw_rect(rect,Color("03101b20"))
		# Keep small configuration labels legible over the overhead softboxes.
		for band in 8:
			draw_rect(Rect2(rect.position+Vector2(0,band*6),Vector2(rect.size.x,6)),Color(.01,.025,.04,.50*(1.0-band/8.0)))
		var platform := Rect2(rect.position+Vector2(rect.size.x*.13,rect.size.y*.78),Vector2(rect.size.x*.74,rect.size.y*.14))
		draw_ellipse_platform(platform)
		VehicleRenderer.showroom_light(self,rect,profile.effects_quality)
	if glass.legacy: draw_rect(rect,EDGE,false,1)

func draw_ellipse_platform(rect: Rect2) -> void:
	var points := PackedVector2Array()
	for i in 65:
		var angle := TAU*i/64.0
		points.append(rect.get_center()+Vector2(cos(angle),sin(angle))*rect.size*.5)
	draw_colored_polygon(points,Color("02080dd9"))
	draw_polyline(points,Color(GlassPalette.BLUE,.13),1.0,true)
	draw_line(Vector2(rect.position.x+rect.size.x*.35,rect.end.y),Vector2(rect.position.x+rect.size.x*.65,rect.end.y),Color(ORANGE,.22),1,true)

func set_wager_from_x(x: float) -> void:
	var maximum := mini(profile.credits,int(current_contract().get("max_bet",0)))
	for item in buttons:
		if item.id != "bet_slider": continue
		var limits: Vector2 = item.get("range",Vector2(item.rect.position.x,item.rect.end.x))
		wager = clampi(roundi(clampf((x-limits.x)/maxf(1,limits.y-limits.x),0,1)*maximum/50.0)*50,0,maximum)
		return

func finish_rival_simulation() -> void:
	# Finish the same opponent simulation instantly for a complete time slip.
	var dt := 1.0/120.0
	if not rival.running: return
	while rival.distance < active_distance and rival.elapsed < 90.0:
		var previous := rival.distance
		step_rival(dt)
		if rival.distance >= active_distance:
			rival_finish = rival.elapsed-dt+dt*(active_distance-previous)/maxf(0.001,rival.distance-previous)

func stage_pedal(vehicle: Drivetrain) -> float:
	# AI operates the pedal through feedback; it never assigns engine RPM.
	return RaceAI.stage_pedal(vehicle,active_contract) if int(active_contract.get("driver_model",1))==2 else clampf(0.10+(3900.0-vehicle.rpm)/2500.0,0.0,1.0)

func step_rival(dt: float) -> void:
	var before := rival.distance
	var before_speed := rival.speed
	RaceAI.step(rival,active_contract,dt)
	staging.observe(1,before,rival.distance,rival.elapsed-dt,dt)
	rival_telemetry.observe(rival,before,before_speed,rival.elapsed-dt,dt,staging,1)
	if rival_finish == 0 and before < active_distance and rival.distance >= active_distance:
		var fraction := clampf((active_distance-before)/maxf(.000001,rival.distance-before),0,1)
		rival_finish = rival.elapsed-dt+dt*fraction
		rival_trap_speed = lerpf(before_speed,rival.speed,fraction)*Drivetrain.MPH_PER_MPS

func draw_telemetry() -> void:
	box(Rect2(30,94,475,236),Color(0.03,0.05,0.08,0.94),EDGE)
	var lines := ["RPM %5d / IDEAL %5d / GEAR %s" % [int(car.rpm),int(car.wheel_rpm(car.gear)),"N" if car.gear == 0 else str(car.gear)],"TORQUE %+6.1f lb-ft / LOAD %.2f" % [ImperialUnits.torque(car.engine_torque),car.engine_load],"CLUTCH %.2f / SLIP %+6.0f RPM" % [car.clutch_engagement,car.clutch_slip_rpm],"TIRE %+6.0f lbf / GRIP %6.0f lbf" % [ImperialUnits.force(car.traction_force),ImperialUnits.force(car.available_traction)],"WHEEL %.1f RAD/S / SLIP %+.2f" % [car.wheel_omega,car.slip_ratio],"ACCEL %+.2f ft/s² / BOOST %.1f PSI" % [ImperialUnits.feet(car.acceleration),PressureUnits.psi(car.boost)],"240 HZ / AUDIO UNDERRUNS %d" % sound.underruns]
	lines.append("TURBINE %5d / CONVERTER SLIP %+.2f" % [int(car.turbine_omega*Drivetrain.RPM_PER_RAD),car.converter_slip])
	lines.append("ENGINE %.0f C / TRANS %.0f C / WEAR %.3f" % [car.engine_temperature,car.transmission_temperature,car.component_wear])
	for i in lines.size(): text_at(lines[i],44,119+i*23,14,GREEN if i == 6 else INK,true)

func manual_gear(target: int) -> void:
	if screen != "race" or paused_race or finish_hold_left > 0.0: return
	var status := car.select_manual_gear(target,clutch_input())
	if status == "SHIFT ACCEPTED": shift_flash = 1.0; shift_notice_left = 0.0
	else: shift_notice = status; shift_notice_left = 0.7




