extends Node

## How long Charon pauses before acting (seconds).
@export_range(0.0, 5.0, 0.05) var think_delay := 0.85
## Print AI reasoning to the action log (useful for testing).
@export var log_decisions := false
## Chance of picking the optimal move vs a random move each turn.
var optimal_chance: float = 0.7


func take_turn() -> Dictionary:
	var ai_hands := GameState.get_opponent_hands()
	var player_hands := GameState.get_player_hands()

	if ai_hands.is_empty() or player_hands.is_empty():
		return {}

	# Filter unstunned sources
	var valid_ai_hands: Array[Dictionary] = []
	for hand in ai_hands:
		if not hand.get("stunned", false):
			valid_ai_hands.append(hand)

	if valid_ai_hands.is_empty():
		for hand in ai_hands:
			hand["stunned"] = false
		GameState.log_message.emit(LogTemplates.game.charon_stunned)
		return {}

	# Midas forced attacks override everything — Charon must hit his own marked hand
	var midas_targets: Array[Dictionary] = []
	for hand in ai_hands:
		if hand.get("midas_target", false):
			midas_targets.append(hand)

	if not midas_targets.is_empty():
		var target: Dictionary = midas_targets[0]
		# Source must be a different hand from the target
		var valid_sources: Array[Dictionary] = []
		for hand in valid_ai_hands:
			if hand["id"] != target["id"] and hand["fingers"] > 0:
				valid_sources.append(hand)
		if not valid_sources.is_empty():
			var source := _pick_safest_source(valid_sources, target)
			if not source.is_empty():
				target["midas_target"] = false
				for hand in GameState.get_opponent_hands():
					hand["stunned"] = false
				return {
					"type": "hit",
					"source_id": source["id"],
					"target_id": target["id"]
				}
		# No valid source available — clear mark and proceed normally
		target["midas_target"] = false

	# Clear stuns
	for hand in GameState.get_opponent_hands():
		hand["stunned"] = false

	# Pick optimal or random based on difficulty
	if randf() < optimal_chance:
		return _take_turn_optimal(valid_ai_hands)
	else:
		return _take_turn_random(valid_ai_hands)


func _take_turn_random(valid_ai_hands: Array[Dictionary]) -> Dictionary:
	# Pick a random source with fingers > 0
	var sources: Array[Dictionary] = []
	for hand in valid_ai_hands:
		if hand["fingers"] > 0:
			sources.append(hand)
	if sources.is_empty():
		return {}

	var source: Dictionary = sources[randi() % sources.size()]

	# Pick a random target from ALL living hands (excluding source)
	var targets: Array[Dictionary] = []
	for hand in GameState.get_all_living_hands():
		if hand["id"] != source["id"]:
			targets.append(hand)
	if targets.is_empty():
		return {}

	var target: Dictionary = targets[randi() % targets.size()]
	_log("Random hit: src=%d tgt=%d" % [source["id"], target["id"]])
	return {
		"type": "hit",
		"source_id": source["id"],
		"target_id": target["id"]
	}


func _take_turn_optimal(valid_ai_hands: Array[Dictionary]) -> Dictionary:
	var snapshot := _snapshot_hands()

	var valid_source_ids: Array[int] = []
	for hand in valid_ai_hands:
		if hand["fingers"] > 0:
			valid_source_ids.append(hand["id"])

	var moves := _enumerate_ai_moves(snapshot, valid_source_ids)

	if moves.is_empty():
		return {}

	var best_move: Dictionary = {}
	var best_score := -999999

	for move in moves:
		var state := _apply_move(_deep_copy(snapshot), move)
		var score := _evaluate_after_player_response(state)

		if score > best_score:
			best_score = score
			best_move = move

	if best_move.is_empty():
		return {}

	if best_move["type"] == "hit":
		_log("Optimal hit: src=%d tgt=%d (score=%d)" % [
			best_move["source_id"], best_move["target_id"], best_score])
	elif best_move["type"] == "split":
		_log("Optimal split: %s (score=%d)" % [
			best_move["distribution"], best_score])

	return best_move


# === EVALUATION ===


func _evaluate_after_player_response(state: Array[Dictionary]) -> int:
	# Find the worst-case score after the player's best response
	var player_moves := _enumerate_player_moves(state)

	# If no player moves, evaluate current state directly
	if player_moves.is_empty():
		return _score_state(state)

	var worst_score := 999999
	for p_move in player_moves:
		var p_state := _apply_move(_deep_copy(state), p_move)
		var score := _score_state(p_state)
		if score < worst_score:
			worst_score = score

	return worst_score


func _score_state(state: Array[Dictionary]) -> int:
	# Composite score: advantage * 1000 + player_fingers * 10 + ai_fingers
	var ai_alive := _count_alive(state, Enums.Owner.OPPONENT)
	var player_alive := _count_alive(state, Enums.Owner.PLAYER)
	var advantage := ai_alive - player_alive
	var player_fingers := _total_fingers(state, Enums.Owner.PLAYER)
	var ai_fingers := _total_fingers(state, Enums.Owner.OPPONENT)
	return advantage * 1000 + player_fingers * 10 + ai_fingers


# === SNAPSHOT & SIMULATION ===


func _snapshot_hands() -> Array[Dictionary]:
	var snap: Array[Dictionary] = []
	for hand in GameState.hands:
		snap.append(hand.duplicate())
	return snap


func _deep_copy(snap: Array[Dictionary]) -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for hand in snap:
		copy.append(hand.duplicate())
	return copy


func _snap_hand(snap: Array[Dictionary], hand_id: int) -> Dictionary:
	for hand in snap:
		if hand["id"] == hand_id:
			return hand
	return {}


func _simulate_hit(snap: Array[Dictionary], source_id: int, target_id: int) -> void:
	var source := _snap_hand(snap, source_id)
	var target := _snap_hand(snap, target_id)
	if source.is_empty() or target.is_empty():
		return
	if not source["alive"] or source["fingers"] == 0:
		return
	if not target["alive"]:
		return
	# Aegis protection — strips shield without dealing damage
	if target.get("protected", false):
		target["protected"] = false
		return
	var damage: int = source["fingers"]
	# Account for Hercules double damage on player hands
	if source.get("double_damage", false) and source["owner"] == Enums.Owner.PLAYER:
		damage *= 2
	var new_fingers: int = (target["fingers"] + damage) % Enums.MAX_FINGERS
	target["fingers"] = new_fingers
	if new_fingers == 0:
		target["alive"] = false


func _simulate_split(snap: Array[Dictionary], owner: int, distribution: Array) -> void:
	var idx := 0
	for hand in snap:
		if hand["owner"] == owner:
			if idx < distribution.size():
				hand["fingers"] = int(distribution[idx])
				hand["alive"] = int(distribution[idx]) > 0
				idx += 1


func _apply_move(snap: Array[Dictionary], move: Dictionary) -> Array[Dictionary]:
	if move["type"] == "hit":
		_simulate_hit(snap, move["source_id"], move["target_id"])
	elif move["type"] == "split":
		var owner: int = move.get("owner", Enums.Owner.OPPONENT)
		_simulate_split(snap, owner, move["distribution"])
	return snap


func _count_alive(snap: Array[Dictionary], owner: int) -> int:
	var count := 0
	for hand in snap:
		if hand["owner"] == owner and hand["alive"]:
			count += 1
	return count


func _total_fingers(snap: Array[Dictionary], owner: int) -> int:
	var total := 0
	for hand in snap:
		if hand["owner"] == owner and hand["alive"]:
			total += hand["fingers"]
	return total


# === MOVE ENUMERATION ===


func _enumerate_ai_moves(snap: Array[Dictionary], valid_source_ids: Array[int]) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []

	# Hits against ALL living hands (any owner), excluding self-hits (same hand)
	for target in snap:
		if target["alive"]:
			for src_id in valid_source_ids:
				if target["id"] != src_id:
					moves.append({
						"type": "hit",
						"source_id": src_id,
						"target_id": target["id"]
					})

	# All valid split distributions (stunned hands are locked)
	var current: Array[int] = []
	var stunned_mask: Array[bool] = []
	var total := 0
	var hand_count := 0
	var free_count := 0
	var free_total := 0
	for hand in snap:
		if hand["owner"] == Enums.Owner.OPPONENT:
			current.append(hand["fingers"])
			var is_stunned: bool = hand.get("stunned", false)
			stunned_mask.append(is_stunned)
			total += hand["fingers"]
			hand_count += 1
			if not is_stunned:
				free_count += 1
				free_total += hand["fingers"]

	if free_count >= 2 and free_total > 0:
		var current_sorted := current.duplicate()
		current_sorted.sort()
		var free_distributions := _generate_distributions(free_count, free_total)
		for free_dist in free_distributions:
			# Reconstruct full distribution with locked stunned values
			var full_dist: Array = []
			var free_idx := 0
			for i in hand_count:
				if stunned_mask[i]:
					full_dist.append(current[i])
				else:
					full_dist.append(free_dist[free_idx])
					free_idx += 1
			if not _arrays_equal(full_dist, current):
				var full_sorted: Array = full_dist.duplicate()
				full_sorted.sort()
				if not _arrays_equal(full_sorted, current_sorted):
					moves.append({
						"type": "split",
						"owner": Enums.Owner.OPPONENT,
						"distribution": full_dist
					})

	return moves


func _enumerate_player_moves(snap: Array[Dictionary]) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []

	# Player hits against ALL living hands (any owner), excluding self-hits
	for source in snap:
		if source["owner"] == Enums.Owner.PLAYER and source["alive"] and source["fingers"] > 0:
			for target in snap:
				if target["alive"] and target["id"] != source["id"]:
					moves.append({
						"type": "hit",
						"source_id": source["id"],
						"target_id": target["id"]
					})

	# Player splits
	var current: Array[int] = []
	var total := 0
	var hand_count := 0
	for hand in snap:
		if hand["owner"] == Enums.Owner.PLAYER:
			current.append(hand["fingers"])
			total += hand["fingers"]
			hand_count += 1

	if hand_count >= 2 and total > 0:
		var current_sorted := current.duplicate()
		current_sorted.sort()
		var distributions := _generate_distributions(hand_count, total)
		for dist in distributions:
			if not _arrays_equal(dist, current):
				var dist_sorted: Array = dist.duplicate()
				dist_sorted.sort()
				if not _arrays_equal(dist_sorted, current_sorted):
					moves.append({
						"type": "split",
						"owner": Enums.Owner.PLAYER,
						"distribution": dist
					})

	return moves


# === DISTRIBUTION GENERATION ===


func _generate_distributions(count: int, total: int) -> Array:
	var results: Array = []
	var max_val := Enums.MAX_FINGERS - 1  # 4

	if count == 2:
		for a in range(max_val + 1):
			var b := total - a
			if b >= 0 and b <= max_val:
				results.append([a, b])
	elif count == 3:
		for a in range(max_val + 1):
			for b in range(max_val + 1):
				var c := total - a - b
				if c >= 0 and c <= max_val:
					results.append([a, b, c])

	return results


func _arrays_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if int(a[i]) != int(b[i]):
			return false
	return true


# === MIDAS HELPER ===
# When forced to attack by Midas, pick the source that leaves Charon safest.


func _pick_safest_source(sources: Array[Dictionary], target: Dictionary) -> Dictionary:
	var best_source: Dictionary = {}
	var best_score := -999999

	for source in sources:
		if source["fingers"] == 0:
			continue
		var snap := _snapshot_hands()
		_simulate_hit(snap, source["id"], target["id"])
		var score := _score_state(snap)

		if score > best_score:
			best_score = score
			best_source = source

	return best_source


# === LOGGING ===


func _log(msg: String) -> void:
	if log_decisions:
		GameState.log_message.emit("[AI] " + msg)
