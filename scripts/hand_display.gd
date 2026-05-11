extends Control

signal hand_clicked(hand_id: int)
signal ring_activated(hand_id: int, ring_type: Enums.RingType)

@onready var hand_sprite: TextureRect = $MarginContainer/HandSprite


enum HandPosition {
	LEFT,
	RIGHT,
	MIDDLE
}

const HAND_SPRITES := {
	Enums.Owner.PLAYER: {
		HandPosition.LEFT: {
			"flip_h": false,
			"textures": {
				1: preload("res://assets/player sprites/player_1.png"),
				2: preload("res://assets/player sprites/player_2.png"),
				3: preload("res://assets/player sprites/player_3.png"),
				4: preload("res://assets/player sprites/player_4.png"),
				0: preload("res://assets/player sprites/player_dead.png"),
			}
		},
		HandPosition.RIGHT: {
			"flip_h": true,
			"textures": {
				1: preload("res://assets/player sprites/player_1.png"),
				2: preload("res://assets/player sprites/player_2.png"),
				3: preload("res://assets/player sprites/player_3.png"),
				4: preload("res://assets/player sprites/player_4.png"),
				0: preload("res://assets/player sprites/player_dead.png"),
			}
		}
	},

	Enums.Owner.OPPONENT: {
		HandPosition.LEFT: {
			"flip_h": false,
			"textures": {
				0: preload("res://assets/charon sprites/charon_left/charon_dead.png"),
				1: preload("res://assets/charon sprites/charon_left/charon_1.png"),
				2: preload("res://assets/charon sprites/charon_left/charon_2.png"),
				3: preload("res://assets/charon sprites/charon_left/charon_3.png"),
				4: preload("res://assets/charon sprites/charon_left/charon_4.png"),
			}
		},
		HandPosition.MIDDLE: {
			"flip_h": false,
			"textures": {
				0: preload("res://assets/charon sprites/charon_middle/charon_middle_dead.png"),
				1: preload("res://assets/charon sprites/charon_middle/charon_middle_1.png"),
				2: preload("res://assets/charon sprites/charon_middle/charon_middle_2.png"),
				3: preload("res://assets/charon sprites/charon_middle/charon_middle_3.png"),
				4: preload("res://assets/charon sprites/charon_middle/charon_middle_4.png"),
			}
		},
		HandPosition.RIGHT: {
			"flip_h": false,
			"textures": {
				0: preload("res://assets/charon sprites/charon_right/charon_right_dead.png"),
				1: preload("res://assets/charon sprites/charon_right/charon_right_1.png"),
				2: preload("res://assets/charon sprites/charon_right/charon_right_2.png"),
				3: preload("res://assets/charon sprites/charon_right/charon_right_3.png"),
				4: preload("res://assets/charon sprites/charon_right/charon_right_4.png"),
			}
		}
	}
}

# Ring slot layout — arc around the hand edge
const RING_SLOT_RADIUS := 22.0
const RING_ARC_RADIUS := 150.0
const FINGER_GROUPS := ["INDEX", "MIDDLE", "RING", "PINKY"]
const ANIM_FAN_DURATION := 0.18
const ANIM_STACK_DURATION := 0.12

var hand_id: int = -1
var hand_data: Dictionary = {}
var _hand_index: int = 0

var _highlight_mode: UIConstants.HighlightMode = UIConstants.HighlightMode.NONE
var _selectable := false
var _hovered := false
var _slot_hovered_count := 0
var _rings_fanned := false
var _rings_locked_open := false
var _ring_slots: Array = []

# Animation state
var _pulse_time := 0.0
var _flash_alpha := 0.0
var _death_alpha := 0.0
var _entrance_progress := 1.0  # 1.0 = fully visible

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	custom_minimum_size = UIConstants.HAND_SIZE
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_create_ring_slots()
	GameState.rings_changed.connect(_update_ring_slot_data)

func _process(delta: float) -> void:
	var needs_redraw := false

	if _highlight_mode == UIConstants.HighlightMode.SELECTABLE:
		_pulse_time += delta * UIConstants.ANIM_PULSE_SPEED * TAU
		needs_redraw = true

	if _flash_alpha > 0.0:
		_flash_alpha = maxf(0.0, _flash_alpha - delta / UIConstants.ANIM_HIT_FLASH)

	if _entrance_progress < 1.0:
		_entrance_progress = minf(1.0, _entrance_progress + delta / UIConstants.ANIM_ENTRANCE_DURATION)
		needs_redraw = true

	_update_sprite_modulate()

	if needs_redraw:
		queue_redraw()


func _update_sprite_modulate() -> void:
	if hand_sprite == null:
		return
	var mod := Color.WHITE
	match _highlight_mode:
		UIConstants.HighlightMode.SELECTABLE:
			var pulse := (sin(_pulse_time) + 1.0) * 0.5
			var brightness := 1.0 + pulse * 0.15
			mod = Color(brightness, brightness, brightness + 0.05)
			if _hovered:
				mod = Color(1.3, 1.3, 1.35)
		UIConstants.HighlightMode.SOURCE:
			mod = Color(1.2, 1.15, 0.8)
		UIConstants.HighlightMode.TARGET:
			mod = Color(1.1, 1.1, 1.15)
			if _hovered:
				mod = Color(1.3, 1.3, 1.35)
	if _death_alpha > 0.0:
		mod = mod.lerp(Color(0.4, 0.4, 0.45), _death_alpha)
	if _flash_alpha > 0.0:
		mod = mod.lerp(Color(2.5, 2.5, 2.5), _flash_alpha * 0.5)
	hand_sprite.self_modulate = mod

func _get_hand_position(owner: int, index: int) -> int:
	if owner == Enums.Owner.PLAYER:
		return HandPosition.LEFT if index == 0 else HandPosition.RIGHT
	else:
		match index:
			0: return HandPosition.LEFT
			1: return HandPosition.MIDDLE
			2: return HandPosition.RIGHT
	return HandPosition.LEFT

func _update_hand_sprite() -> void:
	if hand_sprite == null:
		push_error("HandSprite is null — check node path")
		return
	var alive = hand_data.get("alive", true)
	var fingers = hand_data.get("fingers", 0)
	var owner : int = hand_data.get("owner", Enums.Owner.PLAYER)

	var pos := _get_hand_position(owner, _hand_index)
	var entry : Dictionary = HAND_SPRITES[owner][pos]

	hand_sprite.flip_h = entry["flip_h"]
	hand_sprite.flip_v = (owner == Enums.Owner.OPPONENT)

	var tex_key = fingers if alive else 0
	hand_sprite.texture = entry["textures"].get(tex_key)

	var tilt_angle := 0.0
	match pos:
		HandPosition.LEFT:
			tilt_angle = -8.0 if owner == Enums.Owner.PLAYER else 8.0
		HandPosition.RIGHT:
			tilt_angle = 8.0 if owner == Enums.Owner.PLAYER else -8.0
		HandPosition.MIDDLE:
			tilt_angle = 0.0
	hand_sprite.rotation_degrees = tilt_angle


func setup(p_hand_id: int, p_hand_data: Dictionary, index: int) -> void:
	hand_id = p_hand_id
	hand_data = p_hand_data
	_hand_index = index
	_death_alpha = 0.0 if hand_data.get("alive", true) else 1.0
	_update_hand_sprite()
	_update_slot_positions()
	_update_ring_slot_data()
	queue_redraw()

func refresh(p_hand_data: Dictionary, index: int) -> void:
	hand_data = p_hand_data
	_hand_index = index
	_death_alpha = 0.0 if hand_data.get("alive", true) else 1.0
	_update_hand_sprite()
	_update_slot_positions()
	_update_ring_slot_data()
	queue_redraw()

func set_highlight(mode: UIConstants.HighlightMode) -> void:
	_highlight_mode = mode
	if mode != UIConstants.HighlightMode.SELECTABLE:
		_pulse_time = 0.0
	_rings_locked_open = (mode == UIConstants.HighlightMode.SOURCE)
	if _rings_locked_open:
		_fan_rings()
	queue_redraw()

func set_selectable(enabled: bool) -> void:
	_selectable = enabled
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	queue_redraw()

func set_rings_interactable(enabled: bool) -> void:
	for slot in _ring_slots:
		slot.set_interactable(enabled)

func play_hit_flash() -> void:
	_flash_alpha = 1.0
	queue_redraw()

	if hand_sprite:
		var original_scale := hand_sprite.scale
		var tw := create_tween()
		tw.set_ease(Tween.EASE_OUT)
		tw.set_trans(Tween.TRANS_ELASTIC)
		tw.tween_property(hand_sprite, "scale", original_scale * 1.25, 0.15)
		tw.tween_property(hand_sprite, "scale", original_scale, 0.2)

func play_death() -> void:
	var tw := create_tween()
	tw.tween_property(self, "_death_alpha", 1.0, UIConstants.ANIM_DEATH_FADE)

func play_entrance(delay: float) -> void:
	_entrance_progress = 0.0
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(self, "modulate:a", 1.0, UIConstants.ANIM_ENTRANCE_DURATION)
	tw.parallel().tween_property(self, "_entrance_progress", 1.0, UIConstants.ANIM_ENTRANCE_DURATION)

func play_hit_toward(target_global_pos: Vector2) -> void:
	var original_pos := position
	var my_center := global_position + size * 0.5
	var direction := (target_global_pos - my_center).normalized()
	var distance := (target_global_pos - my_center).length()
	var lunge_distance := minf(distance * 0.5, 120.0)
	var lunge_pos := original_pos + direction * lunge_distance
	var tw := create_tween()
	tw.tween_property(self, "position", lunge_pos, UIConstants.ANIM_HIT_LUNGE_OUT).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "position", original_pos, UIConstants.ANIM_HIT_LUNGE_BACK).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await tw.finished

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and _selectable:
			hand_clicked.emit(hand_id)
			accept_event()

func _on_mouse_entered() -> void:
	_hovered = true
	if hand_data.get("owner", Enums.Owner.PLAYER) == Enums.Owner.PLAYER:
		_fan_rings()
	queue_redraw()

func _on_mouse_exited() -> void:
	_hovered = false
	queue_redraw()

# === RING SLOT MANAGEMENT ===

func _is_left_side() -> bool:
	var owner: int = hand_data.get("owner", Enums.Owner.PLAYER)
	return _get_hand_position(owner, _hand_index) != HandPosition.RIGHT

func _get_sprite_center() -> Vector2:
	return Vector2(UIConstants.HAND_SIZE.x * 0.5, 28.0 + (UIConstants.HAND_SIZE.y - 48.0) * 0.5)

func _get_stack_center() -> Vector2:
	var c := _get_sprite_center()
	var angle_rad := deg_to_rad(180.0 if _is_left_side() else 0.0)
	return c + Vector2(cos(angle_rad) * RING_ARC_RADIUS, -sin(angle_rad) * RING_ARC_RADIUS)

func _get_fan_center(slot_index: int) -> Vector2:
	var c := _get_sprite_center()
	# Left side: 120°→240° top-to-bottom; right side: 60°→-60° top-to-bottom
	var angle_deg := 120.0 + float(slot_index) * 40.0 if _is_left_side() else 60.0 - float(slot_index) * 40.0
	return c + Vector2(cos(deg_to_rad(angle_deg)) * RING_ARC_RADIUS, -sin(deg_to_rad(angle_deg)) * RING_ARC_RADIUS)

func _create_ring_slots() -> void:
	for i in 4:
		var slot := HandRingSlot.new()
		slot.visible = false
		slot.modulate.a = 0.4
		slot.mouse_entered.connect(_on_slot_hover_enter)
		slot.mouse_exited.connect(_on_slot_hover_exit)
		slot.clicked.connect(func(rt: Enums.RingType): ring_activated.emit(hand_id, rt))
		add_child(slot)
		_ring_slots.append(slot)

func _update_slot_positions() -> void:
	var is_player: bool = hand_data.get("owner", Enums.Owner.PLAYER) == Enums.Owner.PLAYER
	for i in 4:
		_ring_slots[i].position = _get_fan_center(i) - Vector2(RING_SLOT_RADIUS, RING_SLOT_RADIUS)
		_ring_slots[i].visible = is_player
		_ring_slots[i].modulate.a = 1.0
	_rings_fanned = true

func _update_ring_slot_data() -> void:
	if _ring_slots.is_empty():
		return
	if hand_data.get("owner", Enums.Owner.PLAYER) != Enums.Owner.PLAYER:
		return
	var rings: Array = hand_data.get("rings", [])
	for i in 4:
		var group: String = FINGER_GROUPS[i]
		var found: int = -1
		for r in rings:
			if Enums.RING_RESOURCES[r as Enums.RingType].finger_group == group:
				found = r
				break
		var slot: HandRingSlot = _ring_slots[i]
		if found >= 0:
			var rt := found as Enums.RingType
			slot.set_ring(rt, GameState.ring_cooldowns.get(rt, 0), Enums.RING_RESOURCES[rt].cooldown)
		else:
			slot.set_empty()

func _fan_rings() -> void:
	if _rings_fanned:
		return
	_rings_fanned = true
	for i in _ring_slots.size():
		var target := _get_fan_center(i) - Vector2(RING_SLOT_RADIUS, RING_SLOT_RADIUS)
		var tw := create_tween()
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(_ring_slots[i], "position", target, ANIM_FAN_DURATION)
		tw.parallel().tween_property(_ring_slots[i], "modulate:a", 1.0, ANIM_FAN_DURATION)

func _stack_rings() -> void:
	if not _rings_fanned:
		return
	_rings_fanned = false
	var stack_pos := _get_stack_center() - Vector2(RING_SLOT_RADIUS, RING_SLOT_RADIUS)
	for slot in _ring_slots:
		var tw := create_tween()
		tw.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(slot, "position", stack_pos, ANIM_STACK_DURATION)
		tw.parallel().tween_property(slot, "modulate:a", 0.4, ANIM_STACK_DURATION)

func _on_slot_hover_enter() -> void:
	_slot_hovered_count += 1

func _on_slot_hover_exit() -> void:
	_slot_hovered_count = maxi(0, _slot_hovered_count - 1)

func _check_hover_collapse() -> void:
	if not _hovered and _slot_hovered_count == 0 and not _rings_locked_open:
		_stack_rings()

# === DRAWING ===

func _draw() -> void:
	var owner: int = hand_data.get("owner", Enums.Owner.PLAYER)
	var owner_color: Color = UIConstants.COLOR_PLAYER if owner == Enums.Owner.PLAYER else UIConstants.COLOR_OPPONENT

	var sprite_center := Vector2(size.x * 0.5, 28 + (size.y - 48) * 0.5)
	var glow_radius := 65.0
	match _highlight_mode:
		UIConstants.HighlightMode.SELECTABLE:
			var pulse := (sin(_pulse_time) + 1.0) * 0.5
			var glow_color := owner_color
			glow_color.a = 0.12 + pulse * 0.12
			draw_circle(sprite_center, glow_radius, glow_color)
		UIConstants.HighlightMode.SOURCE:
			var glow_color := UIConstants.COLOR_HIGHLIGHT_SOURCE
			glow_color.a = 0.3
			draw_circle(sprite_center, glow_radius, glow_color)
		UIConstants.HighlightMode.TARGET:
			var glow_color := owner_color.lightened(0.2)
			if _hovered:
				glow_color.a = 0.3
				draw_circle(sprite_center, glow_radius + 5, glow_color)
			else:
				glow_color.a = 0.15
				draw_circle(sprite_center, glow_radius, glow_color)


func _draw_finger_dots(center: Vector2, count: int, owner_color: Color) -> void:
	var pattern: Array = UIConstants.DOT_PATTERNS.get(count, [])
	for offset: Vector2 in pattern:
		var pos := center + offset * UIConstants.DOT_AREA_RADIUS
		var glow_color := owner_color
		glow_color.a = 0.3
		draw_circle(pos, UIConstants.DOT_RADIUS + 4.0, glow_color)
		draw_circle(pos, UIConstants.DOT_RADIUS, UIConstants.COLOR_DOT_DEFAULT)
		var ring_color := owner_color.lightened(0.1)
		_draw_circle_outline(pos, UIConstants.DOT_RADIUS, ring_color, 2.0)


func _draw_rounded_rect(rect: Rect2, color: Color, radius: float) -> void:
	var points := _rounded_rect_points(rect, radius)
	draw_colored_polygon(points, color)


func _draw_rounded_rect_outline(rect: Rect2, color: Color, radius: float, width: float) -> void:
	var points := _rounded_rect_points(rect, radius)
	points.append(points[0])
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], color, width, true)


func _rounded_rect_points(rect: Rect2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var corners := [
		[rect.position + Vector2(r, 0), rect.position, rect.position + Vector2(0, r)],
		[rect.position + Vector2(rect.size.x - r, 0), rect.position + Vector2(rect.size.x, 0), rect.position + Vector2(rect.size.x, r)],
		[rect.end + Vector2(0, -r), rect.end, rect.end + Vector2(-r, 0)],
		[rect.position + Vector2(0, rect.size.y - r), rect.position + Vector2(0, rect.size.y), rect.position + Vector2(r, rect.size.y)],
	]
	var segments := 6
	for corner in corners:
		var start_angle: float
		var cx: float
		var cy: float
		if corner == corners[0]:
			cx = rect.position.x + r
			cy = rect.position.y + r
			start_angle = PI
		elif corner == corners[1]:
			cx = rect.position.x + rect.size.x - r
			cy = rect.position.y + r
			start_angle = -PI / 2.0
		elif corner == corners[2]:
			cx = rect.position.x + rect.size.x - r
			cy = rect.position.y + rect.size.y - r
			start_angle = 0.0
		else:
			cx = rect.position.x + r
			cy = rect.position.y + rect.size.y - r
			start_angle = PI / 2.0
		for j in range(segments + 1):
			var angle: float = start_angle + (PI / 2.0) * (float(j) / float(segments))
			points.append(Vector2(cx + cos(angle) * r, cy + sin(angle) * r))
	return points


func _draw_circle_outline(center: Vector2, radius: float, color: Color, width: float) -> void:
	var segments := 24
	var prev := center + Vector2(radius, 0)
	for i in range(1, segments + 1):
		var angle := TAU * float(i) / float(segments)
		var next := center + Vector2(cos(angle) * radius, sin(angle) * radius)
		draw_line(prev, next, color, width, true)
		prev = next


func _get_text_width(text: String, font_size: int) -> float:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


# === RING SLOT ===

class HandRingSlot extends Control:
	signal clicked(ring_type: Enums.RingType)

	const RADIUS := 22.0

	var has_ring := false
	var ring_type: Enums.RingType = Enums.RingType.ASCLEPIUS
	var cooldown := 0
	var max_cooldown := 1
	var interactable := false
	var _hovered := false
	var _pulse_time := 0.0
	var _tooltip: Control = null

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
		size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
		tree_exiting.connect(_remove_tooltip)

	func _process(delta: float) -> void:
		if interactable and has_ring and cooldown == 0:
			_pulse_time += delta * 3.0
			queue_redraw()

		# Manual hit-test: bypasses GUI routing so ActionBar can't block us
		var now_hovered := false
		if visible and is_inside_tree():
			var mouse_pos := get_global_mouse_position()
			var circle_center := global_position + Vector2(RADIUS, RADIUS)
			now_hovered = mouse_pos.distance_to(circle_center) <= RADIUS

		if now_hovered != _hovered:
			_hovered = now_hovered
			if _hovered and has_ring:
				_show_tooltip()
			else:
				_remove_tooltip()
			queue_redraw()

	func set_ring(p_ring_type: Enums.RingType, p_cd: int, p_max_cd: int) -> void:
		has_ring = true
		ring_type = p_ring_type
		cooldown = p_cd
		max_cooldown = maxi(1, p_max_cd)
		queue_redraw()

	func set_empty() -> void:
		has_ring = false
		queue_redraw()

	func set_interactable(p_interactable: bool) -> void:
		interactable = p_interactable
		queue_redraw()

	func _show_tooltip() -> void:
		_remove_tooltip()
		var ring_res = Enums.RING_RESOURCES[ring_type]
		var ring_color: Color = ring_res.ring_color
		var is_cooling := cooldown > 0

		var w := 220.0
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.z_index = 1000
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.07, 0.07, 0.11, 0.96)
		style.border_color = ring_color.lightened(0.2) if not is_cooling else Color(0.45, 0.45, 0.5)
		style.set_border_width_all(2)
		style.set_corner_radius_all(7)
		style.set_content_margin_all(9)
		panel.add_theme_stylebox_override("panel", style)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		panel.add_child(vbox)

		var name_label := Label.new()
		name_label.text = ring_res.ring_name
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", ring_color.lightened(0.2))
		vbox.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = ring_res.description
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_label.custom_minimum_size = Vector2(w - 18.0, 0)
		desc_label.add_theme_font_size_override("font_size", 10)
		desc_label.add_theme_color_override("font_color", Color(0.88, 0.88, 0.93))
		vbox.add_child(desc_label)

		var info_label := Label.new()
		info_label.text = "Needs %d+ fingers  |  CD: %d turns" % [ring_res.min_fingers_needed, ring_res.cooldown]
		info_label.add_theme_font_size_override("font_size", 9)
		info_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		vbox.add_child(info_label)

		if is_cooling:
			var cd_label := Label.new()
			cd_label.text = "On cooldown — %d turn%s left" % [cooldown, "s" if cooldown > 1 else ""]
			cd_label.add_theme_font_size_override("font_size", 9)
			cd_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
			vbox.add_child(cd_label)

		# Position near cursor, clamped to viewport
		var vp_size := get_viewport_rect().size
		var mouse_pos := get_global_mouse_position()
		panel.size = Vector2(w, 0)
		const ESTIMATED_H := 140.0
		var pos := mouse_pos + Vector2(14.0, 14.0)
		if pos.y + ESTIMATED_H > vp_size.y:
			pos.y = mouse_pos.y - ESTIMATED_H - 6.0
		pos.y = maxf(4.0, pos.y)
		if pos.x + w > vp_size.x:
			pos.x = vp_size.x - w - 8.0
		panel.position = pos

		get_tree().root.add_child(panel)
		_tooltip = panel

	func _remove_tooltip() -> void:
		if _tooltip != null:
			_tooltip.queue_free()
			_tooltip = null

	func _input(event: InputEvent) -> void:
		if not _hovered:
			return
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				if interactable and has_ring and cooldown == 0:
					clicked.emit(ring_type)
					get_viewport().set_input_as_handled()

	func _draw() -> void:
		var center := Vector2(RADIUS, RADIUS)

		if not has_ring:
			_draw_outline(center, RADIUS - 2.0, Color(0.4, 0.4, 0.5, 0.35), 1.5)
			return

		var ring_res = Enums.RING_RESOURCES[ring_type]
		var ring_color: Color = ring_res.ring_color
		var is_cooling := cooldown > 0
		var display_color := ring_color if not is_cooling else Color(0.35, 0.35, 0.4)

		if interactable and not is_cooling:
			var pulse := (sin(_pulse_time) + 1.0) * 0.5
			var glow := ring_color
			glow.a = 0.15 + pulse * 0.15
			draw_circle(center, RADIUS + 7.0, glow)

		var bg := Color(0.08, 0.08, 0.12)
		if _hovered and interactable and not is_cooling:
			bg = bg.lightened(0.18)
		draw_circle(center, RADIUS, bg)

		var border := display_color
		var bw := 2.0
		if _hovered and interactable and not is_cooling:
			border = border.lightened(0.35)
			bw = 2.5
		elif interactable and not is_cooling:
			border = border.lightened(0.1)
		_draw_outline(center, RADIUS, border, bw)

		if is_cooling:
			_draw_cooldown_arc(center, RADIUS - 2.0, float(cooldown) / float(max_cooldown), Color(0.08, 0.08, 0.12, 0.72))

		var letter: String = ring_res.ring_letter
		var font := ThemeDB.fallback_font
		if not is_cooling:
			var lw := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(font, Vector2(center.x - lw * 0.5, center.y + 6.0), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, display_color.lightened(0.1))
		else:
			# Greyed letter sits behind the number as a subtle hint
			var lw := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(font, Vector2(center.x - lw * 0.5, center.y + 6.0), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.42, 0.42, 0.48, 0.55))
			# Large Norse number fills the circle
			var cd_str := str(cooldown)
			var cd_font := UIConstants.FONT_TITLE
			const CD_SIZE := 28
			var cdw := cd_font.get_string_size(cd_str, HORIZONTAL_ALIGNMENT_LEFT, -1, CD_SIZE).x
			var cd_ascent := cd_font.get_ascent(CD_SIZE)
			draw_string(cd_font, Vector2(center.x - cdw * 0.5, center.y + cd_ascent * 0.45), cd_str, HORIZONTAL_ALIGNMENT_LEFT, -1, CD_SIZE, Color(0.95, 0.95, 1.0, 0.95))

	func _draw_outline(center: Vector2, radius: float, color: Color, width: float) -> void:
		var segs := 24
		var prev := center + Vector2(radius, 0.0)
		for i in range(1, segs + 1):
			var angle := TAU * float(i) / float(segs)
			var nxt := center + Vector2(cos(angle) * radius, sin(angle) * radius)
			draw_line(prev, nxt, color, width, true)
			prev = nxt

	func _draw_cooldown_arc(center: Vector2, radius: float, fraction: float, color: Color) -> void:
		if fraction <= 0.0:
			return
		var segs := 32
		var arc_end := int(float(segs) * fraction)
		var pts := PackedVector2Array()
		pts.append(center)
		for i in range(arc_end + 1):
			var angle := -PI * 0.5 + TAU * float(i) / float(segs)
			pts.append(center + Vector2(cos(angle) * radius, sin(angle) * radius))
		if pts.size() >= 3:
			draw_colored_polygon(pts, color)
