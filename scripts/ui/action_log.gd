extends Control

@onready var log_label: RichTextLabel = %ActionLog


func _ready() -> void:
	GameState.log_message.connect(add_message)


func add_message(text: String) -> void:
	log_label.append_text(text + "\n")


func clear_log() -> void:
	log_label.clear()


func show_welcome() -> void:
	clear_log()
	add_message("[b][color=#FFD700]⚔ ChopStyx - Duel of the Ferryman ⚔[/color][/b]")
	add_message("[color=#AAAAAA]Eliminate all of Charon's hands to escape the Underworld![/color]")


func show_restart() -> void:
	clear_log()
	add_message("[b][color=#FFD700]⚔ ChopStyx - Duel of the Ferryman ⚔[/color][/b]")
	add_message("[color=#AAAAAA]A new challenger approaches the River Styx...[/color]")
