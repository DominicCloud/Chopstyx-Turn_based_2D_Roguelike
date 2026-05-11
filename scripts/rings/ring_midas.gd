class_name RingMidas
extends RingEffect

func perform_effect(context: Dictionary) -> bool:
	var gs: Node = context["game_state"]
	var target_id: int = context["target_id"]
	var target: Dictionary = gs.get_hand(target_id)
	if target.is_empty() or not target["alive"] or target["owner"] != Enums.Owner.OPPONENT:
		return false

	# Edge case: Clear all other midas marks (only one hand can be marked at a time)
	for hand in gs.get_opponent_hands():
		if hand["id"] != target_id:
			hand["midas_target"] = false

	var already_marked: bool = target.get("midas_target", false)
	target["midas_target"] = true
	var target_label: String = gs._hand_label(target)

	if already_marked:
		gs.log_message.emit(LogTemplates.ring.midas_wasted.format({"target": target_label}))
	else:
		gs.log_message.emit(LogTemplates.ring.midas_mark.format({"target": target_label}))

	gs.hands_changed.emit()
	return true
