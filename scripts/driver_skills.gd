class_name DriverSkills
extends RefCounted

# Driver progression is separate from vehicle upgrades. Ranks are stored by stable ID.
const CATEGORIES := ["Launch", "Shifting", "Racecraft", "Career"]
const NODES := [
	{"id":"launch_basics","category":"Launch","name":"Grip Fundamentals","description":"+2% tire grip during launches and racing.","requires":[],"max_rank":1,"bonus":0.02,"effect":"grip"},
	{"id":"tree_reaction","category":"Launch","name":"Staging Control","description":"+1% grip and smoother throttle response off the line.","requires":["launch_basics"],"max_rank":1,"bonus":0.01,"effect":"grip"},
	{"id":"holeshot","category":"Launch","name":"Holeshot Setup","description":"+3% low-speed launch bite.","requires":["tree_reaction"],"max_rank":1,"bonus":0.03,"effect":"launch"},
	{"id":"shift_basics","category":"Shifting","name":"Shift Discipline","description":"Reduce shift delay by 2%.","requires":[],"max_rank":1,"bonus":0.02,"effect":"shift"},
	{"id":"clean_gears","category":"Shifting","name":"Smooth Engagement","description":"Reduce shift delay by another 2%.","requires":["shift_basics"],"max_rank":1,"bonus":0.02,"effect":"shift"},
	{"id":"shift_master","category":"Shifting","name":"Shift Master","description":"Reduce shift delay by another 3%.","requires":["clean_gears"],"max_rank":1,"bonus":0.03,"effect":"shift"},
	{"id":"track_time","category":"Racecraft","name":"Track Familiarity","description":"+2% braking effectiveness.","requires":[],"max_rank":1,"bonus":0.02,"effect":"brake"},
	{"id":"competitor","category":"Racecraft","name":"Cornerstone Control","description":"+1% grip across the run.","requires":["track_time"],"max_rank":1,"bonus":0.01,"effect":"grip"},
	{"id":"consistent","category":"Racecraft","name":"Consistent Inputs","description":"2% more responsive throttle control.","requires":["competitor"],"max_rank":1,"bonus":0.02,"effect":"throttle"},
	{"id":"street_rookie","category":"Career","name":"Street Rookie","description":"+5% race XP.","requires":[],"max_rank":1,"bonus":0.05,"effect":"xp"},
	{"id":"street_veteran","category":"Career","name":"Street Veteran","description":"+10% XP from race wins at level 5 or higher.","requires":["street_rookie"],"max_rank":1,"bonus":0.1,"effect":"xp"},
	{"id":"street_legend","category":"Career","name":"Street Legend","description":"+15% XP from race wins at level 10 or higher.","requires":["street_veteran"],"max_rank":1,"bonus":0.15,"effect":"xp"},
	{"id":"launch_repeatability","category":"Launch","name":"Launch Repeatability","description":"+2% launch traction when accelerating from the line.","requires":["launch_basics"],"max_rank":1,"bonus":0.02,"effect":"launch"},
	{"id":"amber_reader","category":"Launch","name":"Throttle Precision","description":"2% more responsive accelerator pedal.","requires":["launch_repeatability"],"max_rank":1,"bonus":0.02,"effect":"throttle"},
	{"id":"launch_specialist","category":"Launch","name":"Wheelspin Recovery","description":"Reduce wheelspin traction loss by 8%.","requires":["tree_reaction","amber_reader"],"max_rank":1,"bonus":0.08,"effect":"spin"},
	{"id":"perfect_start","category":"Launch","name":"Launch Mastery","description":"+3% overall grip to keep launches planted.","requires":["holeshot","launch_specialist"],"max_rank":1,"bonus":0.03,"effect":"grip"},
	{"id":"shift_rhythm","category":"Shifting","name":"Clutch Timing","description":"Engage the clutch 3% faster.","requires":["shift_basics"],"max_rank":1,"bonus":0.03,"effect":"clutch"},
	{"id":"shift_streak","category":"Shifting","name":"Gear Rhythm","description":"Reduce shift delay by another 2%.","requires":["shift_rhythm"],"max_rank":1,"bonus":0.02,"effect":"shift"},
	{"id":"gear_precision","category":"Shifting","name":"Precision Engagement","description":"Engage the clutch 4% faster.","requires":["clean_gears","shift_streak"],"max_rank":1,"bonus":0.04,"effect":"clutch"},
	{"id":"flawless_gears","category":"Shifting","name":"Fast Hands","description":"Reduce shift delay by another 3%.","requires":["shift_master","gear_precision"],"max_rank":1,"bonus":0.03,"effect":"shift"},
	{"id":"finish_line","category":"Racecraft","name":"Brake Control","description":"+2% braking effectiveness.","requires":["track_time"],"max_rank":1,"bonus":0.02,"effect":"brake"},
	{"id":"close_competition","category":"Racecraft","name":"Road Sense","description":"+1% tire grip across the run.","requires":["finish_line"],"max_rank":1,"bonus":0.01,"effect":"grip"},
	{"id":"race_veteran","category":"Racecraft","name":"Experienced Hands","description":"Reduce shift delay by 2%.","requires":["competitor","close_competition"],"max_rank":1,"bonus":0.02,"effect":"shift"},
	{"id":"track_ace","category":"Racecraft","name":"Racecraft Mastery","description":"+2% tire grip throughout the race.","requires":["consistent","race_veteran"],"max_rank":1,"bonus":0.02,"effect":"grip"},
	{"id":"street_learner","category":"Career","name":"Street Learner","description":"+8% race XP.","requires":["street_rookie"],"max_rank":1,"bonus":0.08,"effect":"xp"},
	{"id":"night_regular","category":"Career","name":"Prize Negotiator","description":"+5% bonus credits on winning wagers.","requires":["street_learner"],"max_rank":1,"bonus":0.05,"effect":"money"},
	{"id":"reputation","category":"Career","name":"Reputation","description":"+8% bonus credits on winning wagers at level 7 or higher.","requires":["street_veteran","night_regular"],"max_rank":1,"bonus":0.08,"effect":"money"},
	{"id":"champion_mentality","category":"Career","name":"Champion Mentality","description":"+10% bonus credits on winning wagers at level 15 or higher.","requires":["street_legend","reputation"],"max_rank":1,"bonus":0.1,"effect":"money"}
]

static func node_for(id: String) -> Dictionary:
	for node in NODES:
		if str(node.id) == id: return node
	return {}

static func sanitize(raw: Variant, level: int) -> Dictionary:
	var result: Dictionary = {}
	if not raw is Dictionary: return result
	var budget: int = maxi(0, level - 1)
	# Iterate in dependency order; reject invalid, unearned or orphaned ranks.
	for node in NODES:
		var id: String = str(node.id)
		var requested: Variant = raw.get(id, 0)
		if not (requested is int or requested is float) or not is_finite(float(requested)): continue
		if requested is float and float(requested) != floorf(float(requested)): continue
		var rank: int = clampi(int(requested), 0, int(node.max_rank))
		if rank == 0 or budget < rank: continue
		var eligible := true
		for required in node.requires:
			if int(result.get(required, 0)) == 0: eligible = false
		if eligible:
			result[id] = rank
			budget -= rank
	return result

static func available(ranks: Dictionary, level: int) -> int:
	var sanitized := sanitize(ranks, level)
	var spent := 0
	for rank in sanitized.values(): spent += int(rank)
	return maxi(0, level - 1 - spent)

static func can_unlock(ranks: Dictionary, level: int, id: String) -> bool:
	var node := node_for(id)
	if node.is_empty() or available(ranks, level) < 1: return false
	var valid := sanitize(ranks, level)
	if int(valid.get(id, 0)) >= int(node.max_rank): return false
	for required in node.requires:
		if int(valid.get(required, 0)) == 0: return false
	return true

static func unlock(ranks: Dictionary, level: int, id: String) -> Dictionary:
	if not can_unlock(ranks, level, id): return ranks.duplicate()
	var next := sanitize(ranks, level)
	next[id] = int(next.get(id, 0)) + 1
	return next

# Only Career perks alter rewards. Racing perks are applied to the player's
# drivetrain at configuration time, never to rival AI or stored vehicle builds.
static func performance_modifiers(ranks: Dictionary, level: int) -> Dictionary:
	var valid := sanitize(ranks, level)
	var values: Dictionary = {"grip":0.0,"launch":0.0,"spin":0.0,"throttle":0.0,"shift":0.0,"clutch":0.0,"brake":0.0}
	for node in NODES:
		if int(valid.get(str(node.id),0)) == 0: continue
		var effect: String = str(node.get("effect",""))
		if values.has(effect): values[effect] += float(node.bonus)
	# Modest hard caps prevent perks from replacing mechanical upgrades.
	values.grip = minf(0.10, float(values.grip))
	values.launch = minf(0.08, float(values.launch))
	values.spin = minf(0.10, float(values.spin))
	values.shift = minf(0.15, float(values.shift))
	return values

static func xp_bonus(ranks: Dictionary, level: int, won: bool, red: bool, _reaction: float, _perfect_shifts: int) -> float:
	var valid := sanitize(ranks, level)
	var bonus := 0.0
	for node in NODES:
		if node.category != "Career" or str(node.effect) != "xp" or int(valid.get(str(node.id),0)) == 0: continue
		match str(node.id):
			"street_rookie", "street_learner": bonus += float(node.bonus)
			"street_veteran": 
				if won and not red and level >= 5: bonus += float(node.bonus)
			"street_legend":
				if won and not red and level >= 10: bonus += float(node.bonus)
	return minf(0.75,bonus)

static func money_bonus(ranks: Dictionary, level: int, won: bool, red: bool) -> float:
	if not won or red: return 0.0
	var valid := sanitize(ranks,level)
	var bonus := 0.0
	for node in NODES:
		if node.category != "Career" or str(node.effect) != "money" or int(valid.get(str(node.id),0)) == 0: continue
		match str(node.id):
			"night_regular": bonus += float(node.bonus)
			"reputation":
				if level >= 7: bonus += float(node.bonus)
			"champion_mentality":
				if level >= 15: bonus += float(node.bonus)
	return minf(0.25,bonus)
