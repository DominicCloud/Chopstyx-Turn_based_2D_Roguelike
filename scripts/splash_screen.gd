extends Control

@onready var logo: TextureRect = $Logo
@onready var credits_label: RichTextLabel = $CreditsLabel
@onready var skip_label: Label = $SkipLabel

var _can_skip := false
var _transitioning := false

func _ready() -> void:
	# Start with everything invisible
	logo.modulate.a = 0.0
	credits_label.modulate.a = 0.0
	skip_label.modulate.a = 0.0

	# Run splash sequence
	_play_splash()


func _play_splash() -> void:
	# Brief initial delay
	await get_tree().create_timer(0.3).timeout

	# Fade in logo
	var tw := create_tween()
	tw.tween_property(logo, "modulate:a", 1.0, 1.0)
	await tw.finished

	# Show skip label
	_can_skip = true
	var tw2 := create_tween()
	tw2.tween_property(skip_label, "modulate:a", 0.5, 0.5)

	# Hold logo
	await get_tree().create_timer(1.5).timeout

	# Fade in credits
	var tw3 := create_tween()
	tw3.tween_property(credits_label, "modulate:a", 1.0, 0.8)
	await tw3.finished

	# Hold credits
	await get_tree().create_timer(2.0).timeout

	# Auto transition
	_transition_to_menu()


func _transition_to_menu() -> void:
	if _transitioning:
		return
	_transitioning = true

	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	await tw.finished

	get_tree().change_scene_to_file("res://scenes/screens/menu.tscn")


func _input(event: InputEvent) -> void:
	if not _can_skip or _transitioning:
		return
	if event is InputEventKey or event is InputEventMouseButton:
		if event.pressed:
			_transition_to_menu()
