class_name RingHermes
extends RingEffect

func perform_effect(context: Dictionary) -> bool:
	var gs: Node = context["game_state"]
	gs.bonus_actions += 1
	gs.actions_remaining += 1
	gs.log_message.emit("[color=#9933FF]⚡ Hermes' speed grants another action! ([b]%d remaining[/b])[/color]" % gs.actions_remaining)
	return true
