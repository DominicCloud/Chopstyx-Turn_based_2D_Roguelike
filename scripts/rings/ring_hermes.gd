class_name RingHermes
extends RingEffect

func perform_effect(context: Dictionary) -> bool:
	var gs: Node = context["game_state"]
	gs.bonus_actions += 1
	gs.actions_remaining += 1
	gs.log_message.emit(LogTemplates.ring.hermes_action.format({"remaining": gs.actions_remaining}))
	return true
