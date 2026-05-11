## Log messages for hand-vs-hand attacks.
## Placeholders: {source} {target} {fingers}
class_name LogAttackMessages
extends LogTemplate

@export_multiline var hit: String = "⚔ {source} strikes {target} → [b]{fingers} fingers[/b]"
@export_multiline var kill: String = "[color=#FF4466]💀 {source} strikes {target} — eliminated![/color]"
@export_multiline var hercules_hit: String = "[color=#FF6600]⚡ {source} unleashes Hercules' might on {target} → [b]{fingers} fingers[/b][/color]"
@export_multiline var hercules_kill: String = "[color=#FF6600]⚡ HERCULES SMASH! {source} obliterates {target}![/color]"
@export_multiline var aegis_block: String = "[color=#4D9FFF]⚔ Aegis Shield activated! {target} deflects the attack![/color]"
