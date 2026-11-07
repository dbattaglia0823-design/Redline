class_name PressureUnits
extends RefCounted

# Simulation and existing saves store boost in bar. Convert at UI boundaries.
const PSI_PER_BAR := 14.503773773

static func psi(pressure_bar: float) -> float:
	return pressure_bar*PSI_PER_BAR

static func from_psi(pressure_psi: float) -> float:
	return pressure_psi/PSI_PER_BAR

static func is_pressure_setting(key: String) -> bool:
	return key in ["boost","boost_gear","boost_rise"] or key.begins_with("boost_slot_")
