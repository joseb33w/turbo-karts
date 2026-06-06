class_name KartBuild
extends RefCounted
## Code-only kart models (no imported meshes). Still low-poly for mobile, but a lot less
## "boxy" than before: a tapered hull with side pods + a front splitter, a tinted
## windshield, a little driver (body, helmet, visor, arms), twin exhausts, a rear wing,
## and wheels with light hubcaps that the game rolls with speed. Higher tiers get an
## emissive accent. The model faces -Z (Godot forward); returns {root, wheels, body}.

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


static func _mat(c: Color, rough := 0.45, metal := 0.0, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


static func _glass(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.08
	m.metallic = 0.5
	return m


static func build(color: Color) -> Dictionary:
	return build_def({"color": color, "style": "classic"})


static func _params(style: String) -> Dictionary:
	match style:
		"sport":
			return {"chassis": Vector3(1.45, 0.34, 2.34), "nose": 0.95, "wing": 0.58, "wf": 0.34, "wr": 0.46, "emit": 0.0, "metal": 0.35}
		"drift":
			return {"chassis": Vector3(1.62, 0.38, 2.04), "nose": 0.72, "wing": 0.64, "wf": 0.34, "wr": 0.54, "emit": 0.0, "metal": 0.2}
		"heavy":
			return {"chassis": Vector3(1.74, 0.52, 2.04), "nose": 0.72, "wing": 0.66, "wf": 0.48, "wr": 0.56, "emit": 0.0, "metal": 0.15}
		"gt":
			return {"chassis": Vector3(1.42, 0.32, 2.46), "nose": 1.08, "wing": 0.5, "wf": 0.34, "wr": 0.48, "emit": 0.4, "metal": 0.5}
		"ace":
			return {"chassis": Vector3(1.44, 0.32, 2.48), "nose": 1.08, "wing": 0.52, "wf": 0.34, "wr": 0.48, "emit": 1.3, "metal": 0.6}
		_:
			return {"chassis": Vector3(1.5, 0.40, 2.12), "nose": 0.72, "wing": 0.56, "wf": 0.34, "wr": 0.44, "emit": 0.0, "metal": 0.25}


static func build_def(def: Dictionary) -> Dictionary:
	var color: Color = def.get("color", Color(0.3, 0.8, 0.35))
	var accent := color.lightened(0.28)
	var dark := color.darkened(0.34)
	var p := _params(str(def.get("style", "classic")))
	var emit: float = p["emit"]
	var metal: float = p["metal"]
	var cs: Vector3 = p["chassis"]

	var root := Node3D.new()
	root.name = "KartModel"

	var body_mat := _mat(color, 0.30, metal, emit * 0.35)

	# lower hull (slightly sunk)
	var hull := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(cs.x, cs.y, cs.z)
	hull.mesh = hm
	hull.material_override = body_mat
	hull.position = Vector3(0, 0.02, 0)
	root.add_child(hull)

	# floor pan / splitter (wide thin lip at the front)
	var pan := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(cs.x * 1.04, 0.10, cs.z * 0.5)
	pan.mesh = pm
	pan.material_override = _mat(Color(0.10, 0.11, 0.13), 0.6)
	pan.position = Vector3(0, -cs.y * 0.5 + 0.02, -cs.z * 0.28)
	root.add_child(pan)

	# pointed nose
	var nose := MeshInstance3D.new()
	var nm := PrismMesh.new()
	nm.size = Vector3(cs.x * 0.72, 0.30, p["nose"] * 1.25)
	nose.mesh = nm
	nose.material_override = _mat(accent, 0.28, metal, emit * 0.35)
	nose.rotation = Vector3(PI * 0.5, PI, 0)
	nose.position = Vector3(0, 0.04, -cs.z * 0.5 - p["nose"] * 0.42)
	root.add_child(nose)

	# side pods
	for sx: float in [-1.0, 1.0]:
		var pod := MeshInstance3D.new()
		var pdm := BoxMesh.new()
		pdm.size = Vector3(0.32, 0.30, cs.z * 0.62)
		pod.mesh = pdm
		pod.material_override = _mat(dark, 0.35, metal)
		pod.position = Vector3(sx * (cs.x * 0.5 + 0.10), 0.0, 0.18)
		root.add_child(pod)

	# cockpit surround + tinted windshield
	var cowl := MeshInstance3D.new()
	var cwm := BoxMesh.new()
	cwm.size = Vector3(cs.x * 0.78, 0.42, 1.05)
	cowl.mesh = cwm
	cowl.material_override = _mat(dark, 0.4, metal)
	cowl.position = Vector3(0, 0.34, 0.28)
	root.add_child(cowl)

	var screen := MeshInstance3D.new()
	var scm := BoxMesh.new()
	scm.size = Vector3(cs.x * 0.66, 0.40, 0.12)
	screen.mesh = scm
	screen.material_override = _glass(Color(0.4, 0.7, 0.95))
	screen.rotation = Vector3(-0.5, 0, 0)
	screen.position = Vector3(0, 0.52, -0.18)
	root.add_child(screen)

	# driver: torso, helmet, visor, hands
	var torso := MeshInstance3D.new()
	var tm := CapsuleMesh.new()
	tm.radius = 0.24
	tm.height = 0.7
	tm.radial_segments = 8
	tm.rings = 3
	torso.mesh = tm
	torso.material_override = _mat(dark.darkened(0.1), 0.6)
	torso.rotation = Vector3(0.25, 0, 0)
	torso.position = Vector3(0, 0.6, 0.34)
	root.add_child(torso)

	var helmet := MeshInstance3D.new()
	var helm := SphereMesh.new()
	helm.radius = 0.26
	helm.height = 0.52
	helm.radial_segments = 12
	helm.rings = 8
	helmet.mesh = helm
	helmet.material_override = _mat(accent, 0.2, 0.2, emit * 0.5)
	helmet.position = Vector3(0, 0.92, 0.30)
	root.add_child(helmet)

	var visor := MeshInstance3D.new()
	var vm := BoxMesh.new()
	vm.size = Vector3(0.34, 0.12, 0.16)
	visor.mesh = vm
	visor.material_override = _glass(Color(0.1, 0.12, 0.16))
	visor.position = Vector3(0, 0.92, 0.10)
	root.add_child(visor)

	for sx2: float in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var arm_m := CapsuleMesh.new()
		arm_m.radius = 0.09
		arm_m.height = 0.5
		arm_m.radial_segments = 6
		arm_m.rings = 2
		arm.mesh = arm_m
		arm.material_override = _mat(dark.darkened(0.1), 0.6)
		arm.rotation = Vector3(1.1, 0, sx2 * 0.2)
		arm.position = Vector3(sx2 * 0.22, 0.55, 0.02)
		root.add_child(arm)

	# steering wheel hint
	var sw := MeshInstance3D.new()
	var swm := TorusMesh.new()
	swm.inner_radius = 0.10
	swm.outer_radius = 0.17
	sw.mesh = swm
	sw.material_override = _mat(Color(0.08, 0.08, 0.1), 0.5)
	sw.rotation = Vector3(1.2, 0, 0)
	sw.position = Vector3(0, 0.5, -0.12)
	root.add_child(sw)

	# rear wing on two pylons
	var wing := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(cs.x * 1.02, 0.07, 0.42)
	wing.mesh = wm
	wing.material_override = _mat(accent, 0.3, metal, emit)
	wing.position = Vector3(0, p["wing"] + 0.06, cs.z * 0.5 + 0.05)
	root.add_child(wing)
	for sx3: float in [-1.0, 1.0]:
		var pylon := MeshInstance3D.new()
		var pym := BoxMesh.new()
		pym.size = Vector3(0.08, p["wing"] * 0.7, 0.2)
		pylon.mesh = pym
		pylon.material_override = _mat(dark, 0.4)
		pylon.position = Vector3(sx3 * cs.x * 0.34, p["wing"] * 0.7, cs.z * 0.5)
		root.add_child(pylon)

	# twin exhausts with hot tips
	for sx4: float in [-1.0, 1.0]:
		var pipe := MeshInstance3D.new()
		var ppm := CylinderMesh.new()
		ppm.top_radius = 0.07
		ppm.bottom_radius = 0.07
		ppm.height = 0.4
		ppm.radial_segments = 8
		pipe.mesh = ppm
		pipe.material_override = _mat(Color(0.5, 0.5, 0.55), 0.25, 0.9)
		pipe.rotation = Vector3(PI * 0.5, 0, 0)
		pipe.position = Vector3(sx4 * 0.24, 0.14, cs.z * 0.5 + 0.12)
		root.add_child(pipe)
		var tip := MeshInstance3D.new()
		var tipm := CylinderMesh.new()
		tipm.top_radius = 0.075
		tipm.bottom_radius = 0.075
		tipm.height = 0.06
		tip.mesh = tipm
		tip.material_override = _mat(Color(1.0, 0.45, 0.15), 0.3, 0.0, 1.6)
		tip.rotation = Vector3(PI * 0.5, 0, 0)
		tip.position = Vector3(sx4 * 0.24, 0.14, cs.z * 0.5 + 0.32)
		root.add_child(tip)

	# headlights
	for sx5: float in [-1.0, 1.0]:
		var hl := MeshInstance3D.new()
		var hlm := SphereMesh.new()
		hlm.radius = 0.11
		hlm.height = 0.22
		hlm.radial_segments = 6
		hlm.rings = 3
		hl.mesh = hlm
		hl.material_override = _mat(Color(1.0, 0.96, 0.8), 0.2, 0.0, 1.8)
		hl.position = Vector3(sx5 * cs.x * 0.3, 0.08, -cs.z * 0.5 - p["nose"] * 0.7)
		root.add_child(hl)

	# wheels with hubcaps
	var wheels: Array[MeshInstance3D] = []
	var tire_mat := _mat(Color(0.09, 0.09, 0.11), 0.85)
	var hub_mat := _mat(Color(0.78, 0.80, 0.86), 0.25, 0.7)
	var positions := [
		Vector3(cs.x * 0.54, -0.03, -0.72),
		Vector3(-cs.x * 0.54, -0.03, -0.72),
		Vector3(cs.x * 0.57, 0.0, 0.80),
		Vector3(-cs.x * 0.57, 0.0, 0.80),
	]
	var sizes := [p["wf"], p["wf"], p["wr"], p["wr"]]
	for i in positions.size():
		var w := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = sizes[i]
		cyl.bottom_radius = sizes[i]
		cyl.height = 0.32
		cyl.radial_segments = 14
		w.mesh = cyl
		w.material_override = tire_mat
		w.rotation = Vector3(0, 0, PI / 2.0)
		w.position = positions[i]
		root.add_child(w)
		var hub := MeshInstance3D.new()
		var hubm := CylinderMesh.new()
		hubm.top_radius = sizes[i] * 0.55
		hubm.bottom_radius = sizes[i] * 0.55
		hubm.height = 0.34
		hubm.radial_segments = 8
		hub.mesh = hubm
		hub.material_override = hub_mat
		hub.rotation = Vector3(0, 0, PI / 2.0)
		hub.position = positions[i]
		root.add_child(hub)
		wheels.append(w)

	return {"root": root, "wheels": wheels, "body": hull}
