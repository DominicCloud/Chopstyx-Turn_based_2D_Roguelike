extends Control

@onready var play_button: TextureButton = $PlayButton
@onready var quit_button: TextureButton = $QuitButton

# Audio
@onready var menu_bg: AudioStreamPlayer = $bg_wind
@onready var menu_bg_water: AudioStreamPlayer = $bg_water
@onready var on_play: AudioStreamPlayer = $on_play
@onready var button_hover: AudioStreamPlayer = $button_hover


func _ready() -> void:
	menu_bg.playing = false
	menu_bg_water.playing = false
	await get_tree().process_frame # important on first launch
	await Fade.fade_in(0.7).finished

	# begin bg_music
	menu_bg.volume_db = -80 # Start quiet
	menu_bg.play()
	menu_bg_water.volume_db = -80
	menu_bg_water.play()

	var tween = create_tween()
	tween.tween_property(menu_bg, "volume_db", 0, 1.0).from(-80)
	tween.tween_property(menu_bg_water, "volume_db", 0, 1.0).from(-80)


func _process(_delta: float) -> void:
	pass


func _on_play_button_pressed() -> void:
	#menu_bg.playing = false
	var tween = create_tween()
	tween.tween_property(menu_bg, "volume_db", -80.0, 1.0)
	tween.tween_property(menu_bg_water, "volume_db", -80.0, 1.0)
	menu_bg_water.playing = false
	on_play.play()
	await get_tree().create_timer(1.0).timeout

	var scene := ResourceLoader.load("res://scenes/main.tscn")
	get_tree().change_scene_to_packed(scene)


func _on_tutorial_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/tutorial.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_button_mouse_entered() -> void:
	button_hover.play()
