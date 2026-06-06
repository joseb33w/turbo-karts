extends Node3D
## Turbo Karts bootstrap: registers input actions, builds the Game world (frozen),
## and shows the tap-to-start overlay that unlocks Web Audio on the first gesture.

const Game := preload("res://scripts/game.gd")

var _game


func _ready() -> void:
	_register_actions()
	_game = Game.new()
	_game.name = "Game"
	add_child(_game)
	_show_tap_to_start()


func _register_actions() -> void:
	_action("kart_left", [KEY_LEFT, KEY_A])
	_action("kart_right", [KEY_RIGHT, KEY_D])
	_action("kart_drift", [KEY_SPACE, KEY_SHIFT])
	_action("kart_item", [KEY_E, KEY_ENTER])
	_action("kart_brake", [KEY_DOWN, KEY_S])


func _action(name: String, keys: Array) -> void:
	if InputMap.has_action(name):
		InputMap.erase_action(name)
	InputMap.add_action(name, 0.2)
	for k: int in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(name, ev)


func _show_tap_to_start() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TapToStart"
	layer.layer = 50
	var panel := ColorRect.new()
	panel.color = Color(0.05, 0.07, 0.12, 0.92)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)

	var title := Label.new()
	title.text = "TURBO KARTS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.2))
	box.add_child(title)

	var sub := Label.new()
	sub.text = "Tap to start"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 34)
	sub.add_theme_color_override("font_color", Color(1, 1, 1))
	box.add_child(sub)

	var hint := Label.new()
	hint.text = "Steer with arrows / WASD or the on-screen buttons\nHold drift through turns to charge a boost"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(0.8, 0.86, 0.95))
	box.add_child(hint)

	var blink := create_tween().set_loops()
	blink.tween_property(sub, "modulate:a", 0.25, 0.6)
	blink.tween_property(sub, "modulate:a", 1.0, 0.6)

	panel.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.is_pressed():
			blink.kill()
			layer.queue_free()
			_game.begin())
	add_child(layer)
