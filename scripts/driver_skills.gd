class_name DriverSkills
extends RefCounted

# Driver progression is separate from vehicle upgrades. Ranks are stored by stable ID.
const CATEGORIES := ["Launch", "Shifting", "Racecraft", "Career"]
const NODES := [
	{"id":"launch_basics","category":"Launch","name":"Launch Basics","description":"Earn 5% more XP from every completed race.","requires":[],"max_rank":1,"bonus":0.05},
	{"id":"tree_reaction","category":"Launch","name":"Tree Reaction","description":"Earn 10% extra XP on a legal reaction of 0.200 seconds or faster.","requires":["launch_basics"],"max_rank":1,"bonus":0.10},
	{"id":"holeshot","category":"Launch","name":"Holeshot","description":"Earn 15% extra XP for wins with a legal reaction of 0.100 seconds or faster.","requires":["tree_reaction"],"max_rank":1,"bonus":0.15},
	{"id":"shift_basics","category":"Shifting","name":"Shift Discipline","description":"Earn 5% more XP from every completed race.","requires":[],"max_rank":1,"bonus":0.05},
	{"id":"clean_gears","category":"Shifting","name":"Clean Gears","description":"Earn 10% extra XP when you achieve at least two perfect shifts.","requires":["shift_basics"],"max_rank":1,"bonus":0.10},
	{"id":"shift_master","category":"Shifting","name":"Shift Master","description":"Earn 15% extra XP when you achieve at least four perfect shifts.","requires":["clean_gears"],"max_rank":1,"bonus":0.15},
	{"id":"track_time","category":"Racecraft","name":"Track Time","description":"Earn 5% more XP from every completed race.","requires":[],"max_rank":1,"bonus":0.05},
	{"id":"competitor","category":"Racecraft","name":"Competitor","description":"Earn 10% extra XP for a race victory.","requires":["track_time"],"max_rank":1,"bonus":0.10},
	{"id":"consistent","category":"Racecraft","name":"Consistency","description":"Earn 15% extra XP for a race victory without a red light.","requires":["competitor"],"max_rank":1,"bonus":0.15},
	{"id":"street_rookie","category":"Career","name":"Street Rookie","description":"Earn 5% more XP from every completed race.","requires":[],"max_rank":1,"bonus":0.05},
	{"id":"street_veteran","category":"Career","name":"Street Veteran","description":"Earn 10% extra XP on a win at driver level 5 or higher.","requires":["street_rookie"],"max_rank":1,"bonus":0.10},
	{"id":"street_legend","category":"Career","name":"Street Legend","description":"Earn 15% extra XP on a win at driver level 10 or higher.","requires":["street_veteran"],"max_rank":1,"bonus":0.15}
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

static func xp_bonus(ranks: Dictionary, level: int, won: bool, red: bool, reaction: float, perfect_shifts: int) -> float:
	var valid := sanitize(ranks, level)
	var bonus := 0.0
	for node in NODES:
		if int(valid.get(str(node.id), 0)) == 0: continue
		var id: String = str(node.id)
		var active := false
		match id:
			"launch_basics", "shift_basics", "track_time", "street_rookie": active = true
			"tree_reaction": active = not red and reaction >= 0.0 and reaction <= 0.2
			"holeshot": active = won and not red and reaction >= 0.0 and reaction <= 0.1
			"clean_gears": active = perfect_shifts >= 2
			"shift_master": active = perfect_shifts >= 4
			"competitor", "consistent": active = won and not red
			"street_veteran": active = won and not red and level >= 5
			"street_legend": active = won and not red and level >= 10
		if active: bonus += float(node.bonus)
	return minf(0.75, bonus)
