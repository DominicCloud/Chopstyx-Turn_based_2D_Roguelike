extends Control

signal split_confirmed(distribution: Array[int])
signal split_canceled()

# Layout
const BOX_SIZE := Vector2(160, 200)
const BOX_GAP := 40.0
const BOX_Y_OFFSET := -20.0
const DRAG_DOT_RADIUS := 18.0
const SNAP_DOT_RADIUS := 16.0
const BUTTON_WIDTH := 120.0
const BUTTON_HEIGHT := 40.0
const BUTTON_GAP := 20.0

# State
var _hands: Array[Dictionary] = []
var _boxes: Array[Rect2] = []         # Screen rects for each hand box
var _dots: Array[Dictionary] = []     # {pos: Vector2, box_index: int, snap_index: int}
var _dragging_index: int = -1
var _drag_offset := Vector2.ZERO
var _fade_alpha := 0.0
var _confirm_rect := Rect2()
var _cancel_rect := Rect2()
var _hovered_button := -1  # 0 = confirm, 1 = cancel, -1 = none

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

func open(hands: Array[Dictionary]) -> void:
	_hands = hands
	_build_layout()
	visible = true
	_fade_alpha = 0.0
	var tw := create_tween()
	tw.tween_property(self, "_fade_alpha", 1.0, UIConstants.ANIM_SPLIT_FADE)
	tw.tween_callback(queue_redraw)
	set_process(true)
	queue_redraw()

func close() -> void:
	var tw := create_tween()
	tw.tween_property(self, "_fade_alpha", 0.0, UIConstants.ANIM_SPLIT_FADE)
	tw.tween_callback(_on_fade_out_done)

func _on_fade_out_done() -> void:
	visible = false
	_dots.clear()
	_boxes.clear()
	_hands.clear()

func _process(_delta: float) -> void:
	if visible and _fade_alpha < 1.0:
		queue_redraw()

func _build_layout() -> void:
	_boxes.clear()
	_dots.clear()

	var count := _hands.size()
	var total_width: float = count * BOX_SIZE.x + (count - 1) * BOX_GAP
	var start_x: float = (size.x - total_width) * 0.5
	var center_y: float = size.y * 0.5 + BOX_Y_OFFSET

	for i in count:
		var box_pos := Vector2(start_x + i * (BOX_SIZE.x + BOX_GAP), center_y - BOX_SIZE.y * 0.5)
		_boxes.append(Rect2(box_pos, BOX_SIZE))

		# Create dots for this hand's fingers
		var fingers: int = _hands[i]["fingers"]
		for j in fingers:
			var dot := {
				"box_index": i,
				"snap_index": j,
			}
			dot["pos"] = _get_snap_position(i, j, fingers)
			_dots.append(dot)

	# Button rects
	var btn_y: float = center_y + BOX_SIZE.y * 0.5 + 30
	var btn_total: float = BUTTON_WIDTH * 2 + BUTTON_GAP
	var btn_start_x: float = (size.x - btn_total) * 0.5
	_confirm_rect = Rect2(Vector2(btn_start_x, btn_y), Vector2(BUTTON_WIDTH, BUTTON_HEIGHT))
	_cancel_rect = Rect2(Vector2(btn_start_x + BUTTON_WIDTH + BUTTON_GAP, btn_y), Vector2(BUTTON_WIDTH, BUTTON_HEIGHT))


func _get_snap_position(box_index: int, dot_index: int, total_dots: int) -> Vector2:
	if box_index >= _boxes.size():
		return Vector2.ZERO
	var box: Rect2 = _boxes[box_index]
	var center := box.position + box.size * 0.5
	var clamped := mini(total_dots, 4)
	var pattern: Array = UIConstants.DOT_PATTERNS.get(clamped, [])
	if dot_index < pattern.size():
		return center + pattern[dot_index] * 55.0
	# Fallback: stack extra dots
	return center + Vector2(0, 30.0 * (dot_index - pattern.size()))


func _get_distribution() -> Array[int]:
	var dist: Array[int] = []
	for i in _hands.size():
		var count := 0
		for dot in _dots:
			if dot["box_index"] == i:
				count += 1
		dist.append(count)
	return dist


func _reindex_dots_in_box(box_index: int) -> void:
	var box_dots: Array[int] = []
	for i in _dots.size():
		if _dots[i]["box_index"] == box_index:
			box_dots.append(i)
	var total := box_dots.size()
	for j in box_dots.size():
		var idx: int = box_dots[j]
		_dots[idx]["snap_index"] = j
		if idx != _dragging_index:
			_dots[idx]["pos"] = _get_snap_position(box_index, j, total)


func _gui_input(event: InputEvent) -> void:
	if not visible or _fade_alpha < 0.9:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_on_press(mb.position)
			else:
				_on_release(mb.position)
			accept_event()
			queue_redraw()

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging_index >= 0:
			_dots[_dragging_index]["pos"] = mm.position + _drag_offset
			accept_event()
			queue_redraw()
		else:
			# Button hover detection
			var old_hover := _hovered_button
			_hovered_button = -1
			if _confirm_rect.has_point(mm.position):
				_hovered_button = 0
			elif _cancel_rect.has_point(mm.position):
				_hovered_button = 1
			if old_hover != _hovered_button:
				queue_redraw()


func _on_press(pos: Vector2) -> void:
	# Check dots (reverse order so topmost is picked first)
	for i in range(_dots.size() - 1, -1, -1):
		var dot_pos: Vector2 = _dots[i]["pos"]
		if dot_pos.distance_to(pos) < DRAG_DOT_RADIUS + 4:
			_dragging_index = i
			_drag_offset = dot_pos - pos
			return

	# Check buttons
	if _confirm_rect.has_point(pos):
		_try_confirm()
	elif _cancel_rect.has_point(pos):
		close()
		split_canceled.emit()


func _on_release(_pos: Vector2) -> void:
	if _dragging_index < 0:
		return

	var dot: Dictionary = _dots[_dragging_index]
	var dot_pos: Vector2 = dot["pos"]
	var old_box: int = dot["box_index"]

	# Find which box the dot was dropped in
	var new_box := -1
	for i in _boxes.size():
		if _boxes[i].grow(20).has_point(dot_pos):
			new_box = i
			break

	if new_box >= 0 and new_box != old_box:
		# Count dots in target box
		var target_count := 0
		for d in _dots:
			if d["box_index"] == new_box:
				target_count += 1
		if target_count < 4:  # Max 4 fingers
			dot["box_index"] = new_box
			_reindex_dots_in_box(old_box)
			_reindex_dots_in_box(new_box)
		else:
			# Snap back
			_reindex_dots_in_box(old_box)
	elif new_box < 0:
		# Dropped outside - snap back
		_reindex_dots_in_box(old_box)
	else:
		# Same box
		_reindex_dots_in_box(old_box)

	_dragging_index = -1
	queue_redraw()


func _try_confirm() -> void:
	var dist := _get_distribution()
	# Validate: differs from current
	var same := true
	for i in _hands.size():
		if _hands[i]["fingers"] != dist[i]:
			same = false
			break
	if same:
		return  # No change

	# Validate: no hand exceeds max
	for val in dist:
		if val < 0 or val >= Enums.MAX_FINGERS:
			return

	close()
	split_confirmed.emit(dist)


# === DRAWING ===

func _draw() -> void:
	if not visible:
		return

	# Dark backdrop
	var backdrop_color := Color(0.0, 0.0, 0.05, 0.85 * _fade_alpha)
	draw_rect(Rect2(Vector2.ZERO, size), backdrop_color)

	if _fade_alpha < 0.01:
		return

	# Title
	var title := "SPLIT FINGERS"
	var title_w := UIConstants.FONT_TITLE.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	draw_string(UIConstants.FONT_TITLE, Vector2((size.x - title_w) * 0.5, _boxes[0].position.y - 28 if _boxes.size() > 0 else 100), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.8, 0.85, 0.9, _fade_alpha))

	# Hand boxes
	for i in _boxes.size():
		_draw_hand_box(i)

	# Dots (non-dragged first, then dragged on top)
	for i in _dots.size():
		if i != _dragging_index:
			_draw_dot(i)
	if _dragging_index >= 0:
		_draw_dot(_dragging_index)

	# Buttons
	_draw_button(_confirm_rect, "Confirm", UIConstants.COLOR_CONFIRM, _hovered_button == 0)
	_draw_button(_cancel_rect, "Cancel", UIConstants.COLOR_CANCEL, _hovered_button == 1)

	# Instructions
	var instr := "Drag dots between boxes to redistribute"
	var instr_w := UIConstants.FONT_BODY.get_string_size(instr, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(UIConstants.FONT_BODY, Vector2((size.x - instr_w) * 0.5, _cancel_rect.end.y + 30), instr, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.5, 0.5, 0.6, _fade_alpha))


func _draw_hand_box(index: int) -> void:
	var box: Rect2 = _boxes[index]
	# Background
	var bg := Color(0.12, 0.12, 0.18, _fade_alpha)
	draw_rect(box, bg)
	# Border
	var border_col := UIConstants.COLOR_PLAYER.darkened(0.3)
	border_col.a = _fade_alpha
	_draw_rect_outline(box, border_col, 2.0)

	# Label
	var hand: Dictionary = _hands[index]
	var alive: bool = hand.get("alive", true)
	var label := "Hand %d" % (index + 1)
	if not alive:
		label += " (dead)"
	var lw := UIConstants.FONT_BODY_BOLD.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var label_color := UIConstants.COLOR_PLAYER if alive else UIConstants.COLOR_DOT_DEAD
	label_color.a = _fade_alpha
	draw_string(UIConstants.FONT_BODY_BOLD, Vector2(box.position.x + (box.size.x - lw) * 0.5, box.position.y + 20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, label_color)

	# Dot count
	var dot_count := 0
	for d in _dots:
		if d["box_index"] == index:
			dot_count += 1
	var count_str := str(dot_count)
	var cw := UIConstants.FONT_BODY.get_string_size(count_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var count_col := Color(0.5, 0.5, 0.6, _fade_alpha)
	draw_string(UIConstants.FONT_BODY, Vector2(box.position.x + (box.size.x - cw) * 0.5, box.end.y - 8), count_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, count_col)


func _draw_dot(index: int) -> void:
	var dot: Dictionary = _dots[index]
	var pos: Vector2 = dot["pos"]
	var is_dragging := (index == _dragging_index)
	var radius := DRAG_DOT_RADIUS if is_dragging else SNAP_DOT_RADIUS

	# Glow
	var glow := UIConstants.COLOR_PLAYER
	glow.a = (0.4 if is_dragging else 0.25) * _fade_alpha
	draw_circle(pos, radius + 6.0, glow)

	# Main circle
	var col := UIConstants.COLOR_DOT_DEFAULT
	col.a = _fade_alpha
	draw_circle(pos, radius, col)

	# Ring
	var ring_col := UIConstants.COLOR_PLAYER.lightened(0.1)
	ring_col.a = _fade_alpha
	_draw_circle_outline(pos, radius, ring_col, 2.0)


func _draw_button(rect: Rect2, text: String, color: Color, hovered: bool) -> void:
	var bg := color.darkened(0.6 if not hovered else 0.4)
	bg.a = _fade_alpha
	draw_rect(rect, bg)

	var border := color
	border.a = _fade_alpha
	_draw_rect_outline(rect, border, 2.0)

	var tw := UIConstants.FONT_BODY_BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var text_col := color.lightened(0.3)
	text_col.a = _fade_alpha
	var text_pos := Vector2(rect.position.x + (rect.size.x - tw) * 0.5, rect.position.y + rect.size.y * 0.5 + 5)
	draw_string(UIConstants.FONT_BODY_BOLD, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, text_col)


func _draw_rect_outline(rect: Rect2, color: Color, width: float) -> void:
	draw_line(rect.position, Vector2(rect.end.x, rect.position.y), color, width)
	draw_line(Vector2(rect.end.x, rect.position.y), rect.end, color, width)
	draw_line(rect.end, Vector2(rect.position.x, rect.end.y), color, width)
	draw_line(Vector2(rect.position.x, rect.end.y), rect.position, color, width)


func _draw_circle_outline(center: Vector2, radius: float, color: Color, width: float) -> void:
	var segments := 24
	var prev := center + Vector2(radius, 0)
	for i in range(1, segments + 1):
		var angle := TAU * float(i) / float(segments)
		var next_pt := center + Vector2(cos(angle) * radius, sin(angle) * radius)
		draw_line(prev, next_pt, color, width, true)
		prev = next_pt
