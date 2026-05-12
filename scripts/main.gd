extends Control

const HandDisplayScene := preload("res://scenes/gameplay/hand_display.tscn")
const RingEffectClass := preload("res://scripts/rings/ring_effect.gd")

# === SUB-SCENE REFS ===

@onready var top_bar: HBoxContainer = %TopBar
@onready var action_bar: HBoxContainer = %ActionBar
@onready var action_log_panel: Control = %ActionLogPanel
@onready var game_over_dialog: Control = %GameOverDialog
@onready var audio_manager: Node = %AudioManager

# === NODE REFS (still in main.tscn) ===

@onready var status_label: Label = %StatusLabel
@onready var opponent_label: Label = $OpponentSection/OpponentLabel
@onready var player_label: Label = $PlayerSection/PlayerLabel
@onready var opponent_hands_container: HBoxContainer = %OpponentHands
@onready var player_hands_container: HBoxContainer = %PlayerHands
@onready var flash_overlay: ColorRect = %FlashOverlay
@onready var split_panel: Control = %SplitPanel
@onready var ai_timer: Timer = %AITimer

const WinDialogScene := "res://scenes/ui/win_dialog.tscn"
const LoseDialogScene := "res://scenes/ui/lose_dialog.tscn"

var ring_select_panel: Control

# === STATE ===

var current_state: Enums.ActionState = Enums.ActionState.CHOOSE_ACTION
var hit_source_id: int = -1
var active_ring_type: Enums.RingType = Enums.RingType.ASCLEPIUS
var hand_displays: Dictionary = {}  # hand_id -> HandDisplay node
var ai: Node  # AIOpponent

var _pending_ring_earn := false
var _pending_ring_type: Enums.RingType = Enums.RingType.ASCLEPIUS
var _pending_ring_hand_id: int = -1
var _conflicting_ring_type: Enums.RingType = Enums.RingType.ASCLEPIUS
var _pandora_mode := false
var _hit_animating := false

# === INITIALIZATION ===

func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/bg_art/game_art_2.png")
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)

	await Fade.fade_in(.2).finished
	GameState.reset_game()

	status_label.add_theme_font_override("font", UIConstants.FONT_BODY)
	opponent_label.add_theme_font_override("font", UIConstants.FONT_TITLE)
	player_label.add_theme_font_override("font", UIConstants.FONT_TITLE)

	ai = preload("res://scripts/ai_opponent.gd").new()
	ai.optimal_chance = GameState.DIFFICULTY_OPTIMAL[GameState.ai_difficulty]
	add_child(ai)

	ring_select_panel = preload("res://scripts/ring_select_panel.gd").new()
	ring_select_panel.anchor_right = 1.0
	ring_select_panel.anchor_bottom = 1.0
	add_child(ring_select_panel)

	# Connect action bar signals
	action_bar.split_pressed.connect(_on_split_pressed)
	action_bar.cancel_pressed.connect(_on_cancel_pressed)

	# Connect game state signals
	GameState.hands_changed.connect(_refresh_hands)
	GameState.hand_died.connect(_on_hand_died)
	GameState.game_over.connect(_on_game_over)

	# Connect split panel
	split_panel.split_confirmed.connect(_on_split_confirmed)
	split_panel.split_canceled.connect(_on_cancel_pressed)

	# Connect dialogs
	ring_select_panel.ring_selected.connect(_on_ring_selected)
	ring_select_panel.selection_skipped.connect(_on_ring_select_closed)
	ring_select_panel.replace_confirmed.connect(_on_ring_replace_confirmed)
	ring_select_panel.keep_confirmed.connect(_on_ring_keep_confirmed)

	# AI timer
	ai_timer.timeout.connect(_on_ai_timer_timeout)

	# Initial setup
	_build_hand_displays()
	_set_state(Enums.ActionState.CHOOSE_ACTION)
	action_log_panel.show_welcome()
	_play_entrance_animations()


func _play_entrance_animations() -> void:
	var delay := 0.0
	for hand in GameState.hands:
		if hand_displays.has(hand["id"]):
			hand_displays[hand["id"]].play_entrance(delay)
			delay += UIConstants.ANIM_ENTRANCE_STAGGER


func _build_hand_displays() -> void:
	for child in opponent_hands_container.get_children():
		child.queue_free()
	for child in player_hands_container.get_children():
		child.queue_free()
	hand_displays.clear()

	var opp_index := 0
	for hand in GameState.hands:
		if hand["owner"] == Enums.Owner.OPPONENT:
			_add_hand_display(hand, opp_index, opponent_hands_container)
			opp_index += 1

	var player_index := 0
	for hand in GameState.hands:
		if hand["owner"] == Enums.Owner.PLAYER:
			_add_hand_display(hand, player_index, player_hands_container)
			player_index += 1


func _add_hand_display(hand: Dictionary, index: int, container: HBoxContainer) -> void:
	var display: Control = HandDisplayScene.instantiate()
	container.add_child(display)
	display.setup(hand["id"], hand, index)
	display.hand_clicked.connect(_on_hand_clicked)
	display.ring_activated.connect(_on_ring_activated)
	hand_displays[hand["id"]] = display

# === STATE MACHINE ===

func _set_state(new_state: Enums.ActionState) -> void:
	current_state = new_state
	_clear_highlights()
	top_bar.update_actions(GameState.actions_remaining)
	action_bar.configure_for_state(new_state)

	match new_state:
		Enums.ActionState.CHOOSE_ACTION:
			status_label.text = "Click a hand to attack"
			for hand in GameState.get_player_hands():
				if hand["fingers"] > 0 and hand_displays.has(hand["id"]):
					hand_displays[hand["id"]].set_selectable(true)
					hand_displays[hand["id"]].set_highlight(UIConstants.HighlightMode.SELECTABLE)

		Enums.ActionState.HIT_SELECT_TARGET:
			status_label.text = "Select target hand to hit"
			if hand_displays.has(hit_source_id):
				hand_displays[hit_source_id].set_selectable(true)
				hand_displays[hit_source_id].set_highlight(UIConstants.HighlightMode.SOURCE)
			for hand in GameState.get_all_living_hands():
				if hand["id"] != hit_source_id and hand_displays.has(hand["id"]):
					hand_displays[hand["id"]].set_selectable(true)
					hand_displays[hand["id"]].set_highlight(UIConstants.HighlightMode.TARGET)

		Enums.ActionState.SPLIT_DIALOG:
			var hands_to_show: Array[Dictionary] = []
			if _pandora_mode:
				status_label.text = "Pandora: Redistribute ALL fingers (yours + Charon's)"
				hands_to_show.append_array(GameState.get_hands_for_owner(Enums.Owner.PLAYER))
				hands_to_show.append_array(GameState.get_hands_for_owner(Enums.Owner.OPPONENT))
			else:
				status_label.text = "Redistribute your fingers"
				hands_to_show = GameState.get_hands_for_owner(Enums.Owner.PLAYER)
			split_panel.open(hands_to_show)

		Enums.ActionState.RING_SELECT_TARGET, Enums.ActionState.RING_DRAG:
			for hid in hand_displays:
				hand_displays[hid].set_selectable(false)
			var ring_res = Enums.RING_RESOURCES[active_ring_type]
			status_label.text = ring_res.target_prompt
			var target_hands: Array[Dictionary] = []
			match ring_res.target_mode:
				RingEffectClass.TargetMode.SELF_HAND:
					target_hands = GameState.get_player_hands()
				RingEffectClass.TargetMode.OPPONENT_HAND:
					target_hands = GameState.get_opponent_hands()
			for hand in target_hands:
				if hand_displays.has(hand["id"]):
					hand_displays[hand["id"]].set_selectable(true)
					hand_displays[hand["id"]].set_highlight(UIConstants.HighlightMode.TARGET)

		Enums.ActionState.RING_PLACE:
			var place_ring = Enums.RING_RESOURCES[_pending_ring_type]
			status_label.text = "Select a hand to wear the %s" % place_ring.ring_name
			for hand in GameState.get_player_hands():
				if hand_displays.has(hand["id"]):
					hand_displays[hand["id"]].set_selectable(true)
					hand_displays[hand["id"]].set_highlight(UIConstants.HighlightMode.TARGET)

		Enums.ActionState.AI_TURN:
			status_label.text = "Charon is thinking..."
			_set_all_hands_not_selectable()

		Enums.ActionState.GAME_OVER:
			status_label.text = "Game Over"
			_set_all_hands_not_selectable()

	_update_ring_interactability(new_state)

# === BUTTON HANDLERS ===

func _on_split_pressed() -> void:
	if current_state != Enums.ActionState.CHOOSE_ACTION:
		return
	var all_hands := GameState.get_hands_for_owner(Enums.Owner.PLAYER)
	if all_hands.size() < 2:
		_on_log_message(LogTemplates.split.player_no_hands)
		return
	var total := 0
	for hand in all_hands:
		total += hand["fingers"]
	if total < 1:
		_on_log_message(LogTemplates.split.player_no_fingers)
		return
	_set_state(Enums.ActionState.SPLIT_DIALOG)


func _on_cancel_pressed() -> void:
	if current_state == Enums.ActionState.RING_PLACE:
		_on_log_message(LogTemplates.ring.ring_declined)
		_pending_ring_earn = false
		_continue_after_ring_earn()
		return
	hit_source_id = -1
	if split_panel.visible:
		split_panel.close()
	_set_state(Enums.ActionState.CHOOSE_ACTION)

# === HAND CLICK HANDLER ===

func _on_hand_clicked(hand_id: int) -> void:
	if _hit_animating:
		return
	match current_state:
		Enums.ActionState.CHOOSE_ACTION:
			var hand := GameState.get_hand(hand_id)
			if hand["owner"] == Enums.Owner.PLAYER and hand["alive"] and hand["fingers"] > 0:
				audio_manager.play_click()
				hit_source_id = hand_id
				_set_state(Enums.ActionState.HIT_SELECT_TARGET)

		Enums.ActionState.HIT_SELECT_TARGET:
			if hand_id == hit_source_id:
				hit_source_id = -1
				_set_state(Enums.ActionState.CHOOSE_ACTION)
				return
			var hand := GameState.get_hand(hand_id)
			if hand_id != hit_source_id and hand["alive"]:
				_set_all_hands_not_selectable()
				var source_display: Control = hand_displays[hit_source_id]
				var target_display: Control = hand_displays[hand_id]
				var target_center := target_display.global_position + target_display.size * 0.5
				_hit_animating = true
				await source_display.play_hit_toward(target_center)
				_hit_animating = false
				if hand_displays.has(hand_id):
					hand_displays[hand_id].play_hit_flash()
				_screen_flash()
				audio_manager.play_hit()
				GameState.perform_hit(hit_source_id, hand_id)
				hit_source_id = -1
				_after_player_action()

		Enums.ActionState.RING_SELECT_TARGET, Enums.ActionState.RING_DRAG:
			if hand_displays.has(hand_id):
				hand_displays[hand_id].play_hit_flash()
			if GameState.use_ring(active_ring_type, {"target_id": hand_id}):
				_after_ring_action()

		Enums.ActionState.RING_PLACE:
			var hand := GameState.get_hand(hand_id)
			if hand.is_empty() or not hand["alive"] or hand["owner"] != Enums.Owner.PLAYER:
				return
			var new_ring_res = Enums.RING_RESOURCES[_pending_ring_type]
			var conflict_type: int = -1
			for existing in hand["rings"]:
				var er = Enums.RING_RESOURCES[existing as Enums.RingType]
				if er.finger_group == new_ring_res.finger_group:
					conflict_type = existing
					break
			if conflict_type >= 0:
				_pending_ring_hand_id = hand_id
				_conflicting_ring_type = conflict_type as Enums.RingType
				ring_select_panel.open_replace_prompt(_conflicting_ring_type, _pending_ring_type)
			else:
				GameState.earn_ring(_pending_ring_type, hand_id)
				_pending_ring_earn = false
				_continue_after_ring_earn()

# === SPLIT PANEL ===

func _on_split_confirmed(distribution: Array[int]) -> void:
	if _pandora_mode:
		if GameState.use_ring(Enums.RingType.PANDORA, {"distribution": distribution}):
			_pandora_mode = false
			audio_manager.play_split()
			_after_player_action()
		else:
			_on_log_message(LogTemplates.split.pandora_invalid)
			_set_state(Enums.ActionState.CHOOSE_ACTION)
			_pandora_mode = false
	else:
		if GameState.perform_split(Enums.Owner.PLAYER, distribution):
			audio_manager.play_split()
			_after_player_action()
		else:
			_on_log_message(LogTemplates.split.invalid_split)
			_set_state(Enums.ActionState.CHOOSE_ACTION)

# === RING USAGE ===

func _on_ring_use_requested(ring_type: Enums.RingType) -> void:
	if current_state != Enums.ActionState.CHOOSE_ACTION:
		return
	if not GameState.can_use_ring(ring_type):
		return

	active_ring_type = ring_type
	var ring = Enums.RING_RESOURCES[ring_type]

	match ring.target_mode:
		RingEffectClass.TargetMode.SELF_HAND, RingEffectClass.TargetMode.OPPONENT_HAND:
			_set_state(Enums.ActionState.RING_SELECT_TARGET)
		RingEffectClass.TargetMode.NO_TARGET:
			if GameState.use_ring(ring_type, {}):
				_after_ring_action()
		RingEffectClass.TargetMode.SPECIAL_DIALOG:
			_pandora_mode = true
			_set_state(Enums.ActionState.SPLIT_DIALOG)


func _on_ring_activated(p_hand_id: int, ring_type: Enums.RingType) -> void:
	if current_state != Enums.ActionState.CHOOSE_ACTION and current_state != Enums.ActionState.HIT_SELECT_TARGET:
		return
	if not GameState.can_use_ring(ring_type):
		return
	# Reset hit selection so the ring-use guard passes
	hit_source_id = -1
	current_state = Enums.ActionState.CHOOSE_ACTION
	_on_ring_use_requested(ring_type)


func _update_ring_interactability(state: Enums.ActionState) -> void:
	match state:
		Enums.ActionState.CHOOSE_ACTION:
			for hand in GameState.get_player_hands():
				if hand_displays.has(hand["id"]):
					hand_displays[hand["id"]].set_rings_interactable(true)
		Enums.ActionState.HIT_SELECT_TARGET:
			for hid in hand_displays:
				hand_displays[hid].set_rings_interactable(hid == hit_source_id)
		_:
			for hid in hand_displays:
				hand_displays[hid].set_rings_interactable(false)


func _after_ring_action() -> void:
	if current_state == Enums.ActionState.GAME_OVER:
		return
	if _pending_ring_earn:
		_show_ring_select_dialog()
		return
	if GameState.has_actions_remaining():
		_set_state(Enums.ActionState.CHOOSE_ACTION)
	else:
		_start_ai_turn()

# === RING EARN DIALOG ===

func _on_hand_died(hand_id: int) -> void:
	var hand := GameState.get_hand(hand_id)
	if hand.is_empty():
		return
	if hand_displays.has(hand_id):
		hand_displays[hand_id].play_death()
	if hand["owner"] == Enums.Owner.OPPONENT:
		audio_manager.play_charon_death()
	if GameState.should_earn_ring_on_kill(hand) and GameState.is_player_turn:
		_pending_ring_earn = true


func _show_ring_select_dialog() -> void:
	var available := GameState.get_available_ring_types()
	if available.is_empty():
		_on_log_message(LogTemplates.ring.all_rings_full)
		_pending_ring_earn = false
		return

	var shuffled := available.duplicate()
	shuffled.shuffle()
	var offered := shuffled.slice(0, mini(2, shuffled.size()))
	ring_select_panel.open(offered)


func _on_ring_selected(ring_type: Enums.RingType) -> void:
	_pending_ring_type = ring_type
	_set_state(Enums.ActionState.RING_PLACE)


func _on_ring_select_closed() -> void:
	if _pending_ring_earn:
		_on_log_message(LogTemplates.ring.ring_declined)
		_pending_ring_earn = false
		_continue_after_ring_earn()


func _on_ring_replace_confirmed() -> void:
	GameState.replace_ring(_pending_ring_hand_id, _conflicting_ring_type, _pending_ring_type)
	_pending_ring_earn = false
	_pending_ring_hand_id = -1
	_continue_after_ring_earn()


func _on_ring_keep_confirmed() -> void:
	_on_log_message(LogTemplates.ring.ring_declined)
	_pending_ring_earn = false
	_pending_ring_hand_id = -1
	_continue_after_ring_earn()

# === TURN FLOW ===

func _after_player_action() -> void:
	if current_state == Enums.ActionState.GAME_OVER:
		return
	if _pending_ring_earn:
		_show_ring_select_dialog()
		return
	_continue_after_ring_earn()


func _continue_after_ring_earn() -> void:
	if current_state == Enums.ActionState.GAME_OVER:
		return
	if GameState.has_actions_remaining():
		_set_state(Enums.ActionState.CHOOSE_ACTION)
	else:
		_start_ai_turn()


func _start_ai_turn() -> void:
	GameState.end_player_turn()
	_set_state(Enums.ActionState.AI_TURN)
	ai_timer.start(ai.think_delay)


func _on_ai_timer_timeout() -> void:
	if current_state == Enums.ActionState.GAME_OVER:
		return

	var ai_move: Dictionary = ai.take_turn()

	if ai_move.is_empty():
		GameState.end_opponent_turn()
		_set_state(Enums.ActionState.CHOOSE_ACTION)
		return

	await _execute_ai_move(ai_move)

	if current_state == Enums.ActionState.GAME_OVER:
		return

	GameState.end_opponent_turn()
	_set_state(Enums.ActionState.CHOOSE_ACTION)


func _execute_ai_move(move: Dictionary) -> void:
	if move["type"] == "hit":
		var source_id: int = move["source_id"]
		var target_id: int = move["target_id"]

		if hand_displays.has(source_id) and hand_displays.has(target_id):
			_set_all_hands_not_selectable()
			var source_display: Control = hand_displays[source_id]
			var target_display: Control = hand_displays[target_id]
			var target_center := target_display.global_position + target_display.size * 0.5
			await source_display.play_hit_toward(target_center)

			target_display.play_hit_flash()
			_screen_flash()
			audio_manager.play_hit()

		GameState.perform_hit(source_id, target_id)

	elif move["type"] == "split":
		var dist: Array[int] = []
		for v in move["distribution"]:
			dist.append(int(v))
		GameState.perform_split(Enums.Owner.OPPONENT, dist)
		audio_manager.play_split()

# === VISUAL EFFECTS ===

func _screen_flash() -> void:
	flash_overlay.color = Color(1, 1, 1, 0.15)
	var tw := create_tween()
	tw.tween_property(flash_overlay, "color:a", 0.0, UIConstants.ANIM_SCREEN_FLASH)

# === GAME STATE SIGNAL HANDLERS ===

func _on_game_over(player_won: bool) -> void:
	_set_state(Enums.ActionState.GAME_OVER)
	if player_won:
		_on_log_message(LogTemplates.game.victory)
		audio_manager.play_charon_groan()
	else:
		_on_log_message(LogTemplates.game.defeat)
	audio_manager.fade_out_music(2.2)
	await get_tree().create_timer(1.2).timeout
	#if player_won:
		#audio_manager.play_charon_groan()
	await Fade.fade_out().finished
	if player_won:
		get_tree().change_scene_to_file(WinDialogScene)
	else:
		get_tree().change_scene_to_file(LoseDialogScene)


func _on_log_message(text: String) -> void:
	action_log_panel.add_message(text)

# === HAND DISPLAY MANAGEMENT ===

func _refresh_hands() -> void:
	var opp_index := 0
	var player_index := 0
	for hand in GameState.hands:
		if hand_displays.has(hand["id"]):
			var idx: int
			if hand["owner"] == Enums.Owner.OPPONENT:
				idx = opp_index
			else:
				idx = player_index
			hand_displays[hand["id"]].refresh(hand, idx)

		if hand["owner"] == Enums.Owner.OPPONENT:
			opp_index += 1
		else:
			player_index += 1


func _rebuild_hand_displays_safe() -> void:
	for hand in GameState.hands:
		if not hand_displays.has(hand["id"]):
			var container: HBoxContainer
			var index := 0
			if hand["owner"] == Enums.Owner.PLAYER:
				container = player_hands_container
				for h in GameState.hands:
					if h["owner"] == Enums.Owner.PLAYER and h["id"] < hand["id"]:
						index += 1
			else:
				container = opponent_hands_container
				for h in GameState.hands:
					if h["owner"] == Enums.Owner.OPPONENT and h["id"] < hand["id"]:
						index += 1
			_add_hand_display(hand, index, container)
			hand_displays[hand["id"]].play_entrance(0.0)


func _clear_highlights() -> void:
	for display: Control in hand_displays.values():
		display.set_highlight(UIConstants.HighlightMode.NONE)
		display.set_selectable(false)


func _set_all_hands_not_selectable() -> void:
	for display: Control in hand_displays.values():
		display.set_selectable(false)
