class_name RingHercules
extends RingEffect

func perform_effect(context: Dictionary) -> bool:
	var gs: Node = context["game_state"]
	var target_id: int = context["target_id"]
	var target: Dictionary = gs.get_hand(target_id)
	if target.is_empty() or not target["alive"] or target["owner"] != Enums.Owner.PLAYER:
		return false

	# Edge case: Warn if already empowered (wastes the ring use)
	var already_empowered: bool = target.get("double_damage", false)
	target["double_damage"] = true
	var target_label: String = gs._hand_label(target)

	if already_empowered:
		gs.log_message.emit(LogTemplates.ring.hercules_wasted.format({"target": target_label}))
	else:
		gs.log_message.emit(LogTemplates.ring.hercules_charge.format({"target": target_label}))

	gs.hands_changed.emit()
	return true
