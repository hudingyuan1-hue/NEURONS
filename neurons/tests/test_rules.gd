extends SceneTree

const Rules = preload("res://scripts/core/interaction_rules.gd")
var checks: int = 0
var failed: int = 0


func _init() -> void:
	_test_search_completion()
	_test_skin_interrupt_and_pause()
	_test_resistance_and_snapshot()
	_test_transfer_geometry_and_identity()
	_test_cat_hit_and_death()
	_test_damage_interruption_and_nonrefreshing_stops()
	_test_adaptation_and_durations()
	print("NEURONS interaction rules: %d checks, %d failures" % [checks, failed])
	quit(1 if failed > 0 else 0)


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failed += 1
		push_error(label)


func _test_search_completion() -> void:
	var r = Rules.new()
	check(r.begin_search("drawer"), "search starts")
	check(r.search_attempts == 1 and r.neurons == 5, "reserve opportunity without reward")
	check(not r.begin_search("shelf"), "concurrent search rejected")
	check(not r.tick(3.999)["search_completed"], "not completed before actual duration")
	check(r.tick(0.001)["search_completed"], "complete at duration")
	check(r.neurons == 6 and r.search_count == 1, "complete gives exactly one neuron")
	check(not r.tick(20.0)["search_completed"] and r.neurons == 6, "completion cannot replay")
	check(not r.begin_search("drawer"), "completed target cannot earn again")
	r.cancel_search()
	check(r.neurons == 6 and r.search_count == 1, "late cancel preserves completed result")
	r.search_limit = 2
	check(r.begin_search("shelf"), "second opportunity starts")
	r.cancel_search()
	check(r.search_attempts == 2 and r.neurons == 6, "cancel neither refunds nor rewards")
	check(not r.begin_search("shelf"), "opportunity exhaustion enforced")


func _test_skin_interrupt_and_pause() -> void:
	var r = Rules.new()
	r.begin_search("desk")
	r.tick(1.0)
	var submitted: Dictionary = r.submit_skin()
	check(submitted["ok"] and submitted["success"] and r.neurons == 4, "paid skin queued")
	check(r.search_active and r.reaction_left == 0.0, "menu submission does not react")
	var paused_time: float = r.world_time
	var paused_progress: float = r.search_elapsed
	# The scene pause contract is deliberately no tick / apply / world commits.
	check(r.world_time == paused_time and r.search_elapsed == paused_progress,
		"external pause preserves game clock and progress")
	check(not r.submit_skin()["ok"] and r.neurons == 4, "duplicate pending cannot double-charge")
	var applied: Dictionary = r.apply_pending()
	check(applied["search_cancelled"] and not r.search_active, "resumed actual skin cancels search")
	check(r.reaction_left == 0.5 and r.skin_reactions == 1, "actual reaction counts once")
	check(not r.apply_pending()["ok"] and r.skin_reactions == 1, "reaction cannot replay")
	r.tick(0.499)
	check(not r.begin_search("desk"), "reaction body remains occupied")
	r.tick(0.001)
	check(r.begin_search("desk") and r.search_attempts == 2, "autonomy can resume after reaction")
	check(not r.submit_skin()["ok"], "cooldown persists after reaction")
	r.tick(1.5)
	check(r.submit_skin()["ok"] and r.neurons == 3, "cooldown ends at two game seconds")


func _test_resistance_and_snapshot() -> void:
	var r = Rules.new()
	r.skin_resistance = 1
	r.begin_search("cabinet")
	var cast: Dictionary = r.submit_skin()
	check(cast["ok"] and not cast["success"] and r.neurons == 4,
		"equal resistance rejects reaction but consumes valid payment")
	r.skin_resistance = 0
	check(not r.apply_pending()["success"] and r.search_active,
		"resistance snapshot stable; resisted cast does not cancel")
	check(r.skin_reactions == 0 and r.reaction_left == 0.0, "resisted cast has no adaptation")
	check(not r.submit_skin()["ok"], "resisted cast still cools down")
	r.tick(2.0)
	cast = r.submit_skin()
	r.skin_resistance = 99
	check(cast["success"] and r.apply_pending()["success"], "successful snapshot also immutable")
	var empty = Rules.new()
	empty.neurons = 0
	check(not empty.submit_skin()["ok"] and empty.cooldown_until == 0.0,
		"insufficient balance rejects without cooldown")


func _test_transfer_geometry_and_identity() -> void:
	var r = Rules.new()
	check(not r.commit_transfer("cup", "porridge", "mother", "protagonist", 1.201, true, true, true),
		"distant transfer rejected")
	check(not r.commit_transfer("cup", "porridge", "mother", "protagonist", 0.3, false, true, true),
		"transfer through wall rejected")
	check(not r.commit_transfer("cup", "porridge", "mother", "protagonist", 0.3, true, false, true),
		"wrong facing rejected")
	check(not r.commit_transfer("cup", "porridge", "mother", "protagonist", 0.3, true, true, false),
		"interrupted action cannot transfer")
	check(r.owners["porridge"] == "mother" and not r.settled.has("cup"),
		"invalid callbacks retain owner and do not consume event")
	check(r.commit_transfer("cup", "porridge", "mother", "protagonist", 1.2, true, true, true),
		"actual transfer at distance boundary")
	check(not r.commit_transfer("cup", "porridge", "mother", "protagonist", 0.3, true, true, true),
		"duplicate transfer event rejected")
	check(not r.commit_transfer("cup_new", "porridge", "mother", "protagonist", 0.3, true, true, true),
		"new callback cannot transfer item from stale owner")
	check(r.owners.size() == 1 and r.owners["porridge"] == "protagonist", "unique item ownership")
	check(r.known.is_empty() and r.institutional_records.is_empty() and r.facts.size() == 1,
		"facts, known information and institutional records remain separate")
	check(not r.commit_transfer("nan", "porridge", "protagonist", "mother", NAN, true, true, true),
		"nonfinite contact rejected")


func _test_cat_hit_and_death() -> void:
	var r = Rules.new()
	check(not r.commit_hit("hit", 3.0, true, true, true), "far cat hit rejected")
	check(not r.commit_hit("hit", 0.5, false, true, true), "occluded cat hit rejected")
	check(not r.commit_hit("hit", 0.5, true, true, false), "interrupted cat hit rejected")
	check(not r.commit_hit("hit", 0.5, true, true, true, "father"), "father is not generic cat attacker")
	check(r.commit_hit("hit", 0.5, true, true, true), "actual cat contact commits")
	check(r.hp == 90 and r.sp == 90, "original cat consequence 10HP and 10SP")
	check(not r.commit_hit("hit", 0.5, true, true, true) and r.hp == 90,
		"replayed cat contact cannot repeat damage")
	r.tick(0.25)
	r.hp = 10
	r.begin_search("desk")
	r.submit_skin()
	check(r.commit_hit("fatal", 0.5, true, true, true) and r.hp == 0, "lethal hit commits")
	check(not r.search_active and not r.apply_pending()["success"], "death blocks pending search and reaction")
	check(not r.commit_transfer("late", "porridge", "mother", "protagonist", 0.3, true, true, true),
		"no transfer after death")
	var time_at_death: float = r.world_time
	r.tick(9.0)
	check(r.world_time == time_at_death, "dead gameplay clock frozen")


func _test_damage_interruption_and_nonrefreshing_stops() -> void:
	var r = Rules.new()
	r.begin_search("cabinet")
	r.tick(3.8)
	check(r.commit_hit("ordinary", 0.2, true, true, true), "ordinary injury actually lands")
	check(not r.search_active and r.search_attempts == 1 and r.search_count == 0 and r.neurons == 5,
		"nonlethal ordinary injury interrupts search without reward/refund")
	check(r.hurt_left == 0.25 and r.stun_left == 0.0 and r.body_busy(),
		"ordinary hit-stop distinct from depletion stupor")
	check(not r.begin_search("cabinet") and not r.submit_skin()["ok"],
		"body cannot start action or pay body skill during hit-stop")
	r.tick(0.1)
	var remaining: float = r.hurt_left
	r.commit_hit("followup", 0.2, true, true, true)
	check(r.hp == 80 and r.sp == 80 and is_equal_approx(r.hurt_left, remaining),
		"consecutive injury deducts values without refreshing existing hit-stop")
	r.tick(0.15)
	check(not r.body_busy() and r.begin_search("cabinet"), "body resumes at original stop endpoint")
	check(not r.tick(0.2)["search_completed"] and r.neurons == 5,
		"cancelled old near-finished search cannot pay after restarting")
	var pending = Rules.new()
	pending.submit_skin()
	pending.commit_hit("before_reaction", 0.2, true, true, true)
	check(pending.pending_skin.is_empty() and not pending.apply_pending()["ok"]
		and pending.neurons == 4 and pending.skin_reactions == 0,
		"injury interrupts paid pending skill without refund or adaptation")
	var depleted = Rules.new()
	depleted.sp = 10
	depleted.begin_search("desk")
	depleted.commit_hit("depletion", 0.2, true, true, true)
	check(not depleted.search_active and depleted.stun_left == 1.0,
		"new SP depletion forcibly cancels current action")
	depleted.tick(0.2)
	depleted.commit_hit("during_stupor", 0.2, true, true, true)
	check(is_equal_approx(depleted.stun_left, 0.8) and is_equal_approx(depleted.hurt_left, 0.05),
		"damage during both active stops refreshes neither timer")
	depleted.tick(0.8)
	check(not depleted.body_busy(), "stupor ends at original one-second endpoint")
	depleted.commit_hit("numb_followup", 0.2, true, true, true)
	check(depleted.stun_left == 0.0 and depleted.hurt_left == 0.25,
		"already-empty SP permits ordinary hit-stop but no second depletion stupor")
	depleted.tick(0.25)
	depleted.sp = 20
	depleted.tick(0.001)
	depleted.commit_hit("after_recovery_1", 0.2, true, true, true)
	depleted.tick(0.25)
	depleted.commit_hit("after_recovery_2", 0.2, true, true, true)
	check(depleted.stun_left == 1.0, "recovery to twenty rearms a later zero-SP stupor")


func _test_adaptation_and_durations() -> void:
	var r = Rules.new()
	for index in range(3):
		r.submit_skin()
		r.apply_pending()
		r.tick(2.0)
	check(r.skin_pending_resistance and r.skin_reactions == 0 and r.skin_resistance == 0,
		"three actual reactions only queue growth until actual restart")
	r.neurons = 5
	r.submit_skin()
	r.apply_pending()
	check(r.skin_reactions == 0, "pending growth caps additional adaptation")
	var slow = Rules.new()
	slow.sp = 19
	slow.actual_attempt = 5
	check(slow.begin_search("complex", 1.2) and is_equal_approx(slow.search_duration, 4.8),
		"complexity, low-SP and capped practice factors use original formula")
	slow.cancel_search()
	slow.actual_attempt = 100
	check(slow.begin_search("simple", 0.8) and is_equal_approx(slow.search_duration, 3.2),
		"practice capped after fifth actual attempt")
	var old_time: float = slow.world_time
	slow.tick(-1.0)
	slow.tick(NAN)
	check(slow.world_time == old_time, "invalid tick cannot move gameplay time")
	var depleted = Rules.new()
	depleted.sp = 10
	depleted.commit_hit("deplete", 0.2, true, true, true)
	check(depleted.stun_left == 1.0, "new SP zero produces one second stupor")
	depleted.tick(1.0)
	depleted.commit_hit("again", 0.2, true, true, true)
	check(depleted.stun_left == 0.0, "SP already zero cannot repeat stupor")
