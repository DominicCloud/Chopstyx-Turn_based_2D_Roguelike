extends Control

@onready var play_button: TextureButton = $PlayButton
@onready var quit_button: TextureButton = $QuitButton
@onready var splashscreen: ColorRect = $Splashscreen
#@onready var all_black: ColorRect = $all_black
# Audio
@onready var menu_bg: AudioStreamPlayer = $menu_bg
@onready var menu_bg_water: AudioStreamPlayer = $menu_bg_water
@onready var on_play: AudioStreamPlayer = $on_play
@onready var button_hover: AudioStreamPlayer = $button_hover


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	menu_bg.playing = false
	menu_bg_water.playing = false
	await get_tree().process_frame # important on first launch
	await Fade.fade_in(1.5).finished
	await get_tree().create_timer(2.0).timeout
	Fade.crossfade_prepare(1.5)
	Fade.crossfade_execute()

	splashscreen.queue_free()

	
	# begin bg_music
	menu_bg.volume_db = -80 # Start quiet
	menu_bg.play()
	menu_bg_water.volume_db = -80
	menu_bg_water.play()

	# Create a tween to fade in over 2 seconds
	var tween = create_tween()
	tween.tween_property(menu_bg, "volume_db", 0, 1.0).from(-80)
	tween.tween_property(menu_bg_water, "volume_db", 0, 1.0).from(-80)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_play_button_pressed() -> void:
	#menu_bg.playing = false
	var tween = create_tween()
	tween.tween_property(menu_bg, "volume_db", -80.0, 1.0)
	tween.tween_property(menu_bg_water, "volume_db", -80.0, 1.0)
	menu_bg_water.playing = false
	on_play.play()
	await get_tree().create_timer(1.0).timeout
	
	get_tree().change_scene_to_file("res://scenes/screens/main.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_button_mouse_entered() -> void:
	button_hover.play()
