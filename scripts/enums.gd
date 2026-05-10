extends Node

# === ENUMS ===
# Drag and drop support for rings

enum Owner { PLAYER, OPPONENT }

enum ActionState {
	CHOOSE_ACTION,
	HIT_SELECT_TARGET,
	SPLIT_DIALOG,
	RING_SELECT_TARGET,
	RING_DRAG,
	RING_PLACE,
	AI_TURN,
	GAME_OVER
}

enum RingType {
	# Index Finger Rings
	ASCLEPIUS,
	ICARUS,
	# Middle Finger Rings
	MEDUSA,
	AEGIS,
	# Ring Finger Rings
	HERCULES,
	MIDAS,
	# Pinkie Finger Rings
	HERMES,
	PANDORA,
}

# === CONSTANTS ===

const MAX_FINGERS := 5
const PLAYER_START_HANDS := 2
const OPPONENT_START_HANDS := 3
const AI_HIT_CHANCE := 0.7
const AI_DELAY := 0.5

# === RING RESOURCES ===

var RING_RESOURCES: Dictionary = {
	RingType.ASCLEPIUS: preload("res://resources/rings/ring_asclepius.tres"),
	RingType.ICARUS: preload("res://resources/rings/ring_icarus.tres"),
	RingType.MEDUSA: preload("res://resources/rings/ring_medusa.tres"),
	RingType.AEGIS: preload("res://resources/rings/ring_aegis.tres"),
	RingType.HERCULES: preload("res://resources/rings/ring_hercules.tres"),
	RingType.MIDAS: preload("res://resources/rings/ring_midas.tres"),
	RingType.HERMES: preload("res://resources/rings/ring_hermes.tres"),
	RingType.PANDORA: preload("res://resources/rings/ring_pandora.tres"),
}
