class_name KartBuild
extends RefCounted
## Builds a cute low-poly kart model (code-only meshes) in a Node3D.
## The model faces -Z (Godot forward). Wheel meshes are returned so the caller
## can spin them with speed.

const PALETTE := [
	Color(0.95, 0.27, 0.21),  # red
	Color(0.20, 0.55, 0.95),  # blue
	Color(0.30, 0.80, 0.35),  # green
	Color(1.00, 0.78, 0.18),  # yellow
	Color(0.70, 0.35, 0.90),  # purple
	Color(1.00, 0.50, 0.20),  # orange
	Color(0.20, 0.80, 0.80),  # teal
	Color(0.95, 0.45, 0.70),  # pink
]


static func color_for(id: String) -> Color:
	var h := 0
	for i in id.length():
		h = (h * 31 + id.unicode_at(i)) & 0x7fffffff
	return PALETTE[h % PALETTE.size()]


static func _mat(c: Color, rough := 0.6, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = 0.0
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


static func build(color: Color) -> Dictionary:
	var root := Node3D.new()
	root.name = "KartModel"

	var chassis := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(1.5, 0.42, 2.1)
	chassis.mesh = cm
	chassis.material_override = _mat(color, 0.45)
	chassis.position = Vector3(0, 0.05, 0)
	root.add_child(chassis)

	var nose := MeshInstance3D.new()
	var nm := BoxMesh.new()
	nm.size = Vector3(1.1, 0.3, 0.7)
	nose.mesh = nm
	nose.material_override = _mat(color.lightened(0.15), 0.4)
	nose.position = Vector3(0, 0.02, -1.15)
	root.add_child(nose)

	var cabin := MeshInstance3D.new()
	var cab := BoxMesh.new()
	cab.size = Vector3(0.95, 0.5, 0.95)
	cabin.mesh = cab
	cabin.material_override = _mat(color.darkened(0.2), 0.5)
	cabin.position = Vector3(0, 0.4, 0.25)
	root.add_child(cabin)

	var seat := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.3
	sm.height = 0.6
	seat.mesh = sm
	seat.material_override = _mat(Color(0.98, 0.82, 0.66), 0.7)
	seat.position = Vector3(0, 0.78, 0.3)
	root.add_child(seat)

	var helmet := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.34
	hm.height = 0.5
	helmet.mesh = hm
	helmet.material_override = _mat(color.lightened(0.25), 0.3)
	helmet.position = Vector3(0, 0.95, 0.28)
	root.add_child(helmet)

	var spoiler := MeshInstance3D.new()
	var spm := BoxMesh.new()
	spm.size = Vector3(1.3, 0.08, 0.35)
	spoiler.mesh = spm
	spoiler.material_override = _mat(color.darkened(0.1), 0.4)
	spoiler.position = Vector3(0, 0.55, 1.05)
	root.add_child(spoiler)

	var wheels: Array[MeshInstance3D] = []
	var wmat := _mat(Color(0.12, 0.12, 0.14), 0.8)
	var positions := [
		Vector3(0.78, -0.05, -0.7),
		Vector3(-0.78, -0.05, -0.7),
		Vector3(0.82, -0.02, 0.78),
		Vector3(-0.82, -0.02, 0.78),
	]
	var sizes := [0.32, 0.32, 0.42, 0.42]
	for i in positions.size():
		var w := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = sizes[i]
		cyl.bottom_radius = sizes[i]
		cyl.height = 0.3
		cyl.radial_segments = 12
		w.mesh = cyl
		w.material_override = wmat
		w.rotation = Vector3(0, 0, PI / 2.0)
		w.position = positions[i]
		root.add_child(w)
		wheels.append(w)

	return {"root": root, "wheels": wheels, "body": chassis}
