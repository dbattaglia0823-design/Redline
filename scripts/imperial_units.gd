class_name ImperialUnits
extends RefCounted

static func pounds(kg: float) -> float: return kg*2.2046226218
static func torque(nm: float) -> float: return nm*.7375621493
static func feet(meters: float) -> float: return meters*3.280839895
static func inches(meters: float) -> float: return meters*39.37007874
static func force(newtons: float) -> float: return newtons*.2248089431
static func inertia(kg_m2: float) -> float: return kg_m2*23.730360404
static func fahrenheit(celsius: float) -> float: return celsius*1.8+32.0

static func value(number: float,unit: String) -> float:
	match unit.strip_edges().to_lower():
		"kg": return pounds(number)
		"nm": return torque(number)
		"m", "m/s²", "m/s2": return feet(number)
		"mm": return inches(number/1000.0)
		"kg m2": return inertia(number)
		"n": return force(number)
		"°c": return fahrenheit(number)
	return number

static func unit(symbol: String) -> String:
	match symbol.strip_edges().to_lower():
		"kg": return "lb"
		"nm": return "lb-ft"
		"m": return "ft"
		"mm": return "in"
		"kg m2": return "lb·ft²"
		"m/s²", "m/s2": return "ft/s²"
		"n": return "lbf"
		"°c": return "°F"
	return symbol.strip_edges()

static func engine_label(label: String) -> String:
	var pattern:=RegEx.new()
	pattern.compile("([0-9]+(?:\\.[0-9]+)?)L")
	var found:=pattern.search(label)
	if found==null: return label
	return label.replace(found.get_string(),"%.0f cu in"%(float(found.get_string(1))*61.0237441))
