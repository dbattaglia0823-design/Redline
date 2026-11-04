class_name RosterTest
extends RefCounted
# Prime asynchronous class work in deterministic tests which disable _process.
# Production continues to use bounded frame-by-frame advancement.
static func ready(game: Node2D) -> void:
	if game==null or game.profile==null: return
	for i in 2500:
		if not PerformanceClasses.request(game.profile.vehicle_id,game.profile.stages,game.profile.hardware).is_empty(): return
		PerformanceClasses.advance()
	push_error("Class benchmark failed to settle for test build")
