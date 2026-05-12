extends Control

signal ring_selected(ring_type: Enums.RingType)
signal selection_skipped()
signal replace_confirmed
signal keep_confirmed

# Fixed panel dimensions
const PANEL_SIZE := Vector2(560, 420)
const CARD_SIZE := Vector2(230, 250)
const CARD_GAP := 28.0
const CORNER_RADIUS := 16.0
const CARD_CORNER_RADIUS := 12.0
const ICON_RADIUS := 24.0
const SKIP_SIZE := Vector2(100, 34)

# State
var _offered_rings: Array = []
var _fade_alpha := 0.0
var _hovered_card := -1
var _hovered_skip := false
var _card_rects: Array[Rect2] = []
var _skip_rect := Rect2()
var _panel_rect := Rect2()

var _conflict_mode := false
var _hovered_keep := false
var _hovered_replace := false
var _keep_rect := Rect2()
var _replace_rect := Rect2()

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func open(offered: Array) -> void:
	_offered_rings = offered
	_hovered_card = -1
	_hovered_skip = false
	_build_layout()
	visible = true
	_fade_alpha = 0.0
	var tw := create_tween()
	tw.tween_property(self, "_fade_alpha", 1.0, 0.25)
	queue_redraw()


func close() -> void:
	_conflict_mode = false
	var tw := create_tween()
	tw.tween_property(self, "_fade_alpha", 0.0, 0.2)
	tw.tween_callback(_on_fade_done)


func open_replace_prompt(existing: Enums.RingType, new_ring: Enums.RingType) -> void:
	_conflict_mode = true
	_offered_rings = [existing, new_ring]
	_hovered_card = -1
	_hovered_keep = false
	_hovered_replace = false
	_build_layout()
	_build_conflict_buttons()
	visible = true
	_fade_alpha = 0.0
	var tw := create_tween()
	tw.tween_property(self, "_fade_alpha", 1.0, 0.25)
	queue_redraw()


func _build_conflict_buttons() -> void:
	const BTN_W := 150.0
	const BTN_H := 34.0
	const GAP := 16.0
	var cx := _panel_rect.position.x + PANEL_SIZE.x * 0.5
	var btn_y := _panel_rect.position.y + PANEL_SIZE.y - 52.0
	_keep_rect = Rect2(Vector2(cx - BTN_W - GAP * 0.5, btn_y), Vector2(BTN_W, BTN_H))
	_replace_rect = Rect2(Vector2(cx + GAP * 0.5, btn_y), Vector2(BTN_W, BTN_H))


func _on_fade_done() -> void:
	visible = false
	_offered_rings.clear()
	_card_rects.clear()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _build_layout() -> void:
	var panel_pos := (size - PANEL_SIZE) * 0.5
	_panel_rect = Rect2(panel_pos, PANEL_SIZE)

	var card_count: int = _offered_rings.size()
	var cards_total: float = card_count * CARD_SIZE.x + maxi(0, card_count - 1) * CARD_GAP
	var cards_x: float = panel_pos.x + (PANEL_SIZE.x - cards_total) * 0.5
	var cards_y := panel_pos.y + 90.0

	_card_rects.clear()
	for i in card_count:
		var cx := cards_x + i * (CARD_SIZE.x + CARD_GAP)
		_card_rects.append(Rect2(Vector2(cx, cards_y), CARD_SIZE))

	_skip_rect = Rect2(
		Vector2(panel_pos.x + (PANEL_SIZE.x - SKIP_SIZE.x) * 0.5, panel_pos.y + PANEL_SIZE.y - 52),
		SKIP_SIZE
	)


# === INPUT ===

func _gui_input(event: InputEvent) -> void:
	if not visible or _fade_alpha < 0.9:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if _conflict_mode:
				if _keep_rect.has_point(mb.position):
					close()
					keep_confirmed.emit()
					accept_event()
					return
				if _replace_rect.has_point(mb.position):
					close()
					replace_confirmed.emit()
					accept_event()
					return
			else:
				for i in _card_rects.size():
					if _card_rects[i].has_point(mb.position):
						var ring_type: Enums.RingType = _offered_rings[i] as Enums.RingType
						close()
						ring_selected.emit(ring_type)
						accept_event()
						return
				if _skip_rect.has_point(mb.position):
					close()
					selection_skipped.emit()
					accept_event()
					return
		accept_event()

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _conflict_mode:
			var old_keep := _hovered_keep
			var old_replace := _hovered_replace
			var old_card := _hovered_card
			_hovered_keep = _keep_rect.has_point(mm.position)
			_hovered_replace = _replace_rect.has_point(mm.position)
			_hovered_card = -1
			for i in _card_rects.size():
				if _card_rects[i].has_point(mm.position):
					_hovered_card = i
					break
			if old_keep != _hovered_keep or old_replace != _hovered_replace or old_card != _hovered_card:
				queue_redraw()
		else:
			var old_card := _hovered_card
			var old_skip := _hovered_skip
			_hovered_card = -1
			_hovered_skip = false
			for i in _card_rects.size():
				if _card_rects[i].has_point(mm.position):
					_hovered_card = i
					break
			_hovered_skip = _skip_rect.has_point(mm.position)
			if old_card != _hovered_card or old_skip != _hovered_skip:
				queue_redraw()
		accept_event()


# === DRAWING ===

func _draw() -> void:
	if not visible:
		return

	# Dark backdrop
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.05, 0.88 * _fade_alpha))

	if _fade_alpha < 0.01:
		return

	var font := UIConstants.FONT_BODY

	# Panel background
	_draw_rounded_rect(_panel_rect, Color(0.07, 0.07, 0.11, 0.97 * _fade_alpha), CORNER_RADIUS)

	# Outer border (subtle)
	_draw_rounded_rect_outline(_panel_rect, Color(0.25, 0.25, 0.35, 0.5 * _fade_alpha), CORNER_RADIUS, 2.0)

	# Inner glow border (very subtle lighter line)
	var inner := Rect2(_panel_rect.position + Vector2(1, 1), _panel_rect.size - Vector2(2, 2))
	_draw_rounded_rect_outline(inner, Color(0.2, 0.2, 0.28, 0.15 * _fade_alpha), CORNER_RADIUS - 1, 1.0)

	# Title
	var title := "RING CONFLICT" if _conflict_mode else "CHOOSE A RING"
	var title_size := 26
	var title_w := UIConstants.FONT_TITLE.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	var title_color := Color(0.88, 0.9, 0.96, _fade_alpha)
	draw_string(UIConstants.FONT_TITLE, Vector2(_panel_rect.position.x + (_panel_rect.size.x - title_w) * 0.5, _panel_rect.position.y + 35), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, title_color)

	# Decorative divider under title
	var div_y := _panel_rect.position.y + 47
	var div_margin := 60.0
	var div_center_x := _panel_rect.position.x + _panel_rect.size.x * 0.5
	# Center bright segment
	draw_line(
		Vector2(div_center_x - 80, div_y),
		Vector2(div_center_x + 80, div_y),
		Color(0.4, 0.4, 0.55, 0.5 * _fade_alpha), 1.0
	)
	# Fading left segment
	draw_line(
		Vector2(_panel_rect.position.x + div_margin, div_y),
		Vector2(div_center_x - 80, div_y),
		Color(0.3, 0.3, 0.4, 0.2 * _fade_alpha), 1.0
	)
	# Fading right segment
	draw_line(
		Vector2(div_center_x + 80, div_y),
		Vector2(_panel_rect.end.x - div_margin, div_y),
		Color(0.3, 0.3, 0.4, 0.2 * _fade_alpha), 1.0
	)

	# Subtitle
	var subtitle: String
	if _conflict_mode:
		var existing_res = Enums.RING_RESOURCES[_offered_rings[0] as Enums.RingType]
		subtitle = existing_res.finger_group + " finger already has a ring — keep it or replace?"
	else:
		subtitle = "You destroyed one of Charon's hands!"
	var sub_size := 13
	var sub_w := font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size).x
	draw_string(font, Vector2(_panel_rect.position.x + (_panel_rect.size.x - sub_w) * 0.5, _panel_rect.position.y + 70), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, Color(0.58, 0.6, 0.66, _fade_alpha))

	# Ring cards
	for i in _offered_rings.size():
		_draw_ring_card(i)

	if _conflict_mode:
		# "CURRENT" / "NEW" labels overlaid on each card
		var label_size := 9
		var labels := ["CURRENT", "NEW"]
		var label_colors := [Color(0.55, 0.55, 0.65, _fade_alpha), Color(0.45, 0.85, 0.5, _fade_alpha)]
		for i in 2:
			var lw := font.get_string_size(labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
			var cx := _card_rects[i].position.x + _card_rects[i].size.x * 0.5
			draw_string(font, Vector2(cx - lw * 0.5, _card_rects[i].position.y + 20), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, label_colors[i])
		# Note about cooldown transfer
		var note := "Replacing carries over any remaining cooldown."
		var note_size := 9
		var nw := font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, note_size).x
		draw_string(font, Vector2(_panel_rect.position.x + (_panel_rect.size.x - nw) * 0.5, _panel_rect.position.y + PANEL_SIZE.y - 62), note, HORIZONTAL_ALIGNMENT_LEFT, -1, note_size, Color(1.0, 0.8, 0.35, 0.65 * _fade_alpha))
		_draw_conflict_buttons()
	else:
		_draw_skip_button()


func _draw_ring_card(index: int) -> void:
	var rect: Rect2 = _card_rects[index]
	var ring_type: Enums.RingType = _offered_rings[index] as Enums.RingType
	var ring = Enums.RING_RESOURCES[ring_type]
	var ring_color: Color = ring.ring_color
	var is_hovered := (index == _hovered_card)
	var font := UIConstants.FONT_BODY

	# Card background
	var bg := Color(0.1, 0.1, 0.15, _fade_alpha)
	if is_hovered:
		bg = Color(0.14, 0.14, 0.21, _fade_alpha)
	_draw_rounded_rect(rect, bg, CARD_CORNER_RADIUS)

	# Card border
	var border_col := ring_color.darkened(0.35)
	var border_width := 2.0
	if is_hovered:
		border_col = ring_color.lightened(0.05)
		border_width = 2.5
	border_col.a = (0.8 if is_hovered else 0.45) * _fade_alpha
	_draw_rounded_rect_outline(rect, border_col, CARD_CORNER_RADIUS, border_width)

	# Top accent bar (colored stripe at top of card)
	var accent_inset := CARD_CORNER_RADIUS
	var accent_rect := Rect2(
		rect.position + Vector2(accent_inset, 1),
		Vector2(rect.size.x - accent_inset * 2, 3)
	)
	var accent_color := ring_color.darkened(0.15)
	accent_color.a = (0.7 if is_hovered else 0.4) * _fade_alpha
	draw_rect(accent_rect, accent_color)

	var cx := rect.position.x + rect.size.x * 0.5
	var top := rect.position.y

	# Ring icon circle
	var icon_center := Vector2(cx, top + 40)
	# Outer glow on hover
	if is_hovered:
		var glow := ring_color
		glow.a = 0.12 * _fade_alpha
		draw_circle(icon_center, ICON_RADIUS + 6, glow)
	# Circle fill
	var icon_bg := ring_color.darkened(0.7)
	icon_bg.a = 0.8 * _fade_alpha
	draw_circle(icon_center, ICON_RADIUS, icon_bg)
	# Circle border
	var icon_border := ring_color
	icon_border.a = (0.9 if is_hovered else 0.5) * _fade_alpha
	_draw_circle_outline(icon_center, ICON_RADIUS, icon_border, 2.0)

	# Ring icon or letter fallback
	var icon: Texture2D = ring.ring_icon
	if icon:
		var icon_color := Color(1.0, 1.0, 1.0, _fade_alpha)
		var icon_size := ICON_RADIUS * 1.6
		draw_texture_rect(icon, Rect2(icon_center - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size)), false, icon_color)
	else:
		var letter: String = ring.ring_letter
		var letter_size := 20
		var lw := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, letter_size).x
		var letter_color := ring_color.lightened(0.25)
		letter_color.a = _fade_alpha
		draw_string(font, Vector2(icon_center.x - lw * 0.5, icon_center.y + 7), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, letter_size, letter_color)

	# Ring name
	var name_text: String = ring.short_name
	var name_size := 16
	var nw := UIConstants.FONT_BODY_BOLD.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
	var name_color := ring_color.lightened(0.15)
	name_color.a = _fade_alpha
	draw_string(UIConstants.FONT_BODY_BOLD, Vector2(cx - nw * 0.5, top + 82), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, name_color)

	# Finger group tag
	var group_text: String = ring.finger_group
	var group_size := 9
	var gw := font.get_string_size(group_text, HORIZONTAL_ALIGNMENT_LEFT, -1, group_size).x
	# Tag background pill
	var tag_w := gw + 12
	var tag_h := 14.0
	var tag_rect := Rect2(Vector2(cx - tag_w * 0.5, top + 88), Vector2(tag_w, tag_h))
	var tag_bg := ring_color.darkened(0.6)
	tag_bg.a = 0.3 * _fade_alpha
	_draw_rounded_rect(tag_rect, tag_bg, 4.0)
	draw_string(font, Vector2(cx - gw * 0.5, top + 99), group_text, HORIZONTAL_ALIGNMENT_LEFT, -1, group_size, Color(0.5, 0.5, 0.56, _fade_alpha))

	# Description (word-wrapped)
	var desc: String = ring.description
	var desc_size := 11
	var desc_x := rect.position.x + 18
	var desc_max_width := rect.size.x - 36
	var desc_y := top + 122
	var lines := _word_wrap(desc, desc_max_width, desc_size)
	for line in lines:
		draw_string(font, Vector2(desc_x, desc_y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, desc_size, Color(0.72, 0.75, 0.8, _fade_alpha))
		desc_y += 15.0

	# Bottom info area
	# Cooldown
	var cd_text := "Cooldown: %d turn%s" % [ring.cooldown, "" if ring.cooldown == 1 else "s"]
	var cd_size := 10
	var cd_color := Color(1.0, 0.82, 0.35, _fade_alpha * 0.85)
	var cdw := font.get_string_size(cd_text, HORIZONTAL_ALIGNMENT_LEFT, -1, cd_size).x
	draw_string(font, Vector2(cx - cdw * 0.5, rect.end.y - 32), cd_text, HORIZONTAL_ALIGNMENT_LEFT, -1, cd_size, cd_color)

	# Capacity
	var cap_text := "Capacity: %d" % ring.capacity
	var cap_size := 10
	var capw := font.get_string_size(cap_text, HORIZONTAL_ALIGNMENT_LEFT, -1, cap_size).x
	draw_string(font, Vector2(cx - capw * 0.5, rect.end.y - 16), cap_text, HORIZONTAL_ALIGNMENT_LEFT, -1, cap_size, Color(0.45, 0.47, 0.52, _fade_alpha * 0.7))

	# Hover cursor hint — cards aren't clickable in conflict mode
	if is_hovered and not _conflict_mode:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	elif not _hovered_skip and not _hovered_keep and not _hovered_replace:
		mouse_default_cursor_shape = Control.CURSOR_ARROW


func _draw_skip_button() -> void:
	var font := UIConstants.FONT_BODY_BOLD
	var bg := Color(0.1, 0.1, 0.13, _fade_alpha)
	if _hovered_skip:
		bg = Color(0.16, 0.13, 0.14, _fade_alpha)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_draw_rounded_rect(_skip_rect, bg, 6.0)

	var border_col := Color(0.35, 0.28, 0.28, 0.4 * _fade_alpha)
	if _hovered_skip:
		border_col = Color(0.55, 0.35, 0.35, 0.6 * _fade_alpha)
	_draw_rounded_rect_outline(_skip_rect, border_col, 6.0, 1.5)

	var text := "Skip"
	var text_size := 13
	var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	var text_color := Color(0.5, 0.42, 0.42, _fade_alpha)
	if _hovered_skip:
		text_color = Color(0.65, 0.48, 0.48, _fade_alpha)
	draw_string(font, Vector2(
		_skip_rect.position.x + (_skip_rect.size.x - text_w) * 0.5,
		_skip_rect.position.y + _skip_rect.size.y * 0.5 + 5
	), text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, text_color)


func _draw_conflict_buttons() -> void:
	var font := UIConstants.FONT_BODY_BOLD

	# Keep button (green tint)
	var keep_bg := Color(0.1, 0.14, 0.1, _fade_alpha)
	if _hovered_keep:
		keep_bg = Color(0.13, 0.20, 0.13, _fade_alpha)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_draw_rounded_rect(_keep_rect, keep_bg, 6.0)
	var keep_border_col := Color(0.35, 0.55, 0.35, (0.65 if _hovered_keep else 0.4) * _fade_alpha)
	_draw_rounded_rect_outline(_keep_rect, keep_border_col, 6.0, 1.5)
	var keep_text := "Keep Existing"
	var keep_text_size := 12
	var ktw := font.get_string_size(keep_text, HORIZONTAL_ALIGNMENT_LEFT, -1, keep_text_size).x
	var keep_color := Color(0.5, 0.82, 0.5, _fade_alpha) if _hovered_keep else Color(0.4, 0.65, 0.4, _fade_alpha)
	draw_string(font, Vector2(_keep_rect.position.x + (_keep_rect.size.x - ktw) * 0.5, _keep_rect.position.y + _keep_rect.size.y * 0.5 + 5), keep_text, HORIZONTAL_ALIGNMENT_LEFT, -1, keep_text_size, keep_color)

	# Replace button (red tint)
	var rep_bg := Color(0.13, 0.1, 0.1, _fade_alpha)
	if _hovered_replace:
		rep_bg = Color(0.20, 0.12, 0.12, _fade_alpha)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_draw_rounded_rect(_replace_rect, rep_bg, 6.0)
	var rep_border_col := Color(0.55, 0.3, 0.3, (0.65 if _hovered_replace else 0.4) * _fade_alpha)
	_draw_rounded_rect_outline(_replace_rect, rep_border_col, 6.0, 1.5)
	var rep_text := "Replace It"
	var rep_text_size := 12
	var rtw := font.get_string_size(rep_text, HORIZONTAL_ALIGNMENT_LEFT, -1, rep_text_size).x
	var rep_color := Color(0.85, 0.45, 0.45, _fade_alpha) if _hovered_replace else Color(0.65, 0.35, 0.35, _fade_alpha)
	draw_string(font, Vector2(_replace_rect.position.x + (_replace_rect.size.x - rtw) * 0.5, _replace_rect.position.y + _replace_rect.size.y * 0.5 + 5), rep_text, HORIZONTAL_ALIGNMENT_LEFT, -1, rep_text_size, rep_color)


# === TEXT WRAPPING ===

func _word_wrap(text: String, max_width: float, font_size: int) -> PackedStringArray:
	var font := UIConstants.FONT_BODY
	var lines: PackedStringArray = []
	var words := text.split(" ")
	var current_line := ""

	for word in words:
		var test_line: String
		if current_line == "":
			test_line = word
		else:
			test_line = current_line + " " + word
		var test_width := font.get_string_size(test_line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if test_width > max_width and current_line != "":
			lines.append(current_line)
			current_line = word
		else:
			current_line = test_line

	if current_line != "":
		lines.append(current_line)

	return lines


# === DRAWING HELPERS ===

func _draw_rounded_rect(rect: Rect2, color: Color, radius: float) -> void:
	draw_colored_polygon(_rounded_rect_points(rect, radius), color)


func _draw_rounded_rect_outline(rect: Rect2, color: Color, radius: float, width: float) -> void:
	var points := _rounded_rect_points(rect, radius)
	points.append(points[0])
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], color, width, true)


func _rounded_rect_points(rect: Rect2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var segments := 8
	# [cx, cy, start_angle] for each corner: TL, TR, BR, BL
	var corners := [
		[rect.position.x + r, rect.position.y + r, PI],
		[rect.end.x - r, rect.position.y + r, -PI / 2.0],
		[rect.end.x - r, rect.end.y - r, 0.0],
		[rect.position.x + r, rect.end.y - r, PI / 2.0],
	]
	for corner in corners:
		var corner_cx: float = corner[0]
		var corner_cy: float = corner[1]
		var start_angle: float = corner[2]
		for j in range(segments + 1):
			var angle: float = start_angle + (PI / 2.0) * (float(j) / float(segments))
			points.append(Vector2(corner_cx + cos(angle) * r, corner_cy + sin(angle) * r))
	return points


func _draw_circle_outline(center: Vector2, radius: float, color: Color, width: float) -> void:
	var segments := 32
	var prev := center + Vector2(radius, 0)
	for i in range(1, segments + 1):
		var angle := TAU * float(i) / float(segments)
		var next_pt := center + Vector2(cos(angle) * radius, sin(angle) * radius)
		draw_line(prev, next_pt, color, width, true)
		prev = next_pt
