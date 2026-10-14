class_name InteractionRules
extends RefCounted
## Bedroom sample rules. Time is game seconds; distances are logical metres.
## The scene supplies actual action/contact facts. It must not call tick or
## contact/transfer commits while the world is paused. Skin menu submission is
## allowed during that pause; apply_pending is called only after resuming.
## Simultaneous harmful facts must be adjudicated before recovery/transfer in
## the scene's verdict node. This small module is not the full S1 dispatcher.

const SKIN_COST: int = 1
const SKIN_COOLDOWN: float = 2.0
const SKIN_REACTION: float = 0.5
const MAX_CONTACT_DISTANCE: float = 1.2

var neurons: int = 5
var plexus: int = 3
var world_time: float = 0.0
var hp: int = 100
var sp: int = 100
var skin_resistance: int = 0
var global_resistance: int = 0
var cooldown_until: float = 0.0
var search_active: bool = false
var search_elapsed: float = 0.0
var search_duration: float = 4.0
var search_attempts: int = 0
var search_count: int = 0
var search_limit: int = 10
var reaction_left: float = 0.0
var facts: Array[Dictionary] = []
var known: Array = []
var institutional_records: Array = []
var owners: Dictionary = {"porridge": "mother"}
var settled: Dictionary = {}

var skin_power: int = 1
var skin_reactions: int = 0
var skin_pending_resistance: bool = false
var actual_attempt: int = 1
var stun_left: float = 0.0
var hurt_left: float = 0.0
var pending_skin: Dictionary = {}
var search_target: String = ""
var _search_serial: int = 0
var _cast_serial: int = 0
var _search_id: String = ""
var _completed_targets: Dictionary = {}
var _sp_depleted: bool = false


func begin_search(target_id: String, complexity: float = 1.0) -> bool:
	# Autonomous low-SP return-to-bed selection belongs to the scene. This
	# action entry retains the <20 duration factor for future legal control.
	if hp <= 0 or search_active or body_busy():
		return false
	if target_id.is_empty() or search_attempts >= search_limit:
		return false
	if _completed_targets.has(target_id) or not is_finite(complexity) or complexity <= 0.0:
		return false
	var practice: float = 1.0 - 0.05 * mini(maxi(actual_attempt - 1, 0), 4)
	search_duration = 4.0 * complexity * practice * (1.25 if sp < 20 else 1.0)
	search_elapsed = 0.0
	search_target = target_id
	search_attempts += 1
	_search_serial += 1
	_search_id = "search:%d:%d" % [actual_attempt, _search_serial]
	search_active = true
	_record("search_started", _search_id, {"target": target_id, "duration": search_duration})
	return true


func tick(delta: float) -> Dictionary:
	var result: Dictionary = {"search_completed": false, "reaction_finished": false, "target_id": ""}
	if hp <= 0 or not is_finite(delta) or delta <= 0.0:
		return result
	world_time += delta
	if sp >= 20:
		_sp_depleted = false
	var blocked_time: float = maxf(maxf(reaction_left, stun_left), hurt_left)
	var old_reaction: float = reaction_left
	reaction_left = _countdown(reaction_left, delta)
	stun_left = _countdown(stun_left, delta)
	hurt_left = _countdown(hurt_left, delta)
	result["reaction_finished"] = old_reaction > 0.0 and reaction_left <= 0.0
	if not search_active:
		return result
	search_elapsed = minf(search_duration, search_elapsed + maxf(0.0, delta - blocked_time))
	if search_elapsed + 0.000001 < search_duration:
		return result
	# Completion identity belongs to this attempt/action. Replayed animation
	# callbacks cannot create a second income event.
	search_active = false
	if settled.has(_search_id):
		return result
	settled[_search_id] = "completed"
	_completed_targets[search_target] = true
	search_count += 1
	neurons += 1
	_record("search_completed", _search_id, {"target": search_target, "neurons": 1})
	result["search_completed"] = true
	result["target_id"] = search_target
	result["event_id"] = _search_id
	return result


func submit_skin() -> Dictionary:
	if hp <= 0:
		return _rejected("dead")
	if not pending_skin.is_empty():
		return _rejected("pending")
	if body_busy():
		return _rejected("body_unavailable")
	if world_time + 0.000001 < cooldown_until:
		return _rejected("cooldown")
	if neurons < SKIN_COST:
		return _rejected("insufficient_neurons")
	_cast_serial += 1
	var event_id: String = "skin:%d:%d" % [actual_attempt, _cast_serial]
	# Values are captured at submission, not recalculated after the menu closes.
	var resistance: int = skin_resistance + global_resistance
	var succeeded: bool = skin_power > resistance
	neurons -= SKIN_COST
	cooldown_until = world_time + SKIN_COOLDOWN
	pending_skin = {"ok": true, "success": succeeded, "event_id": event_id,
		"power": skin_power, "resistance": resistance,
		"reason": "queued" if succeeded else "resisted"}
	_record("skin_submitted", event_id, {"cost": SKIN_COST, "success": succeeded,
		"power": skin_power, "resistance": resistance})
	return pending_skin.duplicate(true)


func apply_pending() -> Dictionary:
	if pending_skin.is_empty():
		return _rejected("no_pending")
	var result: Dictionary = pending_skin.duplicate(true)
	pending_skin.clear()
	var event_id: String = str(result["event_id"])
	if settled.has(event_id):
		return _rejected("already_settled")
	settled[event_id] = "resisted" if not bool(result["success"]) else "reaction"
	if hp <= 0 or stun_left > 0.0 or hurt_left > 0.0:
		settled[event_id] = "interrupted"
		result["success"] = false
		result["reason"] = "body_unavailable"
		result["search_cancelled"] = false
		_record("skin_interrupted", event_id)
		return result
	if not bool(result["success"]):
		result["search_cancelled"] = false
		_record("skin_resisted", event_id)
		return result
	var was_searching: bool = search_active
	cancel_search()
	reaction_left = SKIN_REACTION
	if not skin_pending_resistance:
		skin_reactions += 1
		if skin_reactions >= 3:
			skin_reactions = 0
			skin_pending_resistance = true
	# Pending growth is not permanent resistance until actual rest/revival.
	result["search_cancelled"] = was_searching
	result["reaction_duration"] = SKIN_REACTION
	result["reason"] = "reacted"
	_record("skin_reacted", event_id, {"cancelled_search": was_searching})
	return result


func cancel_search() -> void:
	if not search_active:
		return
	search_active = false
	settled[_search_id] = "cancelled"
	_record("search_cancelled", _search_id, {"target": search_target})


func commit_transfer(event_id: String, item: String, from: String, to: String,
		distance: float, line_of_sight: bool, facing: bool, active: bool) -> bool:
	if not _contact_allowed(event_id, distance, line_of_sight, facing, active):
		return false
	if item.is_empty() or from.is_empty() or to.is_empty() or from == to:
		return false
	if str(owners.get(item, "")) != from:
		return false
	owners[item] = to
	settled[event_id] = "transfer"
	_record("transfer", event_id, {"item": item, "from": from, "to": to})
	return true


func commit_hit(event_id: String, distance: float, line_of_sight: bool,
		facing: bool, active: bool, source_id: String = "cat",
		target_id: String = "protagonist") -> bool:
	# Only the original cat-startle consequence is represented here. The scene
	# must establish that source event before calling; this is not free combat.
	if source_id != "cat" or target_id != "protagonist":
		return false
	if not _contact_allowed(event_id, distance, line_of_sight, facing, active):
		return false
	settled[event_id] = "cat_hit"
	hp = maxi(0, hp - 10)
	sp = maxi(0, sp - 10)
	_record("cat_hit", event_id, {"source": source_id, "target": target_id,
		"hp_damage": 10, "sp_damage": 10})
	# S4 P157-158: actual damage interrupts unfinished body actions. Existing
	# damage/reward receipts and already paid skill costs are not rolled back.
	cancel_search()
	reaction_left = 0.0
	if not pending_skin.is_empty():
		var pending_id: String = str(pending_skin["event_id"])
		settled[pending_id] = "interrupted"
		_record("skin_interrupted", pending_id, {"cause": event_id})
		pending_skin.clear()
	if hp <= 0:
		stun_left = 0.0
		hurt_left = 0.0
	else:
		# A second injury still deducts health/SP, but cannot refresh an active
		# ordinary hit-stop. Depletion stupor has its own one-shot gate/timer.
		if hurt_left <= 0.0:
			hurt_left = 0.25
		if sp <= 0 and not _sp_depleted:
			_sp_depleted = true
			stun_left = 1.0
		elif sp >= 20:
			_sp_depleted = false
	return true


func body_busy() -> bool:
	return reaction_left > 0.0 or stun_left > 0.0 or hurt_left > 0.0


func _contact_allowed(event_id: String, distance: float, line_of_sight: bool,
		facing: bool, active: bool) -> bool:
	return hp > 0 and not event_id.is_empty() and not settled.has(event_id) \
		and is_finite(distance) and distance >= 0.0 and distance <= MAX_CONTACT_DISTANCE \
		and line_of_sight and facing and active


func _rejected(reason: String) -> Dictionary:
	return {"ok": false, "success": false, "reason": reason}


func _countdown(remaining: float, delta: float) -> float:
	# Avoid a sub-microsecond floating residue keeping the body occupied after
	# an exact animation endpoint such as 0.499 + 0.001 seconds.
	var value: float = maxf(0.0, remaining - delta)
	return 0.0 if value < 0.000001 else value


func _record(kind: String, event_id: String, details: Dictionary = {}) -> void:
	var fact: Dictionary = details.duplicate(true)
	fact["kind"] = kind
	fact["event_id"] = event_id
	fact["time"] = world_time
	facts.append(fact)
	# Actual facts never automatically become protagonist knowledge or an
	# institutional record. Those channels require separate observed events.
