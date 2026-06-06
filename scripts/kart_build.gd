class_name KartBuild
extends RefCounted
## Builds cute low-poly kart models (code-only meshes). The model faces -Z (Godot
## forward). Each catalog vehicle has a `style` that tweaks proportions + accents so
## the karts look visually distinct, plus emissive trim on the high-end machines.

const PALETTE := [
	Color(0.95, 0.27, 0.21), Color(0.20, 0.55, 0.95), Color(0.30, 0.80, 0.35),
	Color(1.00, 0.78, 0.18), Color(0.70, 0.35, 0.90), Color(1.00, 0.50, 0.20),
	Color(0.20, 0.80, 0.80), Color(0.95, 0.45, 0.70),
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
	return build_def({"color": color, "style": "classic"})


static func _params(style: String) -> Dictionary:
	match style:
		"sport":
			return {"chassis": Vector3(1.45, 0.36, 2.30), "nose": 0.9, "spoiler": Vector3(1.4, 0.08, 0.4), "spoiler_y": 0.56, "wf": 0.32, "wr": 0.44, "emit": 0.0, "stripe": true}
		"drift":
			return {"chassis": Vector3(1.62, 0.40, 2.0), "nose": 0.7, "spoiler": Vector3(1.6, 0.1, 0.46), "spoiler_y": 0.62, "wf": 0.32, "wr": 0.52, "emit": 0.0, "stripe": false}
		"heavy":
			return {"chassis": Vector3(1.72, 0.55, 2.0), "nose": 0.7, "spoiler": Vector3(1.5, 0.12, 0.4), "spoiler_y": 0.66, "wf": 0.46, "wr": 0.52, "emit": 0.0, "stripe": false}
		"gt":
			return {"chassis": Vector3(1.42, 0.34, 2.42), "nose": 1.05, "spoiler": Vector3(1.45, 0.08, 0.42), "spoiler_y": 0.5, "wf": 0.32, "wr": 0.46, "emit": 0.35, "stripe": true}
		"ace":
			return {"chassis": Vector3(1.44, 0.34, 2.44), "nose": 1.05, "spoiler": Vector3(1.5, 0.09, 0.44), "spoiler_y": 0.52, "wf": 0.32, "wr": 0.46, "emit": 1.3, "stripe": true}
		_:
			return {"chassis": Vector3(1.5, 0.42, 2.1), "nose": 0.7, "spoiler": Vector3(1.3, 0.08, 0.35), "spoiler_y": 0.55, "wf": 0.32, "wr": 0.42, "emit": 0.0, "stripe": false}


static func build_def(def: Dictionary) -> Dictionary:
	var color: Color = def.get("color", Color(0.3, 0.8, 0.35))
	var p := _params(str(def.get("style", "classic")))
	var emit: float = p["emit"]

	var root := Node3D.new()
	root.name = "KartModel"

	var cs: Vector3 = p["chassis"]
	var chassis := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = cs
	chassis.mesh = cm
	chassis.material_override = _mat(color, 0.42, emit * 0.4)
	chassis.position = Vector3(0, 0.05, 0)
	root.add_child(chassis)

	var nose := MeshInstance3D.new()
	var nm := BoxMesh.new()
	nm.size = Vector3(cs.x * 0.74, 0.3, p["nose"])
	nose.mesh = nm
	nose.material_override = _mat(color.lightened(0.15), 0.4, emit * 0.4)
	nose.position = Vector3(0, 0.02, -cs.z * 0.5 - p["nose"] * 0.45)
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
	helmet.material_override = _mat(color.lightened(0.25), 0.3, emit * 0.6)
	helmet.position = Vector3(0, 0.95, 0.28)
	root.add_child(helmet)

	var spoiler := MeshInstance3D.new()
	var spm := BoxMesh.new()
	spm.size = p["spoiler"]
	spoiler.mesh = spm
	spoiler.material_override = _mat(color.darkened(0.1), 0.4, emit)
	spoiler.position = Vector3(0, p["spoiler_y"], cs.z * 0.5)
	root.add_child(spoiler)

	# headlights
	for sx: float in [-1.0, 1.0]:
		var hl := MeshInstance3D.new()
		var hlm := SphereMesh.new()
		hlm.radius = 0.12
		hlm.height = 0.24
		hlm.radial_segments = 6
		hlm.rings = 3
		hl.mesh = hlm
		hl.material_override = _mat(Color(1.0, 0.96, 0.8), 0.2, 1.6)
		hl.position = Vector3(sx * cs.x * 0.32, 0.08, -cs.z * 0.5 - p["nose"] * 0.85)
		root.add_child(hl)

	if bool(p["stripe"]):
		var stripe := MeshInstance3D.new()
		var stm := BoxMesh.new()
		stm.size = Vector3(0.22, 0.03, cs.z * 0.95)
		stripe.mesh = stm
		stripe.material_override = _mat(Color(1, 1, 1, 1).lerp(color, 0.0), 0.3, emit * 0.8)
		stripe.position = Vector3(0, 0.27, -0.1)
		root.add_child(stripe)

	var wheels: Array[MeshInstance3D] = []
	var wmat := _mat(Color(0.12, 0.12, 0.14), 0.8)
	var positions := [
		Vector3(cs.x * 0.52, -0.05, -0.7),
		Vector3(-cs.x * 0.52, -0.05, -0.7),
		Vector3(cs.x * 0.55, -0.02, 0.78),
		Vector3(-cs.x * 0.55, -0.02, 0.78),
	]
	var sizes := [p["wf"], p["wf"], p["wr"], p["wr"]]
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
