extends Node

# === SIGNALS ===

signal hands_changed()
signal hand_died(hand_id: int)
signal rings_changed()
signal turn_changed(is_player_turn: bool)
signal round_changed(round_num: int)
signal game_over(player_won: bool)
signal log_message(text: String)

# === DIFFICULTY ===

var ai_difficulty: int = 1  # 0=Easy, 1=Medium, 2=Hard
const DIFFICULTY_OPTIMAL := [0.4, 0.7, 0.95]

# === STATE ===

var hands: Array[Dictionary] = []  # {id, fingers, alive, owner, rings}
var next_hand_id := 0

var ring_cooldowns: Dictionary = {}  # RingType -> rounds remaining

var current_round := 1
var is_player_turn := true
var actions_remaining := 1
var bonus_actions := 0  # from Pinky ring

# === INITIALIZATION ===

func _ready() -> void:
	reset_game()


func reset_game() -> void:
	hands.clear()
	next_hand_id = 0
	ring_cooldowns.clear()
	current_round = 1
	is_player_turn = true
	actions_remaining = 1
	bonus_actions = 0

	# Create player hands
	for i in Enums.PLAYER_START_HANDS:
		_create_hand(Enums.Owner.PLAYER, 1)

	# Create opponent hands
	for i in Enums.OPPONENT_START_HANDS:
		_create_hand(Enums.Owner.OPPONENT, 1)

	# Initialize ring cooldowns
	for ring_type in Enums.RingType.values():
		ring_cooldowns[ring_type] = 0

	hands_changed.emit()
	rings_changed.emit()
	turn_changed.emit(true)
	round_changed.emit(current_round)


func _create_hand(owner: Enums.Owner, fingers: int) -> Dictionary:
	var hand := {
		"id": next_hand_id,
		"fingers": fingers,
		"alive": true,
		"owner": owner,
		"stunned": false,
		"protected": false,
		"double_damage": false,
		"midas_target": false,
		"rings": [],
	}
	next_hand_id += 1
	hands.append(hand)
	return hand

# === QUERIES ===

func get_hand(hand_id: int) -> Dictionary:
	for hand in hands:
		if hand["id"] == hand_id:
			return hand
	return {}


func get_hands_for_owner(owner: Enums.Owner) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hand in hands:
		if hand["owner"] == owner:
			result.append(hand)
	return result


func get_living_hands(owner: Enums.Owner) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hand in hands:
		if hand["owner"] == owner and hand["alive"]:
			result.append(hand)
	return result


func get_all_living_hands() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hand in hands:
		if hand["alive"]:
			result.append(hand)
	return result


func get_player_hands() -> Array[Dictionary]:
	return get_living_hands(Enums.Owner.PLAYER)


func get_opponent_hands() -> Array[Dictionary]:
	return get_living_hands(Enums.Owner.OPPONENT)


func has_living_hand_with_min_fingers(min_fingers: int) -> bool:
	for hand in get_player_hands():
		if hand["fingers"] >= min_fingers:
			return true
	return false

# === ACTIONS ===

func perform_hit(source_id: int, target_id: int) -> bool:
	var source := get_hand(source_id)
	var target := get_hand(target_id)
	if source.is_empty() or target.is_empty():
		return false
	if not source["alive"] or not target["alive"]:
		return false
	if source["fingers"] == 0:
		return false
	# Cannot hit yourself with the same hand
	if source_id == target_id:
		return false
	# Check if target is protected (Aegis)
	if target.get("protected", false) and target["owner"] == Enums.Owner.PLAYER:
		log_message.emit(LogTemplates.attack.aegis_block.format({"target": _hand_label(target)}))
		target["protected"] = false  # Aegis shield breaks after blocking one attack
		_consume_action()
		hands_changed.emit()
		return true

	# Calculate damage (doubled if source has Hercules ring active)
	var damage: int = source["fingers"]
	var hercules_active: bool = false
	if source.get("double_damage", false) and source["owner"] == Enums.Owner.PLAYER:
		damage *= 2
		hercules_active = true
		source["double_damage"] = false  # Effect applies once then resets

	var new_fingers: int = (target["fingers"] + damage) % Enums.MAX_FINGERS
	target["fingers"] = new_fingers

	var source_label := _hand_label(source)
	var target_label := _hand_label(target)

	if new_fingers == 0:
		target["alive"] = false
		var kill_msg: String
		if hercules_active:
			kill_msg = LogTemplates.attack.hercules_kill.format({"source": source_label, "target": target_label})
		else:
			kill_msg = LogTemplates.attack.kill.format({"source": source_label, "target": target_label})
		log_message.emit(kill_msg)
		hand_died.emit(target_id)
		_check_ring_earn(target)
		_check_game_over()
	else:
		var hit_msg: String
		if hercules_active:
			hit_msg = LogTemplates.attack.hercules_hit.format({"source": source_label, "target": target_label, "fingers": new_fingers})
		else:
			hit_msg = LogTemplates.attack.hit.format({"source": source_label, "target": target_label, "fingers": new_fingers})
		log_message.emit(hit_msg)

	_consume_action()
	hands_changed.emit()
	return true


func perform_split(owner: Enums.Owner, new_distribution: Array[int]) -> bool:
	var all_hands := get_hands_for_owner(owner)
	if all_hands.size() < 2:
		return false

	var total_current := 0
	for hand in all_hands:
		total_current += hand["fingers"]

	if total_current < 1:
		return false

	var total_new := 0
	for val in new_distribution:
		total_new += val

	# Must preserve total
	if total_new != total_current:
		return false

	# Must have correct number of values
	if new_distribution.size() != all_hands.size():
		return false

	# Each hand must have 0 (stays/becomes dead) or 1-4 fingers
	for val in new_distribution:
		if val < 0 or val >= Enums.MAX_FINGERS:
			return false

	# Stunned hands cannot have their finger count changed during a split
	for i in all_hands.size():
		if all_hands[i].get("stunned", false) and all_hands[i]["fingers"] != new_distribution[i]:
			return false

	# Must differ from current (positionally)
	var same := true
	for i in all_hands.size():
		if all_hands[i]["fingers"] != new_distribution[i]:
			same = false
			break
	if same:
		return false

	# Must not be a mere reordering of the same values
	var current_sorted := []
	var new_sorted := new_distribution.duplicate()
	for hand in all_hands:
		current_sorted.append(hand["fingers"])
	current_sorted.sort()
	new_sorted.sort()
	if current_sorted == new_sorted:
		return false

	# Apply - update alive status based on new finger count
	var parts: PackedStringArray = []
	for i in all_hands.size():
		var new_val: int = new_distribution[i]
		all_hands[i]["fingers"] = new_val
		all_hands[i]["alive"] = new_val > 0
		parts.append(str(new_val))

	var fingers_str := ", ".join(parts)
	if owner == Enums.Owner.PLAYER:
		log_message.emit(LogTemplates.split.player_split.format({"fingers": fingers_str}))
	else:
		log_message.emit(LogTemplates.split.opponent_split.format({"fingers": fingers_str}))
	_consume_action()
	hands_changed.emit()
	return true

# === RING SYSTEM ===

func get_ring_count(ring_type: Enums.RingType) -> int:
	var count := 0
	for hand in hands:
		if hand["owner"] == Enums.Owner.PLAYER:
			for ring in hand["rings"]:
				if ring == ring_type:
					count += 1
	return count


func earn_ring(ring_type: Enums.RingType, hand_id: int) -> bool:
	var ring = Enums.RING_RESOURCES[ring_type]
	if get_ring_count(ring_type) >= ring.capacity:
		return false
	var hand := get_hand(hand_id)
	if hand.is_empty() or not hand["alive"] or hand["owner"] != Enums.Owner.PLAYER:
		return false
	hand["rings"].append(ring_type)
	log_message.emit(LogTemplates.ring.ring_earned.format({"hand": _hand_label(hand), "ring": ring.ring_name}))
	rings_changed.emit()
	hands_changed.emit()
	return true


func can_use_ring(ring_type: Enums.RingType) -> bool:
	if ring_cooldowns[ring_type] > 0:
		return false
	var ring = Enums.RING_RESOURCES[ring_type]
	var min_fingers: int = ring.min_fingers_needed
	for hand in get_living_hands(Enums.Owner.PLAYER):
		for r in hand["rings"]:
			if r == ring_type and hand["fingers"] >= min_fingers:
				return true
	return false


func use_ring(ring_type: Enums.RingType, context: Dictionary) -> bool:
	if not can_use_ring(ring_type):
		return false
	var ring = Enums.RING_RESOURCES[ring_type]
	context["game_state"] = self
	if not ring.perform_effect(context):
		return false
	_apply_ring_cost(ring_type)
	if not ring.free_action:
		_consume_action()
	return true


func _apply_ring_cost(ring_type: Enums.RingType) -> void:
	var ring = Enums.RING_RESOURCES[ring_type]
	ring_cooldowns[ring_type] = ring.cooldown
	rings_changed.emit()

# === TURN MANAGEMENT ===

func _consume_action() -> void:
	actions_remaining -= 1


func has_actions_remaining() -> bool:
	return actions_remaining > 0


func end_player_turn() -> void:
	is_player_turn = false
	actions_remaining = 1
	bonus_actions = 0
	turn_changed.emit(false)


func end_opponent_turn() -> void:
	is_player_turn = true
	actions_remaining = 1
	bonus_actions = 0
	_tick_cooldowns()
	current_round += 1
	turn_changed.emit(true)
	round_changed.emit(current_round)


func _tick_cooldowns() -> void:
	for ring_type in ring_cooldowns:
		if ring_cooldowns[ring_type] > 0:
			ring_cooldowns[ring_type] -= 1
	rings_changed.emit()

# === HELPERS ===

func _check_ring_earn(dead_hand: Dictionary) -> void:
	# Player earns a ring when killing an opponent hand
	if dead_hand["owner"] == Enums.Owner.OPPONENT:
		# Will be handled by main.gd showing ring select dialog
		pass


func _check_game_over() -> void:
	if get_opponent_hands().size() == 0:
		game_over.emit(true)
	elif get_player_hands().size() == 0:
		game_over.emit(false)


func _hand_label(hand: Dictionary) -> String:
	var owner_str := "P" if hand["owner"] == Enums.Owner.PLAYER else "C"
	var index := 0
	var count := 0
	for h in hands:
		if h["owner"] == hand["owner"]:
			if h["id"] == hand["id"]:
				index = count
				break
			count += 1
	return "%s-Hand%d(%d)" % [owner_str, index + 1, hand["fingers"]]


func should_earn_ring_on_kill(dead_hand: Dictionary) -> bool:
	return dead_hand["owner"] == Enums.Owner.OPPONENT


func get_available_ring_types() -> Array[Enums.RingType]:
	var available: Array[Enums.RingType] = []
	for ring_type in Enums.RingType.values():
		var ring = Enums.RING_RESOURCES[ring_type]
		if get_ring_count(ring_type) < ring.capacity:
			available.append(ring_type as Enums.RingType)
	return available
