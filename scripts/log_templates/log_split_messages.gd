## Log messages for finger redistribution (split) actions.
## Placeholders: {fingers} = comma-joined finger counts e.g. "1, 2"
class_name LogSplitMessages
extends LogTemplate

@export_multiline var player_split: String = "[color=#00E5FF]🖐 You redistributed fingers → [{fingers}][/color]"
@export_multiline var opponent_split: String = "[color=#FF3399]🖐 Charon redistributed fingers → [{fingers}][/color]"
@export_multiline var player_no_hands: String = "[color=#FFAA00]⚠ You need at least 2 hands to redistribute fingers.[/color]"
@export_multiline var player_no_fingers: String = "[color=#FFAA00]⚠ No fingers available to redistribute.[/color]"
@export_multiline var invalid_split: String = "[color=#FFAA00]⚠ Invalid! Total must match current fingers and create a different arrangement.[/color]"
@export_multiline var pandora_invalid: String = "[color=#FFAA00]⚠ Invalid! Pandora requires the total to match all combined fingers.[/color]"
