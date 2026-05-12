# DEAD CODE — not referenced by any scene or script. Ring slots are handled by HandRingSlot in hand_display.gd.
extends HBoxContainer

signal ring_use_requested(ring_type: Enums.RingType)
signal ring_drag_started(ring_type: Enums.RingType)

var ring_slots: Dictionary = {}  # RingType -> RingSlot Control
var _tooltip_panel: Control = null


func _ready() -> void:
	_create_slots()
	GameState.rings_changed.connect(_refresh)
	_refresh()


func _create_slots() -> void:
	for ring_type in Enums.RingType.values():
		var slot := RingSlot.new()
		slot.ring_type = ring_type
		slot.custom_minimum_size = UIConstants.RING_SLOT_SIZE
		slot.ring_drag_started.connect(func(rt: Enums.RingType): ring_drag_started.emit(rt))
		slot.ring_pressed.connect(_on_slot_pressed)
		slot.mouse_entered.connect(_on_slot_hover.bind(ring_type))
		slot.mouse_exited.connect(_on_slot_unhover)
		add_child(slot)
		ring_slots[ring_type] = slot


func _refresh() -> void:
	for ring_type in ring_slots:
		var slot: RingSlot = ring_slots[ring_type]
		var ring = Enums.RING_RESOURCES[ring_type]
		var count: int = GameState.get_ring_count(ring_type)
		var cd: int = GameState.ring_cooldowns.get(ring_type, 0)
		var max_cd: int = ring.cooldown
		var usable: bool = GameState.can_use_ring(ring_type)

		slot.visible = (count > 0)
		slot.update_state(count, cd, max_cd, usable)


func _on_slot_pressed(ring_type: Enums.RingType) -> void:
	ring_use_requested.emit(ring_type)


func _on_slot_hover(ring_type: Enums.RingType) -> void:
	if _tooltip_panel:
		_tooltip_panel.queue_free()

	var ring = Enums.RING_RESOURCES[ring_type]
	var can_use: bool = GameState.can_use_ring(ring_type)
	var reason: String = _get_unusable_reason(ring_type)
	_tooltip_panel = _create_tooltip_panel(ring, ring_type, can_use, reason)
	get_tree().root.add_child(_tooltip_panel)


func _get_unusable_reason(ring_type: Enums.RingType) -> String:
	if GameState.get_ring_count(ring_type) == 0:
		return "You don't own this ring"

	var cd: int = GameState.ring_cooldowns.get(ring_type, 0)
	if cd > 0:
		return "On cooldown for %d more turn%s" % [cd, "s" if cd > 1 else ""]

	var ring_res = Enums.RING_RESOURCES[ring_type]
	var min_fingers: int = ring_res.min_fingers_needed

	var has_ring_on_hand := false
	for hand in GameState.get_living_hands(Enums.Owner.PLAYER):
		for r in hand["rings"]:
			if r == ring_type:
				has_ring_on_hand = true
				if hand["fingers"] >= min_fingers:
					return ""

	if has_ring_on_hand:
		return "Need %d+ fingers on equipped hand" % min_fingers

	return "No hand has this ring equipped"


func _on_slot_unhover() -> void:
	if _tooltip_panel:
		_tooltip_panel.queue_free()
		_tooltip_panel = null


func _create_tooltip_panel(ring: Resource, ring_type: Enums.RingType, can_use: bool, reason: String) -> Control:
	var panel := Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 1000

	var tooltip_width := 240.0
	var tooltip_height := 120.0 if reason != "" else 100.0
	panel.custom_minimum_size = Vector2(tooltip_width, tooltip_height)
	panel.size = Vector2(tooltip_width, tooltip_height)

	var bg_panel := PanelContainer.new()
	bg_panel.custom_minimum_size = Vector2(tooltip_width, tooltip_height)
	bg_panel.size = Vector2(tooltip_width, tooltip_height)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	var border_color: Color = ring.ring_color.lightened(0.3)
	if not can_use:
		border_color = Color(0.5, 0.5, 0.5)
	bg_style.border_color = border_color
	bg_style.set_border_width_all(2)
	bg_style.set_corner_radius_all(8)
	bg_style.set_content_margin_all(10)
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	panel.add_child(bg_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	bg_panel.add_child(vbox)

	var title_label := Label.new()
	title_label.text = ring.ring_name
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", ring.ring_color.lightened(0.2))
	title_label.custom_minimum_size = Vector2(tooltip_width - 20, 0)
	vbox.add_child(title_label)

	var desc_label := Label.new()
	desc_label.text = ring.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size = Vector2(tooltip_width - 20, 45)
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	vbox.add_child(desc_label)

	var info_label := Label.new()
	info_label.text = "Requires: %d+ fingers | CD: %d turns" % [ring.min_fingers_needed, ring.cooldown]
	info_label.add_theme_font_size_override("font_size", 9)
	info_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	vbox.add_child(info_label)

	# Show reason if can't use
	if reason != "":
		var reason_label := Label.new()
		reason_label.text = "⚠ " + reason
		reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		reason_label.custom_minimum_size = Vector2(tooltip_width - 20, 0)
		reason_label.add_theme_font_size_override("font_size", 9)
		reason_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		vbox.add_child(reason_label)
	
	# Position tooltip near cursor, but keep it on screen
	var mouse_pos := get_global_mouse_position()
	var screen_size := get_viewport_rect().size
	var pos := mouse_pos + Vector2(15, 15)
	
	# Clamp to screen bounds
	if pos.x + tooltip_width > screen_size.x:
		pos.x = screen_size.x - tooltip_width - 10
	if pos.y + tooltip_height > screen_size.y:
		pos.y = screen_size.y - tooltip_height - 10
	
	panel.position = pos
	
	return panel


func set_enabled(enabled: bool) -> void:
	if enabled:
		_refresh()
	else:
		for slot: RingSlot in ring_slots.values():
			slot.set_active(false)


# === INNER CLASS: RingSlot ===

class RingSlot extends Control:
	signal ring_drag_started(ring_type: Enums.RingType)
	signal ring_pressed(ring_type: Enums.RingType)

	var ring_type: Enums.RingType = Enums.RingType.ASCLEPIUS
	var count: int = 0
	var cooldown: int = 0
	var max_cooldown: int = 1
	var active: bool = false
	var _hovered: bool = false
	var _dragging := false
	var _drag_offset := Vector2.ZERO
	var _pulse_time := 0.0
	var _debug_printed := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func(): _hovered = true; queue_redraw())
		mouse_exited.connect(func(): _hovered = false; queue_redraw())

	func _process(delta: float) -> void:
		# Pulse active rings to draw attention
		if active and count > 0:
			_pulse_time += delta * 3.0
			queue_redraw()

	func update_state(p_count: int, p_cd: int, p_max_cd: int, p_usable: bool) -> void:
		count = p_count
		cooldown = p_cd
		max_cooldown = p_max_cd
		active = p_usable
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if active else Control.CURSOR_ARROW
		queue_redraw()

	func set_active(p_active: bool) -> void:
		active = p_active
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if active else Control.CURSOR_ARROW
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and active:
				# Only emit ring_drag_started to avoid double state transitions
				ring_drag_started.emit(ring_type)
				accept_event()

	func get_drag_data(_from_position: Vector2) -> Variant:
		return null

	func _draw() -> void:
		var center := size * 0.5
		var radius := UIConstants.RING_SLOT_RADIUS
		var ring_res = Enums.RING_RESOURCES[ring_type]
		var ring_color: Color = ring_res.ring_color

		# Pulsing glow for active rings
		if active and count > 0:
			var pulse := (sin(_pulse_time) + 1.0) * 0.5  # 0 to 1
			var glow_color := ring_color
			glow_color.a = 0.2 + pulse * 0.2
			draw_circle(center, radius + 8, glow_color)

		# Background circle
		var bg := Color(0.1, 0.1, 0.15)
		if active and _hovered:
			bg = bg.lightened(0.25)  # Increased from 0.15
		elif active:
			bg = bg.lightened(0.1)  # Slightly lighter when active
		elif not active:
			bg = UIConstants.COLOR_BUTTON_DISABLED
		draw_circle(center, radius, bg)

		# Border
		var border_col := ring_color if (active or count > 0) else ring_color.darkened(0.6)
		var border_width := 2.5
		if active and _hovered:
			border_col = border_col.lightened(0.4)  # More visible when hovered
			border_width = 3.5  # Thicker border when hovered
		elif active:
			border_col = border_col.lightened(0.2)
			border_width = 3.0  # Slightly thicker when active
		_draw_circle_outline_static(center, radius, border_col, border_width)

		# Cooldown arc overlay
		if cooldown > 0 and max_cooldown > 0:
			var frac := float(cooldown) / float(max_cooldown)
			_draw_cooldown_arc(center, radius - 2, frac, Color(0.1, 0.1, 0.15, 0.7))

		var font := ThemeDB.fallback_font
		var icon: Texture2D = ring_res.ring_icon
		if not _debug_printed:
			_debug_printed = true
			print("[RingSlot] %s — ring_icon fetch: %s" % [ring_res.short_name, "SUCCESS (%s)" % icon.resource_path if icon else "NULL (no icon set)"])
		if icon:
			var icon_color := Color.WHITE if active else Color(0.6, 0.6, 0.6)
			var icon_size := radius * 1.2
			draw_texture_rect(icon, Rect2(center - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size)), false, icon_color)
		else:
			var letter: String = ring_res.ring_letter
			var letter_color := ring_color if count > 0 else ring_color.darkened(0.5)
			if not active and count > 0:
				letter_color = ring_color.darkened(0.3)
			var lw := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			draw_string(font, Vector2(center.x - lw * 0.5, center.y + 8), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, letter_color)

		# Count badge (bottom-right)
		if count > 0:
			var badge_pos := center + Vector2(radius * 0.6, radius * 0.6)
			var badge_radius := 10.0
			draw_circle(badge_pos, badge_radius, Color(0.15, 0.15, 0.2))
			_draw_circle_outline_static(badge_pos, badge_radius, ring_color.darkened(0.2), 1.5)
			var count_str := str(count)
			var cw := font.get_string_size(count_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string(font, Vector2(badge_pos.x - cw * 0.5, badge_pos.y + 4), count_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

		# Cooldown number (center, over icon)
		if cooldown > 0:
			var cd_str := str(cooldown)
			var cd_color := Color(1.0, 0.4, 0.3)
			var cdw := font.get_string_size(cd_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(font, Vector2(center.x - cdw * 0.5, center.y - radius * 0.3), cd_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, cd_color)

	func _draw_circle_outline_static(center: Vector2, radius: float, color: Color, width: float) -> void:
		var segments := 32
		var prev := center + Vector2(radius, 0)
		for i in range(1, segments + 1):
			var angle := TAU * float(i) / float(segments)
			var next_pt := center + Vector2(cos(angle) * radius, sin(angle) * radius)
			draw_line(prev, next_pt, color, width, true)
			prev = next_pt

	func _draw_cooldown_arc(center: Vector2, radius: float, fraction: float, color: Color) -> void:
		# Draw a filled arc from top going clockwise
		if fraction <= 0.0:
			return
		var segments := 32
		var arc_end := int(float(segments) * fraction)
		var points := PackedVector2Array()
		points.append(center)
		for i in range(arc_end + 1):
			var angle := -PI / 2.0 + TAU * float(i) / float(segments)
			points.append(center + Vector2(cos(angle) * radius, sin(angle) * radius))
		if points.size() >= 3:
			draw_colored_polygon(points, color)
