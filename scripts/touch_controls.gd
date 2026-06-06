extends CanvasLayer
## True multitouch on-screen driving pad. The OLD build used Godot `Button` nodes, but with
## `emulate_mouse_from_touch` only ONE finger becomes the emulated mouse, so a phone player
## could never hold steer + drift at the same time. Here we read raw `InputEventScreenTouch`
## /`Drag` events (one per finger `index`) and press/release the SAME InputMap actions the
## keyboard uses, so kart.gd stays input-source-agnostic and every finger works independently.
## Mouse events are handled too, so desktop + the headless verifier can drive the pad.

const T := preload("res://scripts/ui_theme.gd")

var _pads: Array = []                  # [{ctrl, glow, action}]
var _holder_action := {}               # finger index / "m" -> action it's holding
var _press_count := {}                 # action -> how many holders
var _enabled := true


func setup() -> void:
	layer = 12
	_pad("kart_left", "<", Color(0.20, 0.46, 0.92), 150, Vector2(0, 1), Vector2(40, -200))
	_pad("kart_right", ">", Color(0.20, 0.46, 0.92), 150, Vector2(0, 1), Vector2(214, -200))
	_pad("kart_brake", "BRAKE", Color(0.88, 0.28, 0.28), 116, Vector2(1, 1), Vector2(-372, -176))
	_pad("kart_drift", "DRIFT", Color(0.97, 0.55, 0.14), 176, Vector2(1, 1), Vector2(-216, -214))
	_pad("kart_item", "ITEM", Color(0.24, 0.74, 0.40), 132, Vector2(1, 1), Vector2(-214, -402))


func set_enabled(on: bool) -> void:
	_enabled = on
	for p: Dictionary in _pads:
		(p["ctrl"] as Control).visible = on
	if not on:
		for k: Variant in _holder_action.keys():
			_assign(k, "")


func _pad(action: String, label: String, col: Color, sz: int, anchor: Vector2, off: Vector2) -> void:
	var ctrl := Control.new()
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.anchor_left = anchor.x
	ctrl.anchor_right = anchor.x
	ctrl.anchor_top = anchor.y
	ctrl.anchor_bottom = anchor.y
	ctrl.position = off
	ctrl.size = Vector2(sz, sz)
	add_child(ctrl)

	var base := Panel.new()
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r, col.g, col.b, 0.30)
	sb.set_corner_radius_all(sz / 2)
	sb.set_border_width_all(3)
	sb.border_color = Color(1, 1, 1, 0.5)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 8
	base.add_theme_stylebox_override("panel", sb)
	ctrl.add_child(base)

	var glow := Panel.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	var gs := StyleBoxFlat.new()
	gs.bg_color = Color(col.r, col.g, col.b, 0.95)
	gs.set_corner_radius_all(sz / 2)
	gs.set_border_width_all(3)
	gs.border_color = Color(1, 1, 1, 0.9)
	glow.add_theme_stylebox_override("panel", gs)
	glow.modulate.a = 0.0
	ctrl.add_child(glow)

	var lbl := T.label(label, 40 if label.length() <= 1 else 24, Color(1, 1, 1), 5)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ctrl.add_child(lbl)

	_pads.append({"ctrl": ctrl, "glow": glow, "action": action})


func _hit(screen_pos: Vector2) -> String:
	for p: Dictionary in _pads:
		var c := p["ctrl"] as Control
		var local: Vector2 = c.get_global_transform_with_canvas().affine_inverse() * screen_pos
		if Rect2(Vector2.ZERO, c.size).has_point(local):
			return str(p["action"])
	return ""


func _input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_assign(t.index, _hit(t.position))
		else:
			_assign(t.index, "")
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_assign(d.index, _hit(d.position))
	elif event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.button_index == MOUSE_BUTTON_LEFT:
			_assign("m", _hit(m.position) if m.pressed else "")
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_assign("m", _hit(mm.position))


func _assign(holder: Variant, action: String) -> void:
	var prev := str(_holder_action.get(holder, ""))
	if prev == action:
		return
	if prev != "":
		var n: int = int(_press_count.get(prev, 0)) - 1
		_press_count[prev] = maxi(0, n)
		if n <= 0:
			Input.action_release(prev)
			_glow(prev, false)
	if action != "":
		_holder_action[holder] = action
		var c: int = int(_press_count.get(action, 0)) + 1
		_press_count[action] = c
		if c == 1:
			Input.action_press(action)
			_glow(action, true)
	else:
		_holder_action.erase(holder)


func _glow(action: String, on: bool) -> void:
	for p: Dictionary in _pads:
		if str(p["action"]) == action:
			var g := p["glow"] as Panel
			var t := create_tween()
			t.tween_property(g, "modulate:a", 1.0 if on else 0.0, 0.08)
			return
