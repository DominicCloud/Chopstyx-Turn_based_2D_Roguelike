extends HBoxContainer

signal split_pressed
signal cancel_pressed
signal ring_use_requested(ring_type: Enums.RingType)
signal ring_drag_started(ring_type: Enums.RingType)

@onready var ring_panel: HBoxContainer = %RingPanel
@onready var split_button: Button = %SplitButton
@onready var cancel_button: Button = %CancelButton


func _ready() -> void:
	split_button.pressed.connect(func(): split_pressed.emit())
	cancel_button.pressed.connect(func(): cancel_pressed.emit())
	ring_panel.ring_use_requested.connect(func(rt): ring_use_requested.emit(rt))
	ring_panel.ring_drag_started.connect(func(rt): ring_drag_started.emit(rt))


func configure_for_state(state: Enums.ActionState) -> void:
	match state:
		Enums.ActionState.CHOOSE_ACTION:
			_set_action_buttons(true)
			ring_panel.set_enabled(true)
			cancel_button.visible = false

		Enums.ActionState.HIT_SELECT_TARGET:
			_set_action_buttons(false)
			cancel_button.visible = true
			cancel_button.disabled = false
			ring_panel.set_enabled(false)

		Enums.ActionState.SPLIT_DIALOG:
			_set_action_buttons(false)
			cancel_button.visible = false
			ring_panel.set_enabled(false)

		Enums.ActionState.RING_SELECT_TARGET, Enums.ActionState.RING_DRAG:
			_set_action_buttons(false)
			cancel_button.visible = true
			cancel_button.disabled = false
			ring_panel.set_enabled(false)

		Enums.ActionState.RING_PLACE:
			_set_action_buttons(false)
			cancel_button.visible = true
			cancel_button.disabled = false
			ring_panel.set_enabled(false)

		Enums.ActionState.AI_TURN:
			_set_action_buttons(false)
			cancel_button.visible = false
			ring_panel.set_enabled(false)

		Enums.ActionState.GAME_OVER:
			_set_action_buttons(false)
			cancel_button.visible = false
			ring_panel.set_enabled(false)


func _set_action_buttons(enabled: bool) -> void:
	split_button.disabled = not enabled
