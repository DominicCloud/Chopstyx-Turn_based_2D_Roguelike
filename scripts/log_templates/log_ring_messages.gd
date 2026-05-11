## Log messages for ring acquisition and all ring effects.
## Placeholders vary per field — see inline comments.
class_name LogRingMessages
extends LogTemplate

# General — {hand}, {ring}
@export_multiline var ring_earned: String = "[color=#FFD700]✨ {hand} acquired the {ring}![/color]"
@export_multiline var ring_declined: String = "[color=#888888]You declined the divine gift.[/color]"
@export_multiline var all_rings_full: String = "[color=#FFAA00]⚠ Your hands are adorned with all the rings they can hold![/color]"

# Asclepius — {target}, {fingers}
@export_multiline var asclepius_heal: String = "[color=#33F266]🌿 Asclepius heals {target} → [b]{fingers} fingers[/b][/color]"
@export_multiline var asclepius_burst: String = "[color=#FF4466]💀 Asclepius overhealed {target} — it burst![/color]"

# Aegis — {target}
@export_multiline var aegis_shield: String = "[color=#4D9FFF]🛡️ Aegis shield guards {target}![/color]"
@export_multiline var aegis_wasted: String = "[color=#FFAA00]⚠ Aegis shield already guards {target} (wasted)![/color]"

# Hercules — {target}
@export_multiline var hercules_charge: String = "[color=#FF6600]💪 Hercules empowers {target} with legendary strength![/color]"
@export_multiline var hercules_wasted: String = "[color=#FFAA00]⚠ {target} already has Hercules' strength (wasted)![/color]"

# Hermes — {remaining}
@export_multiline var hermes_action: String = "[color=#9933FF]⚡ Hermes' speed grants another action! ([b]{remaining} remaining[/b])[/color]"

# Icarus — {target}, {fingers}
@export_multiline var icarus_scorch: String = "[color=#00B34C]☀️ Icarus scorches {target} → [b]{fingers} fingers[/b][/color]"
@export_multiline var icarus_burn: String = "[color=#00B34C]☀️ Icarus burns {target} to ashes![/color]"

# Medusa — {target}
@export_multiline var medusa_petrify: String = "[color=#3366FF]🐍 Medusa's gaze petrifies {target}![/color]"
@export_multiline var medusa_reinforce: String = "[color=#3366FF]🐍 Medusa reinforces the petrification on {target}![/color]"

# Midas — {target}
@export_multiline var midas_mark: String = "[color=#FFB333]👑 Midas' curse marks {target} — Charon will strike it![/color]"
@export_multiline var midas_wasted: String = "[color=#FFAA00]⚠ {target} already cursed by Midas (wasted)![/color]"

# Pandora — {fingers}
@export_multiline var pandora_chaos: String = "[color=#FF4DCC]📦 Pandora's chaos redistributes ALL fingers → [{fingers}][/color]"
@export_multiline var pandora_no_fingers: String = "[color=#FFAA00]⚠ No fingers to redistribute![/color]"
