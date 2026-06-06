extends CanvasLayer
## Race HUD + on-screen touch controls, styled with UITheme so it reads as a polished
## product. Touch buttons drive the same Input actions as the keyboard, so kart.gd
## stays input-source-agnostic. Includes the countdown, lap/timer/position/coins, a
## live leaderboard, and a rich finish card that banks + shows coins earned.

const T := preload("res://scripts/ui_theme.gd")

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
var _finish_place: Label
var _finish_stats: Label
var _finish_earn: Label
var _finish_bal: Label
var _msg: Label
var _balance := 0

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
	_build_top_left()
	_build_timer()
	_build_item_slot()
	_build_board()
	_build_room()
	_build_countdown()
	_build_flash()
	_build_touch()
	_build_finish()


func _panel(size: Vector2) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", T.glass())
	p.custom_minimum_size = size
	p.size = size
	return p


func _lbl(text: String, fs: int, col := T.TEXT, outline := 5) -> Label:
	return T.label(text, fs, col, outline)


func _build_top_left() -> void:
	var panel := _panel(Vector2(220, 132))
	panel.position = Vector2(24, 24)
	add_child(panel)
	var box := VBoxContainer.new()
	box.position = Vector2(16, 10)
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)
	_lap = _lbl("LAP 1/3", 34, T.TEXT, 0)
	box.add_child(_lap)
	_pos = _lbl("1st of 1", 30, T.ACCENT, 0)
	box.add_child(_pos)
	_best = _lbl("BEST --", 20, T.DIM, 0)
	box.add_child(_best)


func _build_timer() -> void:
	var panel := _panel(Vector2(200, 86))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.position = Vector2(-100, 24)
	add_child(panel)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)
	var cap := _lbl("TIME", 16, T.DIM, 0)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(cap)
	_time = _lbl("0:00.00", 38, T.TEXT, 0)
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_time)


func _build_item_slot() -> void:
	var slot := Panel.new()
	slot.add_theme_stylebox_override("panel", T.glass(Color(0.06, 0.08, 0.16, 0.78), 18))
	slot.size = Vector2(120, 120)
	slot.anchor_left = 1.0
	slot.anchor_right = 1.0
	slot.position = Vector2(-144, 24)
	add_child(slot)
	_item_swatch = ColorRect.new()
	_item_swatch.color = ITEM_COLORS[""]
	_item_swatch.size = Vector2(80, 56)
	_item_swatch.position = Vector2(20, 14)
	slot.add_child(_item_swatch)
	_item_text = _lbl("-", 22, T.TEXT, 0)
	_item_text.size = Vector2(120, 30)
	_item_text.position = Vector2(0, 80)
	_item_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.add_child(_item_text)

	var chip := Panel.new()
	chip.add_theme_stylebox_override("panel", T.chip(Color(0.16, 0.13, 0.04, 0.85)))
	chip.size = Vector2(120, 44)
	chip.anchor_left = 1.0
	chip.anchor_right = 1.0
	chip.position = Vector2(-144, 152)
	add_child(chip)
	var dot := Panel.new()
	var ds := StyleBoxFlat.new()
	ds.bg_color = T.ACCENT
	ds.set_corner_radius_all(20)
	ds.set_border_width_all(2)
	ds.border_color = Color(0.6, 0.45, 0.05)
	dot.add_theme_stylebox_override("panel", ds)
	dot.size = Vector2(26, 26)
	dot.position = Vector2(12, 9)
	chip.add_child(dot)
	_coins = _lbl("0", 26, T.ACCENT, 0)
	_coins.position = Vector2(48, 6)
	chip.add_child(_coins)


func _build_board() -> void:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", T.glass(T.PANEL_SOFT, 14))
	panel.size = Vector2(240, 210)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.position = Vector2(-264, 210)
	add_child(panel)
	var title := _lbl("RACERS", 18, T.DIM, 0)
	title.position = Vector2(16, 10)
	panel.add_child(title)
	_board = VBoxContainer.new()
	_board.position = Vector2(16, 38)
	_board.size = Vector2(212, 160)
	_board.add_theme_constant_override("separation", 4)
	panel.add_child(_board)


func _build_room() -> void:
	_room = _lbl("", 20, T.DIM, 4)
	_room.anchor_top = 1.0
	_room.anchor_bottom = 1.0
	_room.position = Vector2(24, -40)
	add_child(_room)


func _build_countdown() -> void:
	_count = _lbl("", 150, T.ACCENT, 10)
	_count.anchor_left = 0.5
	_count.anchor_right = 0.5
	_count.anchor_top = 0.5
	_count.anchor_bottom = 0.5
	_count.position = Vector2(-160, -140)
	_count.size = Vector2(320, 220)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_count)


func _build_flash() -> void:
	_msg = _lbl("", 40, T.TEXT, 6)
	_msg.anchor_left = 0.5
	_msg.anchor_right = 0.5
	_msg.anchor_top = 0.5
	_msg.position = Vector2(-280, -230)
	_msg.size = Vector2(560, 60)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_msg)


func _build_touch() -> void:
	var left := _round_btn("<", Color(0.18, 0.42, 0.85))
	left.anchor_top = 1.0
	left.anchor_bottom = 1.0
	left.position = Vector2(28, -158)
	_hold(left, "kart_left")

	var right := _round_btn(">", Color(0.18, 0.42, 0.85))
	right.anchor_top = 1.0
	right.anchor_bottom = 1.0
	right.position = Vector2(172, -158)
	_hold(right, "kart_right")

	var drift := _round_btn("DRIFT", Color(0.95, 0.5, 0.12))
	drift.anchor_left = 1.0
	drift.anchor_right = 1.0
	drift.anchor_top = 1.0
	drift.anchor_bottom = 1.0
	drift.position = Vector2(-160, -158)
	_hold(drift, "kart_drift")

	var item := _round_btn("ITEM", Color(0.22, 0.72, 0.36), 108)
	item.anchor_left = 1.0
	item.anchor_right = 1.0
	item.anchor_top = 1.0
	item.anchor_bottom = 1.0
	item.position = Vector2(-152, -296)
	_hold(item, "kart_item")

	var brake := _round_btn("BRK", Color(0.85, 0.26, 0.26), 100)
	brake.anchor_left = 1.0
	brake.anchor_right = 1.0
	brake.anchor_top = 1.0
	brake.anchor_bottom = 1.0
	brake.position = Vector2(-300, -150)
	_hold(brake, "kart_brake")


func _round_btn(text: String, col: Color, sz := 132) -> Button:
	var b := Button.new()
	b.text = text
	b.size = Vector2(sz, sz)
	b.custom_minimum_size = Vector2(sz, sz)
	var fs := 44 if text.length() <= 1 else 26
	T.style_button(b, Color(col.r, col.g, col.b, 0.6), Color(1, 1, 1), fs, sz / 2)
	var pressed := b.get_theme_stylebox("pressed") as StyleBoxFlat
	pressed.bg_color = Color(col.r, col.g, col.b, 0.95)
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
	bg.color = Color(0.02, 0.03, 0.07, 0.84)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_finish.add_child(bg)

	var card := Panel.new()
	card.add_theme_stylebox_override("panel", T.glass(Color(0.09, 0.12, 0.22, 0.96), 24, T.BORDER, 2))
	card.custom_minimum_size = Vector2(560, 540)
	card.size = Vector2(560, 540)
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.position = Vector2(-280, -270)
	_finish.add_child(card)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	box.offset_left = 30
	box.offset_right = -30
	card.add_child(box)

	var title := _lbl("FINISH!", 66, T.ACCENT, 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_finish_place = _lbl("", 40, T.TEXT, 0)
	_finish_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_finish_place)
	_finish_stats = _lbl("", 24, T.DIM, 0)
	_finish_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_finish_stats)
	_finish_earn = _lbl("", 34, T.GOOD, 0)
	_finish_earn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_finish_earn)
	_finish_bal = _lbl("", 26, T.ACCENT, 0)
	_finish_bal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_finish_bal)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	var again := Button.new()
	again.text = "Race Again"
	T.style_button(again, T.ACCENT, Color(0.1, 0.08, 0.0), 30, 16)
	again.custom_minimum_size = Vector2(220, 64)
	again.pressed.connect(func() -> void:
		_finish.visible = false
		if game: game.reset_race())
	row.add_child(again)
	var menu := Button.new()
	menu.text = "Menu"
	T.style_button(menu, Color(0.2, 0.24, 0.36), T.TEXT, 30, 16)
	menu.custom_minimum_size = Vector2(160, 64)
	menu.pressed.connect(func() -> void:
		_finish.visible = false
		if game: game.exit_to_menu())
	row.add_child(menu)


# ---------------------------------------------------------------- updates

func set_lap(done: int, total: int) -> void:
	_lap.text = "LAP %d/%d" % [mini(done + 1, total), total]


func set_position(p: int, total: int) -> void:
	_pos.text = "%s of %d" % [_ordinal(p), total]


func set_time(secs: float) -> void:
	_time.text = _fmt(secs)


func set_best(secs: float) -> void:
	_best.text = "BEST %s" % _fmt(secs) if secs > 0.0 else "BEST --"


func set_coins(n: int) -> void:
	_coins.text = str(n)


func set_balance(n: int) -> void:
	_balance = n
	if _finish_bal and _finish.visible:
		_finish_bal.text = "Wallet: %s coins" % _commas(n)


func set_item(name: String) -> void:
	_item_swatch.color = ITEM_COLORS.get(name, ITEM_COLORS[""])
	_item_text.text = ITEM_LABELS.get(name, "-")


func set_room(code: String) -> void:
	_room.text = "ROOM %s  -  share the link to race together" % code


func set_board(rows: Array) -> void:
	for c in _board.get_children():
		c.queue_free()
	for i in mini(rows.size(), 5):
		var row: Dictionary = rows[i]
		var l := Label.new()
		l.text = "%d. %s" % [i + 1, row.get("name", "Racer")]
		l.add_theme_font_size_override("font_size", 22)
		var col: Color = row.get("color", Color(1, 1, 1))
		if row.get("me", false):
			col = T.ACCENT
			l.text += "  (you)"
		l.add_theme_color_override("font_color", col)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		l.add_theme_constant_override("outline_size", 4)
		_board.add_child(l)


func show_count(text: String) -> void:
	_count.text = text
	if text != "":
		_count.scale = Vector2(1.6, 1.6)
		_count.pivot_offset = _count.size * 0.5
		var t := create_tween()
		t.tween_property(_count, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func flash(text: String) -> void:
	_msg.text = text
	_msg.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(0.9)
	t.tween_property(_msg, "modulate:a", 0.0, 0.6)


func show_finish(placement: int, total: int, race_time: float, best: float, earned: int, collected: int, place_bonus: int, balance: int) -> void:
	_finish_place.text = "%s of %d" % [_ordinal(placement), total]
	_finish_stats.text = "Total %s    Best lap %s" % [_fmt(race_time), _fmt(best)]
	_finish_earn.text = "+%d coins  (%d x10 + %d place)" % [earned, collected, place_bonus]
	_balance = balance
	_finish_bal.text = "Wallet: %s coins" % _commas(balance)
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


func _commas(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out
