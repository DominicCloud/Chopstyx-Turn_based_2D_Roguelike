## Static accessor for all log message template resources.
## Usage: LogTemplates.attack.kill.format({"source": s, "target": t})
## Edit the .tres files in resources/log_templates/ to change any message.
class_name LogTemplates

const attack: LogAttackMessages = preload("res://resources/log_templates/attack_messages.tres")
const split: LogSplitMessages = preload("res://resources/log_templates/split_messages.tres")
const ring: LogRingMessages = preload("res://resources/log_templates/ring_messages.tres")
const game: LogGameMessages = preload("res://resources/log_templates/game_messages.tres")
