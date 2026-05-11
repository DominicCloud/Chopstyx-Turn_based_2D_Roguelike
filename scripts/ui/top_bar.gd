extends HBoxContainer

@onready var turn_label: Label = %TurnLabel
@onready var round_label: Label = %RoundLabel
@onready var actions_label: Label = %ActionsLabel


func _ready() -> void:
	for label: Label in [turn_label, round_label, actions_label]:
		label.add_theme_font_override("font", UIConstants.FONT_BODY_BOLD)
	GameState.turn_changed.connect(_on_turn_changed)
	GameState.round_changed.connect(_on_round_changed)


func _on_turn_changed(is_player: bool) -> void:
	turn_label.text = "Player's Turn" if is_player else "Charon's Turn"


func _on_round_changed(round_num: int) -> void:
	round_label.text = "Round %d" % round_num


func update_actions(remaining: int) -> void:
	actions_label.text = "Actions: %d" % remaining
