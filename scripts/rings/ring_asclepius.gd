class_name RingAsclepius
extends RingEffect

func perform_effect(context: Dictionary) -> bool:
	var gs: Node = context["game_state"]
	var target_id: int = context["target_id"]
	var target: Dictionary = gs.get_hand(target_id)
	if target.is_empty() or not target["alive"] or target["owner"] != Enums.Owner.PLAYER:
		return false

	# Edge case: If at 4 fingers, adding 1 wraps to 0 (hand dies)
	var new_fingers: int = (target["fingers"] + 1) % Enums.MAX_FINGERS
	target["fingers"] = new_fingers

	var target_label: String = gs._hand_label(target)

	if new_fingers == 0:
		# Critical edge case: Asclepius can accidentally kill your own hand!
		target["alive"] = false
		gs.log_message.emit("[color=#FF4466]💀 Asclepius overhealed %s — it burst![/color]" % target_label)
		gs.hand_died.emit(target_id)
		gs._check_game_over()
	else:
		gs.log_message.emit("[color=#33F266]🌿 Asclepius heals %s → [b]%d fingers[/b][/color]" % [target_label, new_fingers])

	gs.hands_changed.emit()
	return true
