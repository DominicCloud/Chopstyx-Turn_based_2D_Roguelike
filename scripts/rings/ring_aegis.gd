class_name RingAegis
extends RingEffect

func perform_effect(context: Dictionary) -> bool:
	var gs: Node = context["game_state"]
	var target_id: int = context["target_id"]
	var target: Dictionary = gs.get_hand(target_id)
	if target.is_empty() or not target["alive"] or target["owner"] != Enums.Owner.PLAYER:
		return false

	# Edge case: Warn if already protected (wastes the ring use)
	var already_protected: bool = target.get("protected", false)
	target["protected"] = true
	var target_label: String = gs._hand_label(target)

	if already_protected:
		gs.log_message.emit(LogTemplates.ring.aegis_wasted.format({"target": target_label}))
	else:
		gs.log_message.emit(LogTemplates.ring.aegis_shield.format({"target": target_label}))

	gs.hands_changed.emit()
	return true
