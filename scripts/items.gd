class_name Items
extends RefCounted
## Code-built meshes for pickups and hazards. Game logic (pickup, collision, respawn,
## shell travel) lives in game.gd; these are just the visuals. The item box is a glassy
## glowing cube around an inner core; coins are bevelled metallic gold; the shell has a
## banded carapace.


static func _mat(c: Color, emit := 0.0, alpha := 1.0, rough := 0.4, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.roughness = rough
	m.metallic = metal
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


static func make_item_box() -> Node3D:
	var root := Node3D.new()
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.7, 1.7, 1.7)
	box.mesh = bm
	box.material_override = _mat(Color(0.35, 0.85, 1.0), 1.3, 0.5, 0.1)
	box.name = "shell"
	root.add_child(box)

	var core := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.55
	cm.height = 1.1
	cm.radial_segments = 12
	cm.rings = 8
	core.mesh = cm
	core.material_override = _mat(Color(1.0, 0.95, 0.5), 1.8, 1.0, 0.2)
	core.name = "core"
	root.add_child(core)

	var q := Label3D.new()
	q.text = "?"
	q.font_size = 140
	q.pixel_size = 0.01
	q.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	q.modulate = Color(1, 1, 1)
	q.outline_size = 22
	q.outline_modulate = Color(0, 0, 0, 0.9)
	root.add_child(q)
	return root


static func make_coin() -> Node3D:
	var root := Node3D.new()
	var gold := _mat(Color(1.0, 0.82, 0.20), 0.55, 1.0, 0.18, 0.9)
	var c := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.58
	cm.bottom_radius = 0.58
	cm.height = 0.10
	cm.radial_segments = 18
	c.mesh = cm
	c.material_override = gold
	c.rotation = Vector3(PI / 2.0, 0, 0)
	root.add_child(c)
	var rim := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.5
	rm.outer_radius = 0.62
	rim.mesh = rm
	rim.material_override = _mat(Color(1.0, 0.92, 0.4), 0.9, 1.0, 0.2, 0.6)
	root.add_child(rim)
	return root


static func make_banana() -> Node3D:
	var root := Node3D.new()
	var mat := _mat(Color(1.0, 0.85, 0.1), 0.0, 1.0, 0.3)
	for seg in 3:
		var b := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.26 - seg * 0.04
		cap.height = 0.7
		cap.radial_segments = 8
		cap.rings = 3
		b.mesh = cap
		b.material_override = mat
		b.rotation = Vector3(0, 0, PI / 2.0 - (seg - 1) * 0.35)
		b.position = Vector3((seg - 1) * 0.28, 0.32 + absf(seg - 1) * 0.07, 0)
		root.add_child(b)
	return root


static func make_shell(color := Color(0.2, 0.85, 0.3)) -> Node3D:
	var root := Node3D.new()
	var s := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.52
	sm.height = 0.92
	sm.radial_segments = 12
	sm.rings = 7
	s.mesh = sm
	s.material_override = _mat(color, 1.1, 1.0, 0.35)
	s.position = Vector3(0, 0.5, 0)
	root.add_child(s)
	var band := MeshInstance3D.new()
	var bm := TorusMesh.new()
	bm.inner_radius = 0.46
	bm.outer_radius = 0.56
	band.mesh = bm
	band.material_override = _mat(Color(0.98, 0.98, 0.95), 0.4, 1.0, 0.4)
	band.rotation = Vector3(PI / 2.0, 0, 0)
	band.position = Vector3(0, 0.5, 0)
	root.add_child(band)
	return root
