extends Node3D
## Procedural looping race circuit, built from an arena spec (see arenas.gd). A closed
## Catmull-Rom curve from the spec's control points defines the centerline; road / kerb
## / checker meshes are generated from it, themed per arena (sky, sun, ground, kerbs,
## fog, water, decor). The kart asks this node where the road is (closest offset,
## lateral distance, surface height, tangent) instead of using mesh collision.

const HALF_WIDTH := 7.0
const GRASS_MARGIN := 6.5            # drivable grass beyond the road edge
const SHORTCUT_HALF := 3.2

var spec: Dictionary = {}
var theme: Dictionary = {}
var laps := 3

var curve := Curve3D.new()
var length := 0.0

var ramp_pads: Array[Dictionary] = []      # {offset, pos, dir}
var item_offsets: Array[float] = []
var coin_specs: Array[Dictionary] = []     # {offset, side}
var _shortcut_a := Vector3.ZERO
var _shortcut_b := Vector3.ZERO
var _shortcut_active := false


func build(arena: Dictionary) -> void:
	spec = arena
	theme = arena.get("theme", {})
	laps = int(arena.get("laps", 3))
	_build_curve()
	length = curve.get_baked_length()
	_define_features()
	_build_environment()
	_build_road()
	_build_kerbs()
	_build_start_line()
	_build_ramps()
	_build_decor()


func _control() -> Array:
	return spec.get("control", [])


func _build_curve() -> void:
	curve.bake_interval = 0.6
	var ctrl := _control()
	var m := ctrl.size()
	var steps := 14
	for i in m:
		var p0: Vector3 = ctrl[(i - 1 + m) % m]
		var p1: Vector3 = ctrl[i]
		var p2: Vector3 = ctrl[(i + 1) % m]
		var p3: Vector3 = ctrl[(i + 2) % m]
		for s in steps:
			var t := float(s) / float(steps)
			curve.add_point(_catmull(p0, p1, p2, p3, t))
	curve.add_point(ctrl[0])


func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _define_features() -> void:
	for off: float in [length * 0.16, length * 0.45]:
		var pos := curve.sample_baked(off)
		var dir := tangent_at(off)
		ramp_pads.append({"offset": off, "pos": pos, "dir": dir})

	for i in 6:
		item_offsets.append(fmod(length * (0.09 + 0.155 * float(i)), length))

	for i in 30:
		coin_specs.append({"offset": fmod(length * (0.04 + 0.032 * float(i)), length), "side": (-1.0 if i % 2 == 0 else 1.0) * (1.0 if i % 4 < 2 else 2.4)})

	if bool(theme.get("shortcut", false)):
		_shortcut_a = curve.sample_baked(length * 0.60)
		_shortcut_b = curve.sample_baked(length * 0.72)
		_shortcut_active = true


func tangent_at(offset: float) -> Vector3:
	var a := curve.sample_baked(fposmod(offset - 1.0, length))
	var b := curve.sample_baked(fposmod(offset + 1.0, length))
	var d := b - a
	d.y = 0.0
	if d.length() < 0.001:
		return Vector3(0, 0, -1)
	return d.normalized()


func sample(offset: float) -> Vector3:
	return curve.sample_baked(fposmod(offset, length))


## Returns where the kart is relative to the track surface.
func probe(p: Vector3) -> Dictionary:
	var offset := curve.get_closest_offset(p)
	var center := curve.sample_baked(offset)
	var flat_p := Vector3(p.x, center.y, p.z)
	var lateral := flat_p.distance_to(center)
	var surface_y := center.y
	var on_road := lateral <= HALF_WIDTH
	var on_grass := lateral <= HALF_WIDTH + GRASS_MARGIN

	if _shortcut_active:
		var sc := _dist_to_segment(Vector3(p.x, 0, p.z), Vector3(_shortcut_a.x, 0, _shortcut_a.z), Vector3(_shortcut_b.x, 0, _shortcut_b.z))
		if sc <= SHORTCUT_HALF:
			on_road = true
			on_grass = true
			surface_y = 0.0

	return {
		"offset": offset,
		"center": center,
		"lateral": lateral,
		"surface_y": surface_y,
		"on_road": on_road,
		"on_grass": on_grass,
		"tangent": tangent_at(offset),
	}


func _dist_to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func grid_transforms(count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var base := length - 10.0
	for i in count:
		var off := fposmod(base - float(i) * 4.5, length)
		var c := curve.sample_baked(off)
		var dir := tangent_at(off)
		var side := -1.0 if i % 2 == 0 else 1.0
		var normal := Vector3(-dir.z, 0, dir.x)
		var pos := c + normal * side * 2.6 + Vector3(0, 0.6, 0)
		out.append({"pos": pos, "yaw": atan2(-dir.x, -dir.z)})
	return out


# ---------------------------------------------------------------- meshes

func _mat(c: Color, rough := 0.9, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = 0.0
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


func _vcolor_mat(unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = theme.get("sky_top", Color(0.25, 0.6, 1.0))
	psm.sky_horizon_color = theme.get("sky_horizon", Color(0.7, 0.88, 1.0))
	psm.ground_horizon_color = theme.get("ground_horizon", Color(0.7, 0.88, 1.0))
	psm.ground_bottom_color = theme.get("ground_bottom", Color(0.5, 0.7, 0.9))
	psm.sun_angle_max = float(theme.get("sun_angle", 30.0))
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = float(theme.get("ambient", 1.1))
	if bool(theme.get("fog", true)):
		env.fog_enabled = true
		env.fog_light_color = theme.get("fog_color", Color(0.7, 0.86, 1.0))
		env.fog_density = float(theme.get("fog_density", 0.0016))
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = theme.get("sun_rot", Vector3(-52, -48, 0))
	sun.light_energy = float(theme.get("sun_energy", 1.15))
	sun.light_color = theme.get("sun_color", Color(1.0, 0.97, 0.9))
	sun.shadow_enabled = false
	add_child(sun)

	if bool(theme.get("water", false)):
		var water := MeshInstance3D.new()
		var wp := PlaneMesh.new()
		wp.size = Vector2(2000, 2000)
		water.mesh = wp
		water.material_override = _mat(theme.get("water_color", Color(0.30, 0.62, 0.85)), 0.3)
		water.position = Vector3(0, float(theme.get("water_y", -5.0)), 0)
		add_child(water)

	var ground := MeshInstance3D.new()
	var gp := PlaneMesh.new()
	gp.size = Vector2(640, 640)
	ground.mesh = gp
	ground.material_override = _mat(theme.get("ground", Color(0.36, 0.72, 0.34)))
	ground.position = Vector3(0, -0.05, 0)
	add_child(ground)


func _build_road() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 260
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	for i in n + 1:
		var off := length * float(i) / float(n)
		var c := curve.sample_baked(fposmod(off, length))
		var dir := tangent_at(off)
		var nrm := Vector3(-dir.z, 0, dir.x)
		var l := c + nrm * HALF_WIDTH + Vector3(0, 0.02, 0)
		var r := c - nrm * HALF_WIDTH + Vector3(0, 0.02, 0)
		if i > 0:
			_quad(st, prev_l, l, r, prev_r)
		prev_l = l
		prev_r = r
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat(theme.get("road", Color(0.28, 0.29, 0.34)))
	add_child(mi)


func _build_kerbs() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 200
	var inner := HALF_WIDTH
	var outer := HALF_WIDTH + 0.8
	var emit := float(theme.get("kerb_emit", 0.0))
	var ca: Color = theme.get("kerb_a", Color(0.92, 0.2, 0.2))
	var cb: Color = theme.get("kerb_b", Color(0.96, 0.96, 0.96))
	for side: float in [-1.0, 1.0]:
		var pl := Vector3.ZERO
		var po := Vector3.ZERO
		for i in n + 1:
			var off := length * float(i) / float(n)
			var c := curve.sample_baked(fposmod(off, length))
			var dir := tangent_at(off)
			var nrm := Vector3(-dir.z, 0, dir.x) * side
			var a := c + nrm * inner + Vector3(0, 0.06, 0)
			var b := c + nrm * outer + Vector3(0, 0.06, 0)
			if i > 0:
				var col := ca if i % 2 == 0 else cb
				_quad_c(st, pl, a, b, po, col)
			pl = a
			po = b
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _vcolor_mat(emit > 0.0)
	add_child(mi)


func _build_start_line() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var off0 := 3.0
	var dir := tangent_at(off0)
	var nrm := Vector3(-dir.z, 0, dir.x)
	var c0 := curve.sample_baked(off0)
	var cols := 10
	var depth := 4.0
	for cx in cols:
		var fx0 := float(cx) / float(cols)
		var fx1 := float(cx + 1) / float(cols)
		var x0 := (fx0 - 0.5) * 2.0 * HALF_WIDTH
		var x1 := (fx1 - 0.5) * 2.0 * HALF_WIDTH
		for rz in 2:
			var z0 := c0 + dir * (depth * float(rz) - depth * 0.5)
			var z1 := c0 + dir * (depth * float(rz + 1) - depth * 0.5)
			var col := Color.WHITE if (cx + rz) % 2 == 0 else Color(0.08, 0.08, 0.08)
			var p1 := z0 + nrm * x0 + Vector3(0, 0.05, 0)
			var p2 := z1 + nrm * x0 + Vector3(0, 0.05, 0)
			var p3 := z1 + nrm * x1 + Vector3(0, 0.05, 0)
			var p4 := z0 + nrm * x1 + Vector3(0, 0.05, 0)
			_quad_c(st, p1, p2, p3, p4, col)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _vcolor_mat()
	add_child(mi)


func _build_ramps() -> void:
	for pad: Dictionary in ramp_pads:
		var pos: Vector3 = pad["pos"]
		var dir: Vector3 = pad["dir"]
		var ramp := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(2.0 * HALF_WIDTH - 1.0, 1.6, 5.0)
		ramp.mesh = pm
		ramp.material_override = _mat(Color(1.0, 0.62, 0.2), 0.5, 0.4 if float(theme.get("kerb_emit", 0.0)) > 0.0 else 0.0)
		ramp.position = pos + Vector3(0, 0.8, 0)
		ramp.rotation.y = atan2(dir.x, dir.z)
		add_child(ramp)


func _build_decor() -> void:
	var kind := str(theme.get("decor", "trees"))
	if kind == "none":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var count := 26
	for i in count:
		var off := length * float(i) / float(count) + rng.randf_range(-4.0, 4.0)
		var c := curve.sample_baked(fposmod(off, length))
		var dir := tangent_at(off)
		var nrm := Vector3(-dir.z, 0, dir.x)
		var side := 1.0 if i % 2 == 0 else -1.0
		var dist := HALF_WIDTH + GRASS_MARGIN + rng.randf_range(2.0, 10.0)
		var base := c + nrm * side * dist
		base.y = 0.0
		match kind:
			"cacti": _make_cactus(base, rng)
			"city": _make_building(base, rng)
			_: _make_tree(base, rng)


func _make_tree(base: Vector3, rng: RandomNumberGenerator) -> void:
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.3
	tm.bottom_radius = 0.4
	tm.height = 2.0
	trunk.mesh = tm
	trunk.material_override = _mat(Color(0.5, 0.34, 0.2))
	trunk.position = base + Vector3(0, 1.0, 0)
	add_child(trunk)
	var leaf := MeshInstance3D.new()
	var lm := SphereMesh.new()
	var r := rng.randf_range(1.6, 2.4)
	lm.radius = r
	lm.height = r * 2.0
	leaf.mesh = lm
	var g := rng.randf_range(0.55, 0.8)
	leaf.material_override = _mat(Color(0.2, g, 0.28))
	leaf.position = base + Vector3(0, 2.6, 0)
	add_child(leaf)


func _make_cactus(base: Vector3, rng: RandomNumberGenerator) -> void:
	var col := Color(0.20, 0.52, 0.28)
	var mat := _mat(col)
	var h := rng.randf_range(2.2, 3.6)
	var trunk := MeshInstance3D.new()
	var tm := CapsuleMesh.new()
	tm.radius = 0.45
	tm.height = h
	tm.radial_segments = 8
	tm.rings = 3
	trunk.mesh = tm
	trunk.material_override = mat
	trunk.position = base + Vector3(0, h * 0.5, 0)
	add_child(trunk)
	for s: float in [-1.0, 1.0]:
		if rng.randf() < 0.4:
			continue
		var arm := MeshInstance3D.new()
		var am := CapsuleMesh.new()
		am.radius = 0.28
		am.height = 1.3
		am.radial_segments = 6
		am.rings = 2
		arm.mesh = am
		arm.material_override = mat
		arm.rotation.z = s * 1.0
		arm.position = base + Vector3(s * 0.6, h * 0.6, 0)
		add_child(arm)


func _make_building(base: Vector3, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(8.0, 22.0)
	var w := rng.randf_range(4.0, 8.0)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, w)
	body.mesh = bm
	body.material_override = _mat(Color(0.05, 0.05, 0.09), 0.6)
	body.position = base + Vector3(0, h * 0.5, 0)
	add_child(body)
	var neon := MeshInstance3D.new()
	var nm := BoxMesh.new()
	nm.size = Vector3(w + 0.2, 0.5, w + 0.2)
	neon.mesh = nm
	var palette := [Color(0.1, 0.95, 1.0), Color(1.0, 0.2, 0.85), Color(0.7, 0.4, 1.0), Color(1.0, 0.8, 0.2)]
	var nc: Color = palette[rng.randi() % palette.size()]
	neon.material_override = _mat(nc, 0.4, 2.6)
	neon.position = base + Vector3(0, h - rng.randf_range(1.0, 3.0), 0)
	add_child(neon)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
	st.add_vertex(a); st.add_vertex(c); st.add_vertex(d)


func _quad_c(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	st.set_color(col); st.add_vertex(a)
	st.set_color(col); st.add_vertex(b)
	st.set_color(col); st.add_vertex(c)
	st.set_color(col); st.add_vertex(a)
	st.set_color(col); st.add_vertex(c)
	st.set_color(col); st.add_vertex(d)
