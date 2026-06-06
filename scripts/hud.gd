extends CanvasLayer
## On-screen race UI + touch controls. Touch buttons drive the same input actions
## as the keyboard via Input.action_press/release, so the kart code is unified.

var game: Node

var _lap: Label
var _pos: Label
var _time: Label
var _best: Label
var _coins: Label
var _room: Label
var _item_swatch: ColorRect
var _item_text: Label
var _board: VBoxContainer
var _count: Label
var _finish: Control
var _finish_text: Label
var _msg: Label

const ITEM_COLORS := {
	"mushroom": Color(1.0, 0.4, 0.3),
	"banana": Color(1.0, 0.85, 0.1),
	"shell": Color(0.2, 0.85, 0.3),
	"": Color(0.2, 0.22, 0.3),
}
const ITEM_LABELS := {
	"mushroom": "BOOST",
	"banana": "BANANA",
	"shell": "SHELL",
	"": "-",
}


func setup(game_ref: Node) -> void:
	game = game_ref
	_build()


func _build() -> void:
	layer = 10
	_lap = _label(Vector2(20, 16), 40, Color(1, 1, 1), "LAP 1/3")
	_pos = _label(Vector2(20, 62), 52, Color(1.0, 0.84, 0.2), "1st")
	_coins = _label(Vector2(20, 124), 30, Color(1.0, 0.82, 0.18), "Coins 0")

	_time = _label(Vector2(0, 16), 38, Color(1, 1, 1), "0:00.00")
	_time.anchor_left = 0.5
	_time.anchor_right = 0.5
	_time.position = Vector2(-90, 16)
	_time.size.x = 180
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_best = _label(Vector2(0, 60), 24, Color(0.75, 0.85, 1.0), "Best --")
	_best.anchor_left = 0.5
	_best.anchor_right = 0.5
	_best.position = Vector2(-90, 58)
	_best.size.x = 180
	_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# item slot (top-right)
	var slot := Panel.new()
	slot.size = Vector2(120, 120)
	slot.anchor_left = 1.0
	slot.anchor_right = 1.0
	slot.position = Vector2(-138, 16)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.35)
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(3)
	sb.border_color = Color(1, 1, 1, 0.5)
	slot.add_theme_stylebox_override("panel", sb)
	add_child(_wrap(slot))
	_item_swatch = ColorRect.new()
	_item_swatch.color = ITEM_COLORS[""]
	_item_swatch.size = Vector2(76, 60)
	_item_swatch.position = Vector2(22, 14)
	slot.add_child(_item_swatch)
	_item_text = Label.new()
	_item_text.text = "-"
	_item_text.add_theme_font_size_override("font_size", 22)
	_item_text.position = Vector2(0, 80)
	_item_text.size = Vector2(120, 30)
	_item_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.add_child(_item_text)

	# leaderboard (right, under item slot)
	var bpanel := Panel.new()
	bpanel.size = Vector2(220, 220)
	bpanel.anchor_left = 1.0
	bpanel.anchor_right = 1.0
	bpanel.position = Vector2(-238, 150)
	var bb := StyleBoxFlat.new()
	bb.bg_color = Color(0, 0, 0, 0.3)
	bb.set_corner_radius_all(12)
	bpanel.add_theme_stylebox_override("panel", bb)
	add_child(_wrap(bpanel))
	_board = VBoxContainer.new()
	_board.position = Vector2(12, 8)
	_board.size = Vector2(200, 200)
	_board.add_theme_constant_override("separation", 4)
	bpanel.add_child(_board)

	_room = _label(Vector2(20, 0), 22, Color(0.8, 0.9, 1.0), "ROOM ...")
	_room.anchor_top = 1.0
	_room.anchor_bottom = 1.0
	_room.position = Vector2(20, -36)

	# countdown
	_count = _label(Vector2(0, 0), 130, Color(1.0, 0.9, 0.2), "")
	_count.anchor_left = 0.5
	_count.anchor_right = 0.5
	_count.anchor_top = 0.5
	_count.anchor_bottom = 0.5
	_count.position = Vector2(-150, -120)
	_count.size = Vector2(300, 200)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_msg = _label(Vector2(0, 0), 34, Color(1, 1, 1), "")
	_msg.anchor_left = 0.5
	_msg.anchor_right = 0.5
	_msg.anchor_top = 0.5
	_msg.position = Vector2(-260, -200)
	_msg.size = Vector2(520, 60)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_build_touch()
	_build_finish()


func _label(pos: Vector2, fsize: int, col: Color, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l


func _wrap(c: Control) -> Control:
	return c


func _build_touch() -> void:
	var left := _round_btn("<<", Color(0.2, 0.6, 1.0))
	left.anchor_top = 1.0
	left.anchor_bottom = 1.0
	left.position = Vector2(24, -150)
	_hold(left, "kart_left")

	var right := _round_btn(">>", Color(0.2, 0.6, 1.0))
	right.anchor_top = 1.0
	right.anchor_bottom = 1.0
	right.position = Vector2(168, -150)
	_hold(right, "kart_right")

	var drift := _round_btn("DRIFT", Color(1.0, 0.55, 0.15))
	drift.anchor_left = 1.0
	drift.anchor_right = 1.0
	drift.anchor_top = 1.0
	drift.anchor_bottom = 1.0
	drift.position = Vector2(-150, -150)
	_hold(drift, "kart_drift")

	var item := _round_btn("ITEM", Color(0.3, 0.8, 0.4))
	item.anchor_left = 1.0
	item.anchor_right = 1.0
	item.anchor_top = 1.0
	item.anchor_bottom = 1.0
	item.position = Vector2(-150, -290)
	_hold(item, "kart_item")


func _round_btn(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.size = Vector2(126, 126)
	b.add_theme_font_size_override("font_size", 30)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(col.r, col.g, col.b, 0.55)
	normal.set_corner_radius_all(63)
	normal.set_border_width_all(4)
	normal.border_color = Color(1, 1, 1, 0.7)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(col.r, col.g, col.b, 0.9)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_color_override("font_color", Color(1, 1, 1))
	b.focus_mode = Control.FOCUS_NONE
	add_child(b)
	return b


func _hold(btn: Button, action: String) -> void:
	btn.button_down.connect(func() -> void: Input.action_press(action))
	btn.button_up.connect(func() -> void: Input.action_release(action))


func _build_finish() -> void:
	_finish = Control.new()
	_finish.set_anchors_preset(Control.PRESET_FULL_RECT)
	_finish.visible = false
	add_child(_finish)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.1, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_finish.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	_finish.add_child(box)
	var title := Label.new()
	title.text = "FINISH!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.2))
	box.add_child(title)
	_finish_text = Label.new()
	_finish_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_finish_text.add_theme_font_size_override("font_size", 34)
	_finish_text.add_theme_color_override("font_color", Color(1, 1, 1))
	box.add_child(_finish_text)
	var again := Button.new()
	again.text = "  Race Again  "
	again.add_theme_font_size_override("font_size", 34)
	again.custom_minimum_size = Vector2(280, 70)
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.pressed.connect(func() -> void:
		_finish.visible = false
		if game: game.reset_race())
	box.add_child(again)


# ---------------------------------------------------------------- updates

func set_lap(done: int, total: int) -> void:
	_lap.text = "LAP %d/%d" % [mini(done + 1, total), total]


func set_position(p: int, total: int) -> void:
	_pos.text = "%s of %d" % [_ordinal(p), total]


func set_time(secs: float) -> void:
	_time.text = _fmt(secs)


func set_best(secs: float) -> void:
	_best.text = "Best %s" % _fmt(secs) if secs > 0.0 else "Best --"


func set_coins(n: int) -> void:
	_coins.text = "Coins %d" % n


func set_item(name: String) -> void:
	_item_swatch.color = ITEM_COLORS.get(name, ITEM_COLORS[""])
	_item_text.text = ITEM_LABELS.get(name, "-")


func set_room(code: String) -> void:
	_room.text = "ROOM %s  -  share this link" % code


func set_board(rows: Array) -> void:
	for c in _board.get_children():
		c.queue_free()
	for i in rows.size():
		var row: Dictionary = rows[i]
		var l := Label.new()
		l.text = "%d. %s" % [i + 1, row.get("name", "Racer")]
		l.add_theme_font_size_override("font_size", 24)
		var col: Color = row.get("color", Color(1, 1, 1))
		if row.get("me", false):
			col = Color(1.0, 0.9, 0.3)
			l.text += "  (you)"
		l.add_theme_color_override("font_color", col)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		l.add_theme_constant_override("outline_size", 4)
		_board.add_child(l)


func show_count(text: String) -> void:
	_count.text = text
	if text != "":
		_count.scale = Vector2(1.5, 1.5)
		_count.pivot_offset = _count.size * 0.5
		var t := create_tween()
		t.tween_property(_count, "scale", Vector2.ONE, 0.4)


func flash(text: String) -> void:
	_msg.text = text
	_msg.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(0.8)
	t.tween_property(_msg, "modulate:a", 0.0, 0.6)


func show_finish(placement: int, total: int, race_time: float, best: float) -> void:
	_finish_text.text = "You finished %s of %d\nTotal %s   -   Best lap %s" % [_ordinal(placement), total, _fmt(race_time), _fmt(best)]
	_finish.visible = true


func hide_finish() -> void:
	_finish.visible = false


func _ordinal(n: int) -> String:
	match n:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
		_: return "%dth" % n


func _fmt(secs: float) -> String:
	if secs <= 0.0:
		return "--"
	var m := int(secs) / 60
	var s := secs - float(m * 60)
	return "%d:%05.2f" % [m, s]
