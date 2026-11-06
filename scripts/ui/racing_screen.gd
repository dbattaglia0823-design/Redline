class_name RacingScreen
extends CollectionScreen

var wager_slider: HSlider
var wager_label: Label
var preview_build: Drivetrain
var preview_key := ""

func racing_menu() -> bool:
	return game.screen=="results" or (game.screen=="garage" and game.tab=="races")

func supports() -> bool:
	return racing_menu() or super.supports()

func compact_landscape() -> bool:
	return (racing_menu() and not game.is_portrait() and game.get_window().size.y<500) or super.compact_landscape()

func button(parent: Node,id: String,title: String,primary: bool=false) -> Button:
	var control:=super.button(parent,id,title,primary)
	if racing_menu() and compact_landscape():
		control.custom_minimum_size=Vector2(90,90)
	return control

func state_key() -> String:
	if not racing_menu():
		return super.state_key()
	if game.screen=="results":
		return JSON.stringify([size,game.profile.races,game.active_contract,game.result_win,game.player_finish,game.rival_finish,game.result_reward])
	var board: CareerBoard=game.career_board
	var contract: Dictionary=game.current_contract()
	var estimate := {} if board.active and board.picker else estimates(contract)
	var reason := Championships.eligibility(game.profile,contract) if board.active and not board.picker else ""
	return JSON.stringify([size,game.tab,game.profile.vehicle_id,GameCatalog.engine_class(game.profile.vehicle_id,game.profile.hardware),game.profile.credits,game.profile.xp,game.profile.career_wins,game.profile.championship_wins,game.profile.legacy_class_access,board.active,board.picker,board.series,game.event_index,game.selected_opponent,contract,estimate,reason,game.profile.muted])

func publish_targets() -> void:
	if is_instance_valid(wager_slider) and wager_slider.is_visible_in_tree():
		wager_slider.set_value_no_signal(game.wager)
		wager_label.text="Wager  $%d / max $%d"%[game.wager,int(wager_slider.max_value)]
		for id in ["bet_less","bet_more","bet_clear"]:
			if targets.has(id): targets[id].disabled=not game.action_enabled(id)
	super.publish_targets()
	if is_instance_valid(wager_slider) and wager_slider.is_visible_in_tree() and wager_slider.size.x>20 and wager_slider.max_value>0:
		var rect:=Rect2(game.to_local(wager_slider.global_position),wager_slider.size)
		game.buttons.append({"id":"bet_slider","rect":rect,"range":Vector2(rect.position.x+8,rect.end.x-8),"native_owner":self})

func build() -> void:
	wager_slider=null
	wager_label=null
	if not racing_menu():
		super.build()
		return
	var margin := 24 if portrait or compact_landscape() else 36
	var height := 1125 if portrait else (614 if compact_landscape() else 638)
	if game.screen=="results": height=1235 if portrait else 710
	var body:=container(Rect2(margin,18,size.x-margin*2,height))
	body.add_theme_constant_override("separation",10)
	if not compact_landscape(): header(body)
	if game.screen=="results":
		results(body)
	elif game.career_board.active and game.career_board.picker:
		championship_picker(body)
	else:
		race_board(body)
	build_notice()

func add_label(parent: Node,value: String,points: int=20,color: Color=AutomotiveUI.INK,mono: bool=false) -> Label:
	var label:=AutomotiveUI.label(value,points,color,mono)
	parent.add_child(label)
	return label

func small_action(parent: Node,id: String,value: String) -> Button:
	var control:=button(parent,id,value)
	control.size_flags_horizontal=Control.SIZE_SHRINK_END
	return control

func championship_picker(body: VBoxContainer) -> void:
	var heading:=AutomotiveUI.row(body)
	var summary:=AutomotiveUI.column(heading,1)
	var crowned:=Championships.trophies(game.profile)
	var engine_class:=GameCatalog.engine_class(game.profile.vehicle_id,game.profile.hardware)
	add_label(summary,"REDLINE Champion" if crowned==6 else "Championship ladder",32)
	AutomotiveUI.section_mark(summary,"ENGINE %s   ·   %02d/%d RACES   ·   %d/6 TROPHIES"%[engine_class,Championships.completed(game.profile),Championships.TOTAL_RACES,crowned],"races",Championships.TROPHY)
	small_action(heading,"cb_open","Rival Challenges")
	var cards:=grid(body,2 if portrait else 3,12)
	for index in Championships.CLASSES.size():
		var letter: String=Championships.CLASSES[index]
		var wins:=Championships.wins(game.profile,letter)
		var reason:=Championships.unlock_reason(game.profile,letter)
		var state:="Locked" if reason!="" else ("Trophy earned" if wins==Championships.ROUNDS else "Available")
		var card:=AutomotiveUI.content_card(cards,194 if portrait else 172,game.career_board.series==letter)
		AutomotiveUI.class_decal(card,letter,index)
		bind(card,"cb_class_"+letter)
		var content: VBoxContainer=card.get_meta("content")
		var class_heading:=AutomotiveUI.row(content,4)
		add_label(class_heading,"CLASS "+letter,16,AutomotiveUI.ORANGE,true)
		class_heading.add_child(trophy_icon(Championships.TROPHY if wins==Championships.ROUNDS else Color("526476")))
		add_label(content,Championships.TITLES[index],22 if portrait else 26)
		add_label(content,state+"  /  %d of %d"%[wins,Championships.ROUNDS],18,AutomotiveUI.ORANGE if reason!="" else GlassPalette.GREEN)
		progress_bar(content,wins)
		add_label(content,"%d races remaining"%(Championships.ROUNDS-wins) if wins<Championships.ROUNDS else "Championship complete",16,AutomotiveUI.MUTED)
		var detail:=add_label(content,reason if reason!="" else "Boss bonus $%d"%Championships.BONUSES[index],16,AutomotiveUI.MUTED)
		detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		detail.text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING
		detail.custom_minimum_size.y=40
	add_label(body,"Rival Challenges pay for every clean finish and can be replayed freely.",18,AutomotiveUI.MUTED)

func trophy_icon(color: Color) -> Control:
	var icon:=AutomotiveUI.TechnicalIcon.new()
	icon.icon_key="trophy"
	icon.ink=color
	icon.icon_size=24
	icon.custom_minimum_size=Vector2(28,28)
	return icon

func progress_bar(parent: Node,wins: int,total: int=Championships.ROUNDS) -> void:
	var segments:=AutomotiveUI.row(parent,4)
	for index in total:
		var segment:=ColorRect.new()
		segment.color=GlassPalette.GREEN if index<wins else Color("294353")
		segment.custom_minimum_size.y=4
		segment.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		segment.mouse_filter=Control.MOUSE_FILTER_IGNORE
		segments.add_child(segment)

func estimates(contract: Dictionary) -> Dictionary:
	if contract.is_empty(): return {}
	var distance: float=contract.distance
	var player:=RaceAI.player_contract(game.profile)
	if game.career_board.active:
		player.driver_model=2
		player.nitrous=contract.get("rule","")!="motor_only" and game.car.has_nitrous()
	return {"rival":RaceAI.request_estimate(contract,distance),"player":RaceAI.request_estimate(player,distance)}

func opponent_build(contract: Dictionary) -> Drivetrain:
	var key:=JSON.stringify([contract.model,contract.stages,contract.get("hardware",{})])
	if key!=preview_key:
		preview_key=key
		preview_build=Drivetrain.new()
		RaceAI.configure(preview_build,contract)
	return preview_build

func race_board(body: VBoxContainer) -> void:
	var board: CareerBoard=game.career_board
	var contract: Dictionary=game.current_contract()
	if contract.is_empty(): return
	var heading:=AutomotiveUI.row(body)
	add_label(heading,"Rival Challenges" if board.series=="OPEN" else "Class "+board.series+" / "+Championships.TITLES[Championships.CLASSES.find(board.series)],29)
	small_action(heading,"cb_back","Championships")
	if board.series!="OPEN": small_action(heading,"cb_open","Rivals")
	var content: BoxContainer
	if portrait: content=AutomotiveUI.column(body,10)
	else: content=AutomotiveUI.row(body,18)
	content.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var choices:=grid(content,5 if portrait else (3 if compact_landscape() else 2),7)
	if not portrait:
		choices.custom_minimum_size.x=480 if compact_landscape() else 360
		choices.size_flags_horizontal=Control.SIZE_FILL
	championship_rivals(choices)
	var hero:=AutomotiveUI.column(content,7)
	hero.size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_label(hero,"RIVAL PROFILE  /  "+game.distance_label(float(contract.distance) if board.active else game.FINISH),14,AutomotiveUI.ORANGE,true)
	var description:=AutomotiveUI.row(hero)
	add_label(description,str(contract.name),29)
	if board.series!="OPEN":
		var wins:=Championships.wins(game.profile,board.series)
		var boss:=bool(contract.get("boss",false))
		add_label(hero,("CHAMPIONSHIP BOSS" if boss else "ROUND %02d / %d"%[int(contract.round)+1,Championships.ROUNDS])+"   ·   %d CLEARED"%wins,17,Championships.TROPHY if boss else AutomotiveUI.BLUE,true)
		if contract.get("rule","")=="motor_only":
			add_label(hero,"MOTOR ONLY / No nitrous or wagers",17,AutomotiveUI.ORANGE)
		if boss:
			var intro:=add_label(hero,str(contract.intro),17,Championships.TROPHY)
			intro.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			intro.custom_minimum_size.y=25
	var model: String=contract.model
	var car:=opponent_build(contract)
	var paint: int=int(contract.get("paint_index",(game.event_index+game.selected_opponent+3)%6))
	var art:=vehicle(hero,model,car,VehicleAppearance.normalize({},paint,0 if contract.has("id") else 2),196 if portrait else (126 if compact_landscape() else 142))
	art.size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_label(hero,str(GameCatalog.spec(model).name),23)
	var identity: String=contract.get("nickname",contract.get("build_label",""))
	add_label(hero,"%d hp / %.0f Nm%s"%[car.peak_horsepower(),GarageHub.peak_torque(car)," · "+identity if identity!="" else ""],18,AutomotiveUI.MUTED)
	var times:=estimates(contract)
	var comparison:="Measuring both builds…"
	if not times.rival.is_empty() and not times.player.is_empty():
		var gap: float=times.rival.time-times.player.time
		var difficulty:="Close match" if absf(gap)<.7 else ("Favorable" if gap>0 else "Challenging")
		comparison="%s   /   You %.2f s   /   Rival %.2f s"%[difficulty,times.player.time,times.rival.time]
	add_label(hero,comparison,19,AutomotiveUI.BLUE)
	if not compact_landscape() and not bool(contract.get("boss",false)) and not str(contract.get("tradeoff","")).is_empty():
		add_label(hero,str(contract.tradeoff),17,AutomotiveUI.MUTED)
	var distance: float=contract.distance
	var reward:=" %s   ·   $%d win   /   $%d finish"%[game.distance_label(distance),contract.purse,int(float(contract.purse)*.4)]
	if int(contract.get("completion_bonus",0))>0:
		reward+="   ·   "+("Bonus earned" if game.profile.career_claims.has(str(contract.id)) else "$%d first win bonus"%contract.completion_bonus)
	add_label(hero,reward,17,GlassPalette.GREEN)
	if board.series=="OPEN": add_label(hero,"Replay any rival · zero wager is free",16,AutomotiveUI.MUTED)
	var reason:=Championships.eligibility(game.profile,contract)
	if game.profile.save_blocked: reason="Restore progress to enter a race"
	if reason!="": add_label(body,reason,18,AutomotiveUI.ORANGE)
	var footer: BoxContainer=AutomotiveUI.column(body,8) if portrait else AutomotiveUI.row(body,18)
	wager_controls(footer,contract)
	var race:=button(footer,"race",("Challenge boss" if bool(contract.get("boss",false)) else "Race") if reason=="" else "Locked",true)
	if not portrait:
		race.custom_minimum_size.x=220
		race.size_flags_horizontal=Control.SIZE_SHRINK_END

func championship_rivals(parent: Node) -> void:
	var board: CareerBoard=game.career_board
	var options:=Championships.ids(board.series)
	for index in options.size():
		var contract:=Championships.event(str(options[index]))
		var state:=("$%d win"%int(contract.purse)) if board.series=="OPEN" else board.rung_state(contract)
		var boss:=bool(contract.get("boss",false))
		var card:=AutomotiveUI.content_card(parent,92 if portrait or compact_landscape() else 79,board.selected==contract.id)
		bind(card,"cb_rival_"+str(contract.id))
		var content: VBoxContainer=card.get_meta("content")
		add_label(content,"%02d · BOSS"%(index+1) if boss else "%02d"%(index+1),14,Championships.TROPHY if boss else AutomotiveUI.BLUE,true)
		add_label(content,str(contract.name).get_slice(" ",0) if portrait else str(contract.name),16 if portrait else 18)
		var ink:=GlassPalette.GREEN if state=="Cleared" else (AutomotiveUI.BLUE if state=="Next up" else AutomotiveUI.MUTED)
		add_label(content,state,14,ink)
		card.tooltip_text=str(contract.name)+" / "+state

func wager_controls(parent: Node,contract: Dictionary) -> void:
	if contract.get("rule","")=="motor_only": return
	var area: BoxContainer=AutomotiveUI.row(parent,10) if compact_landscape() else AutomotiveUI.column(parent,4)
	wager_label=add_label(area,"",17,AutomotiveUI.MUTED,true)
	if compact_landscape():
		wager_label.custom_minimum_size.x=236
		wager_label.size_flags_horizontal=Control.SIZE_FILL
		wager_label.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	var row:=AutomotiveUI.row(area,8)
	small_action(row,"bet_less","−")
	wager_slider=HSlider.new()
	wager_slider.max_value=mini(game.profile.credits,int(contract.get("max_bet",0)))
	wager_slider.custom_minimum_size.y=70 if portrait else (90 if compact_landscape() else 46)
	wager_slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	wager_slider.mouse_filter=Control.MOUSE_FILTER_IGNORE
	wager_slider.focus_mode=Control.FOCUS_NONE
	row.add_child(wager_slider)
	small_action(row,"bet_more","+")
	small_action(row,"bet_clear","Clear")

func results(body: VBoxContainer) -> void:
	var heading:=AutomotiveUI.row(body)
	var outcome:="Red light" if game.staging.red_light else ("You win" if game.result_win else str(game.active_contract.get("name","Rival"))+" wins")
	var boss_win: bool=game.result_win and bool(game.active_contract.get("boss",false))
	var trophy_earned: bool=boss_win and game.result_bonus>0
	if boss_win:
		heading.add_child(trophy_icon(Championships.TROPHY))
		outcome="REDLINE Champion" if trophy_earned and Championships.trophies(game.profile)==6 else ("Class %s Champion"%game.active_contract.series if trophy_earned else "Boss defeated")
	add_label(heading,outcome,27 if boss_win and portrait else 42,Championships.TROPHY if boss_win else (GlassPalette.GREEN if game.result_win else AutomotiveUI.ORANGE))
	var badge_text: String = "NEW PERSONAL BEST" if game.result_record else game.distance_label(game.active_distance)
	var badge := add_label(heading,"TROPHY EARNED" if trophy_earned else badge_text,16 if portrait else 22,GlassPalette.GREEN if game.result_record else AutomotiveUI.MUTED,true)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var content: BoxContainer=AutomotiveUI.column(body,12) if portrait else AutomotiveUI.row(body,18)
	content.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var visuals:=AutomotiveUI.column(content,6)
	visuals.size_flags_stretch_ratio=.8
	visuals.size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_label(visuals,str(GameCatalog.spec(game.profile.vehicle_id).name),22)
	var player:=vehicle(visuals,game.profile.vehicle_id,game.car,game.profile.appearance_for(game.profile.vehicle_id),175 if portrait else 160)
	player.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var model: String=game.active_contract.get("model","miata")
	add_label(visuals,str(game.active_contract.get("name","Rival"))+" · "+str(GameCatalog.spec(model).name),19,AutomotiveUI.MUTED)
	var opponent:=vehicle(visuals,model,game.rival,game.rival_appearance(),124 if portrait else 110)
	opponent.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var slip_scroll:=catalog_scroll(content,"TimeSlip",0)
	if portrait: content.move_child(slip_scroll,0)
	slip_scroll.custom_minimum_size.y=485 if portrait else 0
	var slip:=AutomotiveUI.panel(slip_scroll)
	slip.add_theme_constant_override("separation",8)
	add_label(slip,"REDLINE / TIME SLIP",26,AutomotiveUI.BLUE,true)
	slip_line(slip,game.distance_label(game.active_distance),"YOU","RIVAL",AutomotiveUI.MUTED,17)
	slip_line(slip,"Elapsed","%.3f s"%game.staging.elapsed(game.player_finish),"%.3f s"%game.staging.elapsed(game.rival_finish,1) if game.rival_finish>0 else "DNF",AutomotiveUI.INK,26)
	slip_line(slip,"Reaction","%.3f s"%game.player_reaction if game.staging.released[0] else "—","%.3f s"%game.staging.reactions[1] if game.staging.released[1] else "—")
	for split in [[18.288,"60 ft","sixty_ft_s"],[201.168,"1/8 mile","eighth_s"],[402.336,"1/4 mile","quarter_s"]]:
		if game.active_distance+0.001<float(split[0]): continue
		slip_line(slip,split[1],time_value(game.run_telemetry.result.get(split[2])),time_value(game.rival_telemetry.result.get(split[2])))
	var units: String="km/h" if game.profile.metric_speed else "mph"
	var factor: float=1.609344 if game.profile.metric_speed else 1.0
	slip_line(slip,"Trap speed","%.1f %s"%[game.finish_speed*factor,units],"%.1f %s"%[game.rival_trap_speed*factor,units] if game.rival_finish>0 else "—")
	slip_line(slip,"Total","%.3f s"%game.player_finish,"%.3f s"%game.rival_finish if game.rival_finish>0 else "—")
	if game.rival_finish>0 and not game.staging.red_light:
		var gap: float=absf(game.player_finish-game.rival_finish)
		add_label(slip,"Margin %.3f s"%gap,17,GlassPalette.GREEN if game.result_win else AutomotiveUI.ORANGE,true)
	if game.result_improvement>0.0005:
		add_label(slip,"%.3f s quicker than your last run here"%game.result_improvement,16,GlassPalette.GREEN)
	slip.add_child(HSeparator.new())
	var net: int=game.result_reward-game.active_stake
	add_label(slip,"NET %s$%d    +%d XP"%["+" if net>=0 else "−",absi(net),game.result_xp],27,GlassPalette.GREEN if net>=0 else AutomotiveUI.ORANGE,true)
	add_label(slip,"Race pay $%d  /  Stake $%d  /  Returned $%d"%[game.result_base_pay,game.active_stake,game.result_bet_return],16,AutomotiveUI.MUTED)
	if game.result_bonus>0:
		add_label(slip,("Championship trophy   /   +$%d" if trophy_earned else "Completion bonus +$%d")%game.result_bonus,18,Championships.TROPHY if trophy_earned else GlassPalette.GREEN)
	if boss_win:
		var victory:=add_label(slip,str(game.active_contract.victory),17,Championships.TROPHY)
		victory.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		victory.custom_minimum_size.y=23
	var series: String=game.active_contract.get("series","")
	if series in Championships.CLASSES:
		var wins:=Championships.wins(game.profile,series)
		add_label(slip,"Class %s   /   %d of %d cleared"%[series,wins,Championships.ROUNDS],19,AutomotiveUI.BLUE)
		progress_bar(slip,wins)
	elif series=="OPEN":
		add_label(slip,"Rival Challenge · replay for cash",18,AutomotiveUI.BLUE)
	add_label(slip,"Driver level %d%s"%[game.profile.level()," · Level up" if game.profile.level()>game.previous_level else ""],16,AutomotiveUI.MUTED)
	var actions:=grid(body,2 if portrait else 4,10)
	button(actions,"garage","Garage")
	button(actions,"results_upgrades","Upgrades")
	button(actions,"retry","Retry")
	button(actions,"next_rival","Career overview" if trophy_earned and Championships.trophies(game.profile)==6 else ("Next rival" if series=="OPEN" else "Next race"),true)

func time_value(value: Variant) -> String:
	return "—" if value==null else "%.3f s"%float(value)

func slip_line(parent: Node,metric: String,player: String,rival: String,color: Color=AutomotiveUI.INK,points: int=21) -> void:
	var row:=AutomotiveUI.row(parent,8)
	add_label(row,metric,17,AutomotiveUI.MUTED)
	add_label(row,player,points,color,true).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	add_label(row,rival,points,color,true).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
