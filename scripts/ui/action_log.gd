extends Control

@onready var log_label: RichTextLabel = %ActionLog
@onready var log_title_label: Label = $LogTitle


func _ready() -> void:
	log_title_label.add_theme_font_override("font", UIConstants.FONT_TITLE)
	log_label.add_theme_font_override("normal_font", UIConstants.FONT_BODY)
	log_label.add_theme_font_override("bold_font", UIConstants.FONT_BODY_BOLD)
	GameState.log_message.connect(add_message)


func add_message(text: String) -> void:
	log_label.append_text(text + "\n")


func clear_log() -> void:
	log_label.clear()


func show_welcome() -> void:
	clear_log()
	add_message(LogTemplates.game.welcome_title)
	add_message(LogTemplates.game.welcome_subtitle)


func show_restart() -> void:
	clear_log()
	add_message(LogTemplates.game.welcome_title)
	add_message(LogTemplates.game.restart_subtitle)
