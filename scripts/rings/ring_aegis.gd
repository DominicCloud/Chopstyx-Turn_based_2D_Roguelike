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
		gs.log_message.emit("[color=#FFAA00]⚠ Aegis shield already guards %s (wasted)![/color]" % target_label)
	else:
		gs.log_message.emit("[color=#4D9FFF]🛡️ Aegis shield guards %s![/color]" % target_label)

	gs.hands_changed.emit()
	return true
