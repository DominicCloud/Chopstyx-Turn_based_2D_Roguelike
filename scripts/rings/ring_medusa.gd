class_name RingMedusa
extends RingEffect

func perform_effect(context: Dictionary) -> bool:
	var gs: Node = context["game_state"]
	var target_id: int = context["target_id"]
	var target: Dictionary = gs.get_hand(target_id)
	if target.is_empty() or not target["alive"] or target["owner"] != Enums.Owner.OPPONENT:
		return false

	# Edge case: Can stun already stunned hands (refreshes the stun)
	var already_stunned: bool = target.get("stunned", false)
	target["stunned"] = true
	var target_label: String = gs._hand_label(target)

	if already_stunned:
		gs.log_message.emit(LogTemplates.ring.medusa_reinforce.format({"target": target_label}))
	else:
		gs.log_message.emit(LogTemplates.ring.medusa_petrify.format({"target": target_label}))

	gs.hands_changed.emit()
	return true
