class_name RingEffect
extends Resource

@export var ring_name: String
@export var short_name: String
@export var description: String
@export var cooldown: int = 1
@export var capacity: int = 2
@export var min_fingers_needed: int = 1
@export var finger_group: String  # "INDEX", "MIDDLE", "RING", "PINKY"
@export var free_action: bool = false
@export var ring_color: Color
@export var ring_letter: String
@export var ring_icon: Texture2D

enum TargetMode { SELF_HAND, OPPONENT_HAND, NO_TARGET, SPECIAL_DIALOG }
@export var target_mode: TargetMode = TargetMode.SELF_HAND
@export var target_prompt: String = "Select a target hand"

func perform_effect(context: Dictionary) -> bool:
	push_error("perform_effect not overridden for: " + ring_name)
	return false
