extends Node3D
## Front-end: a 3D "showroom" backdrop (the selected kart turning on a platform under
## the selected arena's sky) plus a polished UI with three screens — main menu, garage
## (buy/select vehicles with the coin wallet), and arena select. Emits race_requested
## when the player starts a race.

const T := preload("res://scripts/ui_theme.gd")
const KartBuildC := preload("res://scripts/kart_build.gd")

signal race_requested(arena_id: String, kart_id: String)

var _psm: ProceduralSkyMaterial
var _env: Environment
var _sun: DirectionalLight3D
var _cam: Camera3D
var _kart_pivot: Node3D
var _kart_model: Node3D
var _spin := 0.0

var _ui: CanvasLayer
var _topbar: Control
var _overlay_wallets: Array = []
var _main_panel: Control
var _garage_panel: Control
var _arena_panel: Control
var _garage_list: VBoxContainer
var _arena_list: VBoxContainer
var _wallet_lbl: Label
var _arena_name: Label
var _arena_sub: Label
var _kart_name: Label
var _kart_stats: Label
var _state := "main"


func _ready() -> void:
	_read_url_arena()
	_build_showroom()
	_build_ui()
	Profile.updated.connect(_on_profile)
	Profile.op_failed.connect(_on_failed)
	_refresh_all()


func _process(delta: float) -> void:
	_spin += delta * 0.5
	if _kart_pivot:
		_kart_pivot.rotation.y = _spin
		_kart_pivot.position.y = 0.45 + sin(_spin * 2.0) * 0.05


# ---------------------------------------------------------------- showroom

func _build_showroom() -> void:
	var we := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	_psm = ProceduralSkyMaterial.new()
	sky.sky_material = _psm
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = 1.2
	we.environment = _env
	add_child(we)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-45, -50, 0)
	_sun.light_energy = 1.2
	add_child(_sun)

	var platform := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 3.2
	pm.bottom_radius = 3.4
	pm.height = 0.4
	pm.radial_segments = 40
	platform.mesh = pm
	platform.material_override = _solid(Color(0.12, 0.14, 0.22), 0.5, 0.0)
	platform.position = Vector3(0, -0.1, 0)
	add_child(platform)

	var ring := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 3.1
	rm.outer_radius = 3.4
	ring.mesh = rm
	ring.material_override = _solid(T.ACCENT, 0.4, 1.6)
	ring.position = Vector3(0, 0.12, 0)
	add_child(ring)

	_kart_pivot = Node3D.new()
	_kart_pivot.position = Vector3(0, 0.45, 0)
	add_child(_kart_pivot)

	_cam = Camera3D.new()
	_cam.fov = 40.0
	_cam.current = true
	add_child(_cam)
	_cam.position = Vector3(0.0, 3.0, 8.0)
	_cam.look_at(Vector3(0, 0.7, 0), Vector3.UP)


func _solid(c: Color, rough := 0.6, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


func _apply_sky(theme: Dictionary) -> void:
	_psm.sky_top_color = theme.get("sky_top", Color(0.25, 0.6, 1.0))
	_psm.sky_horizon_color = theme.get("sky_horizon", Color(0.7, 0.88, 1.0))
	_psm.ground_horizon_color = theme.get("ground_horizon", Color(0.7, 0.88, 1.0))
	_psm.ground_bottom_color = theme.get("ground_bottom", Color(0.5, 0.7, 0.9))
	_psm.sun_angle_max = float(theme.get("sun_angle", 30.0))
	_env.ambient_light_energy = maxf(0.85, float(theme.get("ambient", 1.1)))
	_sun.light_color = theme.get("sun_color", Color(1.0, 0.97, 0.9))
	_sun.light_energy = maxf(0.9, float(theme.get("sun_energy", 1.15)))


func _apply_kart(def: Dictionary) -> void:
	if _kart_model and is_instance_valid(_kart_model):
		_kart_model.queue_free()
	var built: Dictionary = KartBuildC.build_def(def)
	_kart_model = built["root"]
	_kart_pivot.add_child(_kart_model)


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	_build_topbar()
	_build_main_panel()
	_build_garage_panel()
	_build_arena_panel()
	_show_state("main")


func _build_topbar() -> void:
	_topbar = Control.new()
	_topbar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_topbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_topbar)

	var title := T.label("TURBO KARTS", 40, T.ACCENT, 7)
	title.position = Vector2(26, 18)
	_topbar.add_child(title)

	var chip := _wallet_chip()
	chip.anchor_left = 1.0
	chip.anchor_right = 1.0
	chip.position = Vector2(-214, 22)
	_topbar.add_child(chip)
	_wallet_lbl = chip.get_meta("lbl")


func _wallet_chip() -> Panel:
	var chip := Panel.new()
	chip.add_theme_stylebox_override("panel", T.chip(Color(0.14, 0.12, 0.04, 0.9)))
	chip.size = Vector2(190, 52)
	var dot := Panel.new()
	var ds := StyleBoxFlat.new()
	ds.bg_color = T.ACCENT
	ds.set_corner_radius_all(20)
	ds.set_border_width_all(2)
	ds.border_color = Color(0.6, 0.45, 0.05)
	dot.add_theme_stylebox_override("panel", ds)
	dot.size = Vector2(30, 30)
	dot.position = Vector2(12, 11)
	chip.add_child(dot)
	var lbl := T.label("0", 28, T.ACCENT, 0)
	lbl.position = Vector2(54, 9)
	chip.add_child(lbl)
	chip.set_meta("lbl", lbl)
	return chip


func _build_main_panel() -> void:
	_main_panel = Control.new()
	_main_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_main_panel)

	_arena_name = T.label("", 38, T.TEXT, 7)
	_arena_name.anchor_left = 0.5
	_arena_name.anchor_right = 0.5
	_arena_name.position = Vector2(-300, 92)
	_arena_name.size = Vector2(600, 46)
	_arena_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_panel.add_child(_arena_name)
	_arena_sub = T.label("", 22, T.DIM, 5)
	_arena_sub.anchor_left = 0.5
	_arena_sub.anchor_right = 0.5
	_arena_sub.position = Vector2(-300, 138)
	_arena_sub.size = Vector2(600, 30)
	_arena_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_panel.add_child(_arena_sub)

	# kart info card (bottom-center, above the buttons)
	var info := Panel.new()
	info.add_theme_stylebox_override("panel", T.glass(T.PANEL_SOFT, 16))
	info.size = Vector2(420, 96)
	info.anchor_left = 0.5
	info.anchor_right = 0.5
	info.anchor_top = 1.0
	info.anchor_bottom = 1.0
	info.position = Vector2(-210, -300)
	_main_panel.add_child(info)
	_kart_name = T.label("", 30, T.TEXT, 0)
	_kart_name.position = Vector2(16, 8)
	info.add_child(_kart_name)
	_kart_stats = T.label("", 20, T.DIM, 0)
	_kart_stats.position = Vector2(16, 48)
	info.add_child(_kart_stats)

	# buttons
	var race := Button.new()
	race.text = "RACE"
	T.style_button(race, T.GOOD, Color(0.04, 0.1, 0.05), 40, 20)
	race.size = Vector2(440, 84)
	race.anchor_left = 0.5
	race.anchor_right = 0.5
	race.anchor_top = 1.0
	race.anchor_bottom = 1.0
	race.position = Vector2(-220, -196)
	race.pressed.connect(func() -> void: race_requested.emit(Profile.selected_arena, Profile.selected_kart))
	_main_panel.add_child(race)

	var garage := Button.new()
	garage.text = "GARAGE"
	T.style_button(garage, Color(0.22, 0.26, 0.42), T.TEXT, 30, 18)
	garage.size = Vector2(212, 70)
	garage.anchor_left = 0.5
	garage.anchor_right = 0.5
	garage.anchor_top = 1.0
	garage.anchor_bottom = 1.0
	garage.position = Vector2(-220, -100)
	garage.pressed.connect(func() -> void: _show_state("garage"))
	_main_panel.add_child(garage)

	var arenas := Button.new()
	arenas.text = "ARENAS"
	T.style_button(arenas, Color(0.22, 0.26, 0.42), T.TEXT, 30, 18)
	arenas.size = Vector2(212, 70)
	arenas.anchor_left = 0.5
	arenas.anchor_right = 0.5
	arenas.anchor_top = 1.0
	arenas.anchor_bottom = 1.0
	arenas.position = Vector2(8, -100)
	arenas.pressed.connect(func() -> void: _show_state("arenas"))
	_main_panel.add_child(arenas)


func _build_garage_panel() -> void:
	_garage_panel = _make_overlay("GARAGE")
	_garage_list = _overlay_list(_garage_panel)


func _build_arena_panel() -> void:
	_arena_panel = _make_overlay("ARENAS")
	_arena_list = _overlay_list(_arena_panel)


func _make_overlay(title_text: String) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	_ui.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.09, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bg)

	var title := T.label(title_text, 40, T.ACCENT, 6)
	title.position = Vector2(26, 22)
	root.add_child(title)

	var back := Button.new()
	back.text = "Back"
	T.style_button(back, Color(0.22, 0.26, 0.42), T.TEXT, 28, 16)
	back.size = Vector2(130, 60)
	back.anchor_left = 1.0
	back.anchor_right = 1.0
	back.position = Vector2(-156, 22)
	back.pressed.connect(func() -> void: _show_state("main"))
	root.add_child(back)

	var chip := _wallet_chip()
	chip.anchor_left = 0.5
	chip.anchor_right = 0.5
	chip.position = Vector2(-95, 26)
	root.add_child(chip)
	_overlay_wallets.append(chip.get_meta("lbl"))
	return root


func _overlay_list(root: Control) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 96
	scroll.offset_left = 20
	scroll.offset_right = -20
	scroll.offset_bottom = -20
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)
	return list


# ---------------------------------------------------------------- cards

func _rebuild_garage() -> void:
	for c in _garage_list.get_children():
		c.queue_free()
	for def: Dictionary in Garage.all():
		_garage_list.add_child(_kart_card(def))


func _kart_card(def: Dictionary) -> Control:
	var id := str(def["id"])
	var owned: bool = Profile.owns(id)
	var selected: bool = Profile.selected_kart == id
	var price := int(def["price"])

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := T.glass(Color(0.10, 0.13, 0.24, 0.95), 18)
	if selected:
		sb.border_color = T.ACCENT
		sb.set_border_width_all(3)
	card.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	var swatch := Panel.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = def.get("color", Color(1, 1, 1))
	ss.set_corner_radius_all(14)
	ss.set_border_width_all(2)
	ss.border_color = Color(1, 1, 1, 0.3)
	swatch.add_theme_stylebox_override("panel", ss)
	swatch.custom_minimum_size = Vector2(64, 64)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(swatch)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	var nm := T.label(str(def["name"]), 28, T.TEXT, 0)
	col.add_child(nm)
	var desc := T.label(str(def["desc"]), 17, T.DIM, 0)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(180, 0)
	col.add_child(desc)
	var stats: Dictionary = def["stats"]
	col.add_child(_stat_row("SPD", float(stats["speed"])))
	col.add_child(_stat_row("ACC", float(stats["accel"])))
	col.add_child(_stat_row("HND", float(stats["turn"])))

	var act := VBoxContainer.new()
	act.alignment = BoxContainer.ALIGNMENT_CENTER
	act.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(act)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 60)
	if selected:
		btn.text = "SELECTED"
		T.style_button(btn, Color(0.18, 0.5, 0.3), T.TEXT, 22, 14)
		btn.disabled = true
	elif owned:
		btn.text = "SELECT"
		T.style_button(btn, T.ACCENT2, Color(0.02, 0.08, 0.1), 24, 14)
		btn.pressed.connect(func() -> void: Profile.select_kart(id))
	else:
		btn.text = "BUY  %s" % _commas(price)
		var afford: bool = Profile.coins >= price
		T.style_button(btn, T.ACCENT if afford else Color(0.3, 0.3, 0.36), Color(0.1, 0.08, 0.0) if afford else Color(1, 1, 1, 0.5), 22, 14)
		btn.disabled = not afford
		btn.pressed.connect(func() -> void: Profile.buy(id))
	act.add_child(btn)
	return card


func _stat_row(name: String, value: float) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lab := T.label(name, 16, T.DIM, 0)
	lab.custom_minimum_size = Vector2(42, 0)
	row.add_child(lab)
	var bar := Panel.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0, 0, 0, 0.35)
	bs.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("panel", bs)
	bar.custom_minimum_size = Vector2(150, 14)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var fill := ColorRect.new()
	fill.color = T.GOOD
	var frac := clampf((value - 0.85) / 0.6, 0.06, 1.0)
	fill.size = Vector2(150.0 * frac, 14)
	fill.position = Vector2(0, 0)
	bar.add_child(fill)
	return row


func _rebuild_arenas() -> void:
	for c in _arena_list.get_children():
		c.queue_free()
	for arena: Dictionary in Arenas.all():
		_arena_list.add_child(_arena_card(arena))


func _arena_card(arena: Dictionary) -> Control:
	var id := str(arena["id"])
	var selected: bool = Profile.selected_arena == id
	var theme: Dictionary = arena["theme"]

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := T.glass(Color(0.10, 0.13, 0.24, 0.95), 18)
	if selected:
		sb.border_color = T.ACCENT
		sb.set_border_width_all(3)
	card.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	var swatch := Panel.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = theme.get("sky_horizon", Color(0.5, 0.7, 1.0))
	ss.set_corner_radius_all(14)
	ss.set_border_width_all(2)
	ss.border_color = theme.get("kerb_a", Color(1, 1, 1, 0.4))
	swatch.add_theme_stylebox_override("panel", ss)
	swatch.custom_minimum_size = Vector2(72, 72)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(swatch)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	col.add_child(T.label(str(arena["name"]), 28, T.TEXT, 0))
	var sub := T.label(str(arena["subtitle"]), 17, T.DIM, 0)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(200, 0)
	col.add_child(sub)
	var bl := Profile.best_lap_ms(id)
	var meta := "%d laps" % int(arena["laps"])
	if bl > 0:
		meta += "    Best %s" % _fmt_ms(bl)
	col.add_child(T.label(meta, 18, T.ACCENT2, 0))

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 60)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if selected:
		btn.text = "SELECTED"
		T.style_button(btn, Color(0.18, 0.5, 0.3), T.TEXT, 22, 14)
		btn.disabled = true
	else:
		btn.text = "SELECT"
		T.style_button(btn, T.ACCENT2, Color(0.02, 0.08, 0.1), 24, 14)
		btn.pressed.connect(func() -> void:
			Profile.set_arena(id)
			_show_state("main"))
	row.add_child(btn)
	return card


# ---------------------------------------------------------------- state + refresh

func _show_state(s: String) -> void:
	_state = s
	_topbar.visible = s == "main"
	_main_panel.visible = s == "main"
	_garage_panel.visible = s == "garage"
	_arena_panel.visible = s == "arenas"
	if s == "garage":
		_rebuild_garage()
	elif s == "arenas":
		_rebuild_arenas()


func _refresh_all() -> void:
	_wallet_lbl.text = _commas(Profile.coins)
	for w: Label in _overlay_wallets:
		if is_instance_valid(w):
			w.text = _commas(Profile.coins)
	var arena := Arenas.by_id(Profile.selected_arena)
	_arena_name.text = str(arena["name"])
	_arena_sub.text = str(arena["subtitle"])
	_apply_sky(arena["theme"])
	var def := Garage.by_id(Profile.selected_kart)
	_apply_kart(def)
	_kart_name.text = str(def["name"])
	var st: Dictionary = def["stats"]
	_kart_stats.text = "Speed %d   Accel %d   Handling %d" % [_pct(st["speed"]), _pct(st["accel"]), _pct(st["turn"])]


func _on_profile() -> void:
	_refresh_all()
	if _state == "garage":
		_rebuild_garage()
	elif _state == "arenas":
		_rebuild_arenas()


func _on_failed(reason: String) -> void:
	if reason == "insufficient":
		_toast("Not enough coins")
	elif reason == "not_owned":
		_toast("You don't own that kart yet")
	# Transient/infra reasons (sdk_missing, rpc_error, bad_secret, no_profile)
	# are not user-actionable - stay silent rather than alarm the player.


func _toast(text: String) -> void:
	var lbl := T.label(text, 26, T.BAD, 6)
	lbl.anchor_left = 0.5
	lbl.anchor_right = 0.5
	lbl.anchor_top = 1.0
	lbl.anchor_bottom = 1.0
	lbl.position = Vector2(-260, -360)
	lbl.size = Vector2(520, 40)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ui.add_child(lbl)
	var t := create_tween()
	t.tween_interval(1.4)
	t.tween_property(lbl, "modulate:a", 0.0, 0.6)
	t.tween_callback(lbl.queue_free)


func _read_url_arena() -> void:
	if not OS.has_feature("web"):
		return
	var v: Variant = JavaScriptBridge.eval("(new URLSearchParams(location.search)).get('arena')||''", true)
	var id := str(v)
	if id != "" and Arenas.ids().has(id):
		Profile.selected_arena = id


func _pct(v: Variant) -> int:
	return int(round(float(v) * 100.0))


func _fmt_ms(ms: int) -> String:
	var secs := float(ms) / 1000.0
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
