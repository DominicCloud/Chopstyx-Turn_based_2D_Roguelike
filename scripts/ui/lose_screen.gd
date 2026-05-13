extends Control
@onready var charon_laughing: AudioStreamPlayer = $Charon_laughing
@onready var lose_music: AudioStreamPlayer = $lose_music
@onready var button_hover: AudioStreamPlayer = $button_hover

func _ready() -> void:
	await get_tree().process_frame # important on first launch
	await Fade.fade_in().finished
	_play_from_silence(charon_laughing)
	


func _play_from_silence(player: AudioStreamPlayer) -> void:
	if not player:
		return
	player.volume_db = -80.0
	player.play()
	create_tween().tween_property(player, "volume_db", 0.0, 1.5)
func _on_retry_button_pressed() -> void:
	await Fade.fade_out().finished
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_quit_button_pressed() -> void:
	await Fade.fade_out().finished
	get_tree().change_scene_to_file("res://scenes/ui/menu_wo_splashscrn.tscn")
	
func _on_button_hover() -> void:
	button_hover.play()
