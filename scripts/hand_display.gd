extends Control

signal hand_clicked(hand_id: int)
signal ring_dropped(hand_id: int, ring_type: Enums.RingType)

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

var hand_id: int = -1
var hand_data: Dictionary = {}
var _hand_index: int = 0

var _highlight_mode: UIConstants.HighlightMode = UIConstants.HighlightMode.NONE
var _selectable := false
var _hovered := false

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

func _process(delta: float) -> void:
	var needs_redraw := false

	# Breathing pulse for selectable
	if _highlight_mode == UIConstants.HighlightMode.SELECTABLE:
		_pulse_time += delta * UIConstants.ANIM_PULSE_SPEED * TAU
		needs_redraw = true

	# Hit flash fade
	if _flash_alpha > 0.0:
		_flash_alpha = maxf(0.0, _flash_alpha - delta / UIConstants.ANIM_HIT_FLASH)

	# Entrance animation
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

	# Apply rotation based on position (tilt towards center)
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
	queue_redraw()

func refresh(p_hand_data: Dictionary, index: int) -> void:
	hand_data = p_hand_data
	_hand_index = index
	_death_alpha = 0.0 if hand_data.get("alive", true) else 1.0
	_update_hand_sprite()
	queue_redraw()

func set_highlight(mode: UIConstants.HighlightMode) -> void:
	_highlight_mode = mode
	if mode != UIConstants.HighlightMode.SELECTABLE:
		_pulse_time = 0.0
	queue_redraw()

func set_selectable(enabled: bool) -> void:
	_selectable = enabled
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	queue_redraw()

func play_hit_flash() -> void:
	_flash_alpha = 1.0
	queue_redraw()

	# Add impact scale animation (grow then shrink)
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

func get_drop_preview_lines() -> PackedVector2Array:
	return PackedVector2Array()

func _on_mouse_entered() -> void:
	_hovered = true
	queue_redraw()

func _on_mouse_exited() -> void:
	_hovered = false
	queue_redraw()

# === DRAWING ===

func _draw() -> void:
	var alive: bool = hand_data.get("alive", true)
	var owner: int = hand_data.get("owner", Enums.Owner.PLAYER)
	var owner_color: Color = UIConstants.COLOR_PLAYER if owner == Enums.Owner.PLAYER else UIConstants.COLOR_OPPONENT

	# --- Highlight glow behind sprite ---
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

	# --- Ring indicators (player hands only) ---
	if owner == Enums.Owner.PLAYER:
		var rings: Array = hand_data.get("rings", [])
		if rings.size() > 0:
			var hand_pos := _get_hand_position(owner, _hand_index)
			var is_left_hand := (hand_pos == HandPosition.LEFT)

			for ring_type in rings:
				var ring_res = Enums.RING_RESOURCES[ring_type as Enums.RingType]
				var finger_group: String = ring_res.finger_group

				var angle_deg: float
				if is_left_hand:
					angle_deg = UIConstants.RING_ANGLES_LEFT.get(finger_group, 30.0)
				else:
					angle_deg = UIConstants.RING_ANGLES_RIGHT.get(finger_group, 150.0)

				var angle_rad := deg_to_rad(angle_deg)
				var ring_pos := sprite_center + Vector2(
					cos(angle_rad) * UIConstants.RING_INDICATOR_DISTANCE,
					-sin(angle_rad) * UIConstants.RING_INDICATOR_DISTANCE
				)

				var ring_color: Color = ring_res.ring_color
				if not alive:
					ring_color = ring_color.darkened(0.5)

				draw_circle(ring_pos, UIConstants.RING_INDICATOR_RADIUS, ring_color.darkened(0.6))
				_draw_circle_outline(ring_pos, UIConstants.RING_INDICATOR_RADIUS, ring_color, 2.0)

				var letter: String = ring_res.ring_letter
				var lw := UIConstants.FONT_BODY_BOLD.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
				draw_string(UIConstants.FONT_BODY_BOLD, Vector2(ring_pos.x - lw * 0.5, ring_pos.y + 5), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ring_color.lightened(0.3))


func _draw_finger_dots(center: Vector2, count: int, owner_color: Color) -> void:
	var pattern: Array = UIConstants.DOT_PATTERNS.get(count, [])
	for offset: Vector2 in pattern:
		var pos := center + offset * UIConstants.DOT_AREA_RADIUS
		# Outer glow
		var glow_color := owner_color
		glow_color.a = 0.3
		draw_circle(pos, UIConstants.DOT_RADIUS + 4.0, glow_color)
		# Main dot
		draw_circle(pos, UIConstants.DOT_RADIUS, UIConstants.COLOR_DOT_DEFAULT)
		# Inner colored ring
		var ring_color := owner_color.lightened(0.1)
		_draw_circle_outline(pos, UIConstants.DOT_RADIUS, ring_color, 2.0)


func _draw_rounded_rect(rect: Rect2, color: Color, radius: float) -> void:
	# Draw rounded rectangle using draw_rect with no built-in rounding - approximate with polygon
	var points := _rounded_rect_points(rect, radius)
	draw_colored_polygon(points, color)


func _draw_rounded_rect_outline(rect: Rect2, color: Color, radius: float, width: float) -> void:
	var points := _rounded_rect_points(rect, radius)
	points.append(points[0])  # Close the loop
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], color, width, true)


func _rounded_rect_points(rect: Rect2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var corners := [
		[rect.position + Vector2(r, 0), rect.position, rect.position + Vector2(0, r)],                                                          # top-left
		[rect.position + Vector2(rect.size.x - r, 0), rect.position + Vector2(rect.size.x, 0), rect.position + Vector2(rect.size.x, r)],       # top-right
		[rect.end + Vector2(0, -r), rect.end, rect.end + Vector2(-r, 0)],                                                                       # bottom-right
		[rect.position + Vector2(0, rect.size.y - r), rect.position + Vector2(0, rect.size.y), rect.position + Vector2(r, rect.size.y)],       # bottom-left
	]
	var segments := 6
	for corner in corners:
		var start_angle: float
		var cx: float
		var cy: float
		if corner == corners[0]:  # top-left
			cx = rect.position.x + r
			cy = rect.position.y + r
			start_angle = PI
		elif corner == corners[1]:  # top-right
			cx = rect.position.x + rect.size.x - r
			cy = rect.position.y + r
			start_angle = -PI / 2.0
		elif corner == corners[2]:  # bottom-right
			cx = rect.position.x + rect.size.x - r
			cy = rect.position.y + rect.size.y - r
			start_angle = 0.0
		else:  # bottom-left
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
