extends HBoxContainer

signal split_pressed
signal cancel_pressed

@onready var split_button: Button = %SplitButton
@onready var cancel_button: Button = %CancelButton


func _ready() -> void:
	split_button.pressed.connect(func(): split_pressed.emit())
	cancel_button.pressed.connect(func(): cancel_pressed.emit())


func configure_for_state(state: Enums.ActionState) -> void:
	match state:
		Enums.ActionState.CHOOSE_ACTION:
			_set_action_buttons(true)
			cancel_button.visible = false

		Enums.ActionState.HIT_SELECT_TARGET:
			_set_action_buttons(false)
			cancel_button.visible = true
			cancel_button.disabled = false

		Enums.ActionState.SPLIT_DIALOG:
			_set_action_buttons(false)
			cancel_button.visible = false

		Enums.ActionState.RING_SELECT_TARGET, Enums.ActionState.RING_DRAG:
			_set_action_buttons(false)
			cancel_button.visible = true
			cancel_button.disabled = false

		Enums.ActionState.RING_PLACE:
			_set_action_buttons(false)
			cancel_button.visible = true
			cancel_button.disabled = false

		Enums.ActionState.AI_TURN:
			_set_action_buttons(false)
			cancel_button.visible = false

		Enums.ActionState.GAME_OVER:
			_set_action_buttons(false)
			cancel_button.visible = false


func _set_action_buttons(enabled: bool) -> void:
	split_button.disabled = not enabled
