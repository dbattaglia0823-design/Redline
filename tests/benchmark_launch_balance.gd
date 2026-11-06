extends SceneTree

func _initialize() -> void:
	var rows := []
	var before := "--before" in OS.get_cmdline_user_args()
	if before and VehicleParts.PARTS.has("gear_pro"):
		push_error("Run the baseline benchmark against the pre-balance scripts")
		quit(1)
		return
	for model in ["civic_si","miata","gtr"]:
		for tier in 3:
			var stages := GameCatalog.blank_stages()
			var build := GameCatalog.factory_build(model)
			var parts: Array = []
			if tier==1:
				stages=[1,1,0,0,0,0,0,0]
				parts=["street_radial","coilovers","clutch_twin","ecu"]
			elif tier==2:
				stages=[3,3,0,2,0,3,0,3]
				parts=["drag_slicks","pro_drag_susp","clutch_race","gear_strength","billet","fuel_ethanol","ecu_race","charge_pressure","turbo_hybrid"]
				for id in ["pro_drag_slicks","active_drag_susp","clutch_carbon","gear_pro"]:
					if not before and VehicleParts.PARTS.has(id):
						var slot: String=VehicleParts.PARTS[id].slot
						parts=parts.filter(func(part): return VehicleParts.PARTS[part].slot!=slot)
						parts.append(id)
				var tire: String=parts[0] if VehicleParts.PARTS[parts[0]].slot=="tires" else "pro_drag_slicks"
				build.tune={"tire_pressure":VehicleParts.PARTS[tire].pressure_peak,"launch_damping":1.2}
			for id in parts:
				build.owned_parts.append(id)
				build.parts[VehicleParts.PARTS[id].slot]=id
			var starts := []
			for rpm_offset in [-300,0,300]:
				var bench := VehicleBench.new()
				bench.begin(GameCatalog.spec(model),stages,build)
				bench.car.set_road_state(0,1,bench.car.rpm+rpm_offset)
				while not bench.done: bench.step_budget(960)
				var slip_samples := 0
				for sample in bench.samples:
					if sample.gear>0 and sample.shift_s<=0.0 and sample.clutch>=.95 and sample.mph>12 and sample.clutch_slip_rpm>150:
						slip_samples+=1
				starts.append({"sixty_ft":bench.result.sixty_ft_s,"zero_60":bench.result.zero_60_s,"quarter":bench.result.quarter_et_s,"wheelspin_s":bench.result.wheelspin_s,"loaded_slip_s":slip_samples*0.05,"clamps":bench.result.safety_clamps})
			rows.append({"car":model,"drive":GameCatalog.spec(model).drive,"tier":tier,"runs":starts})
	var name := "before" if before else "after"
	DirAccess.make_dir_recursive_absolute("res://.qa")
	var file := FileAccess.open("res://.qa/traction_"+name+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"  "))
	file.close()
	print("TRACTION BENCHMARK (",name,"): ",rows.size()," builds Ã— 3 launches")
	quit()
