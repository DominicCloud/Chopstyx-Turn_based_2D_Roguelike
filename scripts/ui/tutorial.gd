extends Control

@onready var sections: Array[Control] = [$attack, $split, $defeat, $victory]

var _current := 0
var _can_advance := false
var _transitioning := false

const FADE_DURATION := 0.5


func _ready() -> void:
	for section in sections:
		section.visible = true
		section.modulate.a = 0.0
	_fade_in_current()


func _fade_in_current() -> void:
	_can_advance = false
	var tw := create_tween()
	tw.tween_property(sections[_current], "modulate:a", 1.0, FADE_DURATION)
	await tw.finished
	_can_advance = true


func _input(event: InputEvent) -> void:
	if not _can_advance or _transitioning:
		return
	if event is InputEventKey or event is InputEventMouseButton:
		if event.pressed:
			_advance()


func _advance() -> void:
	_can_advance = false
	_transitioning = true

	var tw := create_tween()
	tw.tween_property(sections[_current], "modulate:a", 0.0, FADE_DURATION)
	await tw.finished

	_current += 1

	if _current >= sections.size():
		await Fade.fade_out().finished
		get_tree().change_scene_to_file("res://scenes/ui/menu_wo_splashscrn.tscn")
		return

	_transitioning = false
	_fade_in_current()
