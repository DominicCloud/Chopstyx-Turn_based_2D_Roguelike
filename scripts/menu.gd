extends Control

@export var bg_speed := 80.0

@onready var bg1: Sprite2D = $Sprite2D
@onready var bg2: Sprite2D = $Sprite2D2

@onready var menu_bg: AudioStreamPlayer = $menu_bg
@onready var menu_bg_water: AudioStreamPlayer = $menu_bg_water
@onready var start_sound: AudioStreamPlayer = $on_play

@onready var difficulty_row: HBoxContainer = $CenterContainer/VBoxContainer/DifficultyRow
@onready var title_label: Label = $CenterContainer/VBoxContainer/Label
@onready var play_button: Button = $CenterContainer/VBoxContainer/Play
@onready var quit_button: Button = $CenterContainer/VBoxContainer/Quit

var sprite_width := 0.0
var main_game_Scene: PackedScene = preload("res://scenes/screens/main.tscn")
var main_game: Control
var out_timer: float = 1.5

const DIFFICULTY_NAMES := ["Easy", "Medium", "Hard"]
const DIFFICULTY_COLORS := [
	Color(0.4, 1.0, 0.4),   # Easy - green
	Color(1.0, 0.85, 0.3),  # Medium - gold
	Color(1.0, 0.35, 0.35), # Hard - red
]
var _difficulty_buttons: Array[Button] = []

func _ready():
	if bg1.texture == null or bg2.texture == null:
		push_error("Background sprites must have textures assigned")
		return

	# Account for scale
	sprite_width = bg1.texture.get_size().x * bg1.scale.x

	title_label.add_theme_font_override("font", UIConstants.FONT_TITLE)
	play_button.add_theme_font_override("font", UIConstants.FONT_BODY_BOLD)
	quit_button.add_theme_font_override("font", UIConstants.FONT_BODY_BOLD)

	menu_bg.volume_db = -80 # Start quiet
	menu_bg.play()

	# Create a tween to fade in over 2 seconds
	var tween = create_tween()
	tween.tween_property(menu_bg, "volume_db", 0, 1.0).from(-80)

	# Position sprites side-by-side using CENTER origin
	bg1.position.x = sprite_width * 0.5
	bg2.position.x = bg1.position.x + sprite_width

	_build_difficulty_buttons()

func _build_difficulty_buttons() -> void:
	for i in DIFFICULTY_NAMES.size():
		var btn := Button.new()
		btn.text = DIFFICULTY_NAMES[i]
		btn.custom_minimum_size = Vector2(100, 36)
		btn.add_theme_font_override("font", UIConstants.FONT_BODY_BOLD)
		btn.pressed.connect(_on_difficulty_selected.bind(i))
		difficulty_row.add_child(btn)
		_difficulty_buttons.append(btn)
	_update_difficulty_highlight()


func _on_difficulty_selected(index: int) -> void:
	GameState.ai_difficulty = index
	_update_difficulty_highlight()


func _update_difficulty_highlight() -> void:
	for i in _difficulty_buttons.size():
		var btn := _difficulty_buttons[i]
		if i == GameState.ai_difficulty:
			btn.add_theme_color_override("font_color", DIFFICULTY_COLORS[i])
			btn.add_theme_color_override("font_hover_color", DIFFICULTY_COLORS[i])
			btn.modulate.a = 1.0
		else:
			btn.remove_theme_color_override("font_color")
			btn.remove_theme_color_override("font_hover_color")
			btn.modulate.a = 0.45


func _process(delta):
	bg1.position.x -= bg_speed * delta
	bg2.position.x -= bg_speed * delta

	# If a sprite fully leaves the screen, move it to the right of the other
	if bg1.position.x <= -sprite_width * 0.5:
		bg1.position.x = bg2.position.x + sprite_width

	if bg2.position.x <= -sprite_width * 0.5:
		bg2.position.x = bg1.position.x + sprite_width


func _on_play_pressed() -> void:
	menu_bg.playing = false
	menu_bg_water.playing = false
	start_sound.play()
	await get_tree().create_timer(out_timer).timeout

	get_tree().change_scene_to_file("res://scenes/screens/main.tscn")


func _on_options_pressed() -> void:
	pass # Replace with function body.

func _on_quit_pressed() -> void:
	get_tree().quit()

func _exit_tree() -> void:
	# Create a tween to fade in over 2 seconds
	var tween = create_tween()
	tween.tween_property(menu_bg, "volume_db", 0, out_timer).from(-80)
