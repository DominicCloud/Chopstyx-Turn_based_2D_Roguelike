extends Node

@onready var bg_music: AudioStreamPlayer = $bg_music
@onready var click_sfx: AudioStreamPlayer = $click_sfx
@onready var hit_sfx: AudioStreamPlayer = $hit_sfx
@onready var charon_death_sfx: AudioStreamPlayer = $charon_death_sfx
@onready var split_sfx: AudioStreamPlayer = $split_sfx
@onready var charon_groan_sfx: AudioStreamPlayer = $charon_groan_sfx


func play_bg_music() -> void:
	if not bg_music.playing:
		bg_music.play()


func stop_bg_music() -> void:
	bg_music.stop()


func fade_out_music(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(bg_music, "volume_db", -80.0, duration)


func play_click() -> void:
	click_sfx.play()


func play_hit() -> void:
	hit_sfx.play()


func play_charon_death() -> void:
	charon_death_sfx.play()


func play_split() -> void:
	split_sfx.play()


func play_charon_groan() -> void:
	charon_groan_sfx.play()
