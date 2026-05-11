class_name RingIcarus
extends RingEffect

func perform_effect(context: Dictionary) -> bool:
	var gs: Node = context["game_state"]
	var target_id: int = context["target_id"]
	var target: Dictionary = gs.get_hand(target_id)
	if target.is_empty() or not target["alive"] or target["owner"] != Enums.Owner.OPPONENT:
		return false

	var new_fingers: int = target["fingers"] - 1
	if new_fingers < 0:
		new_fingers = 0  # Can't go below 0
	target["fingers"] = new_fingers

	var target_label: String = gs._hand_label(target)
	if new_fingers == 0:
		target["alive"] = false
		gs.log_message.emit(LogTemplates.ring.icarus_burn.format({"target": target_label}))
		gs.hand_died.emit(target_id)
		gs._check_game_over()
	else:
		gs.log_message.emit(LogTemplates.ring.icarus_scorch.format({"target": target_label, "fingers": new_fingers}))

	gs.hands_changed.emit()
	return true
