class_name Items
extends RefCounted
## Code-built meshes for pickups and hazards. Game logic (pickup, collision,
## respawn, shell travel) lives in game.gd; these are just the visuals.


static func _mat(c: Color, emit := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.roughness = 0.4
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
	bm.size = Vector3(1.6, 1.6, 1.6)
	box.mesh = bm
	box.material_override = _mat(Color(0.3, 0.85, 1.0), 1.4, 0.55)
	root.add_child(box)
	var q := Label3D.new()
	q.text = "?"
	q.font_size = 130
	q.pixel_size = 0.01
	q.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	q.modulate = Color(1, 1, 1)
	q.outline_size = 20
	q.outline_modulate = Color(0, 0, 0, 0.9)
	root.add_child(q)
	return root


static func make_coin() -> Node3D:
	var root := Node3D.new()
	var c := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.55
	cm.bottom_radius = 0.55
	cm.height = 0.12
	cm.radial_segments = 14
	c.mesh = cm
	c.material_override = _mat(Color(1.0, 0.82, 0.18), 0.9)
	c.rotation = Vector3(PI / 2.0, 0, 0)
	root.add_child(c)
	return root


static func make_banana() -> Node3D:
	var root := Node3D.new()
	var b := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.32
	cap.height = 1.1
	cap.radial_segments = 8
	cap.rings = 4
	b.mesh = cap
	b.material_override = _mat(Color(1.0, 0.85, 0.1), 0.2)
	b.rotation = Vector3(0, 0, PI / 2.0)
	b.position = Vector3(0, 0.32, 0)
	root.add_child(b)
	return root


static func make_shell(color := Color(0.2, 0.85, 0.3)) -> Node3D:
	var root := Node3D.new()
	var s := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 10
	sm.rings = 6
	s.mesh = sm
	s.material_override = _mat(color, 1.2)
	s.position = Vector3(0, 0.5, 0)
	root.add_child(s)
	return root
