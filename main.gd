extends Node3D
## Bootstrap + scene flow. Registers input actions, shows the tap-to-start overlay
## (unlocks Web Audio on the first gesture), then drives the loop:
##   Menu (3D showroom + garage + arena select) ──RACE─▶ Game ──Menu/Again──▶ Menu

const MenuScene := preload("res://scripts/menu.gd")
const GameScene := preload("res://scripts/game.gd")

var _menu: Node = null
var _game: Node = null


func _ready() -> void:
	_register_actions()
	_enter_menu()
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


func _enter_menu() -> void:
	if _game != null:
		_game.queue_free()
		_game = null
	_menu = MenuScene.new()
	add_child(_menu)
	_menu.race_requested.connect(_start_race)


func _start_race(arena_id: String, kart_id: String) -> void:
	if _menu != null:
		_menu.queue_free()
		_menu = null
	_game = GameScene.new()
	_game.arena_spec = Arenas.by_id(arena_id)
	_game.kart_def = Garage.by_id(kart_id)
	add_child(_game)
	_game.exited.connect(_enter_menu)
	_game.begin()


func _show_tap_to_start() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TapToStart"
	layer.layer = 100
	var panel := ColorRect.new()
	panel.color = Color(0.04, 0.05, 0.10, 0.94)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	var title := UITheme.label("TURBO KARTS", 70, UITheme.ACCENT, 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := UITheme.label("Tap to start", 34, UITheme.TEXT, 6)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var hint := UITheme.label("Pick an arena, buy faster karts, and race\nDesktop: WASD/Arrows - Space drift - E item - S brake", 22, UITheme.DIM, 5)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	var blink := create_tween().set_loops()
	blink.tween_property(sub, "modulate:a", 0.3, 0.6)
	blink.tween_property(sub, "modulate:a", 1.0, 0.6)

	panel.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.is_pressed():
			blink.kill()
			layer.queue_free())
	add_child(layer)
