extends Control

signal restart_requested

@onready var dialog: AcceptDialog = %GameOverDialog
@onready var result_label: Label = %GameOverLabel


func _ready() -> void:
	dialog.confirmed.connect(func(): restart_requested.emit())


func show_result(player_won: bool) -> void:
	if player_won:
		result_label.text = "YOU WIN!"
		result_label.add_theme_color_override("font_color", UIConstants.COLOR_PLAYER)
	else:
		result_label.text = "YOU LOSE!"
		result_label.add_theme_color_override("font_color", UIConstants.COLOR_OPPONENT)
	dialog.popup_centered()
