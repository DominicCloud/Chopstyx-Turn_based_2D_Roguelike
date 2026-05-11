class_name RingPandora
extends RingEffect

func perform_effect(context: Dictionary) -> bool:
	var gs: Node = context["game_state"]
	var new_distribution: Array[int] = context["distribution"]

	# Get all hands (both player and opponent)
	var player_hands: Array[Dictionary] = gs.get_hands_for_owner(Enums.Owner.PLAYER)
	var opponent_hands: Array[Dictionary] = gs.get_hands_for_owner(Enums.Owner.OPPONENT)
	var all_hands: Array[Dictionary] = []
	for h in player_hands:
		all_hands.append(h)
	for h in opponent_hands:
		all_hands.append(h)

	if all_hands.size() < 2:
		return false

	# Calculate total combined fingers
	var total_combined := 0
	for hand in all_hands:
		total_combined += hand["fingers"]

	# Edge case: If total is 0, can't redistribute
	if total_combined == 0:
		gs.log_message.emit(LogTemplates.ring.pandora_no_fingers)
		return false

	# Validate distribution
	var total_new := 0
	for val in new_distribution:
		total_new += val

	if total_new != total_combined:
		return false

	if new_distribution.size() != all_hands.size():
		return false

	for val in new_distribution:
		if val < 0 or val >= Enums.MAX_FINGERS:
			return false

	# Pandora allows any distribution, but should not be identical
	var same := true
	for i in all_hands.size():
		if all_hands[i]["fingers"] != new_distribution[i]:
			same = false
			break
	if same:
		return false

	# Record which hands were alive before redistribution
	var was_alive: Array[bool] = []
	for hand in all_hands:
		was_alive.append(hand["alive"])

	# Apply distribution
	var parts: PackedStringArray = []
	for i in all_hands.size():
		var new_val: int = new_distribution[i]
		all_hands[i]["fingers"] = new_val
		all_hands[i]["alive"] = new_val > 0
		parts.append(str(new_val))

	gs.log_message.emit(LogTemplates.ring.pandora_chaos.format({"fingers": ", ".join(parts)}))

	# IMPORTANT: Emit hands_changed before checking deaths
	gs.hands_changed.emit()

	# Detect deaths caused by redistribution
	for i in all_hands.size():
		if was_alive[i] and not all_hands[i]["alive"]:
			gs.hand_died.emit(all_hands[i]["id"])
	gs._check_game_over()

	return true
