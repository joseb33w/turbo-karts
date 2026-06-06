extends Node3D
## Local player kart. Arcade model in world space: auto-accelerate, steer, drift
## to charge a mini-turbo, brake. Height follows the track surface (hills); ramps
## launch it into a gravity arc. Off the grass into the void -> respawn. Owns the
## chase camera that tilts into turns and the engine/boost/drift audio + VFX.

const Audio := preload("res://scripts/audio.gd")
const KartBuildC := preload("res://scripts/kart_build.gd")

const BASE_MAX := 24.0
const BOOST_MAX := 39.0
const BRAKE_TARGET := 4.0
const ACCEL := 16.0
const BRAKE_DECEL := 30.0
const GRASS_MULT := 0.52
const TURN := 2.1
const DRIFT_TURN := 3.1
const GRAVITY := 24.0
const COIN_BONUS := 0.2
const COIN_CAP := 6.0
const MINI_TIERS := [0.55, 1.2, 2.0]
const MINI_BOOST := [0.55, 0.95, 1.45]

var track
var audio
var game

var speed := 0.0
var yaw := 0.0
var vy := 0.0
var airborne := false
var control_enabled := false
var finished := false

var coins := 0
var coin_bonus := 0.0
var current_item := ""

var drifting := false
var drift_dir := 0.0
var drift_charge := 0.0
var boost_time := 0.0
var boost_tier := 0

var spin_time := 0.0
var invuln := 0.0
var ramp_cooldown := 0.0

var track_offset := 0.0
var on_road := true
var _last_good_offset := 0.0

var _model: Node3D
var _body: MeshInstance3D
var _cam: Camera3D
var _cam_ready := false
var _boost_fx: CPUParticles3D
var _spark_l: CPUParticles3D
var _spark_r: CPUParticles3D
var _spark_mat: StandardMaterial3D


func setup(track_ref: Node3D, audio_ref: Node, game_ref: Node, color: Color) -> void:
	track = track_ref
	audio = audio_ref
	game = game_ref
	var built: Dictionary = KartBuildC.build(color)
	_model = built["root"]
	_body = built["body"]
	add_child(_model)
	_build_fx()


func attach_camera(cam: Camera3D) -> void:
	_cam = cam


func place_at(t: Dictionary) -> void:
	position = t["pos"]
	yaw = t["yaw"]
	track_offset = track.probe(position)["offset"]
	_last_good_offset = track_offset
	_apply_model_transform(0.0, 0.0)
	_snap_camera()


func reset_for_race() -> void:
	speed = 0.0
	vy = 0.0
	airborne = false
	finished = false
	drifting = false
	drift_charge = 0.0
	boost_time = 0.0
	spin_time = 0.0
	coins = 0
	coin_bonus = 0.0
	current_item = ""


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	ramp_cooldown = maxf(0.0, ramp_cooldown - delta)
	invuln = maxf(0.0, invuln - delta)

	var probe: Dictionary = track.probe(position)
	track_offset = probe["offset"]
	on_road = probe["on_road"]
	var on_grass: bool = probe["on_grass"]
	var surface_y: float = probe["surface_y"]
	if on_road:
		_last_good_offset = track_offset

	var steer := 0.0
	var drift_held := false
	if control_enabled and spin_time <= 0.0 and not finished:
		steer = (1.0 if Input.is_action_pressed("kart_right") else 0.0) - (1.0 if Input.is_action_pressed("kart_left") else 0.0)
		drift_held = Input.is_action_pressed("kart_drift")
		if Input.is_action_just_pressed("kart_item"):
			_use_item()

	_drive(delta, steer, drift_held, on_grass, surface_y)
	_update_audio()
	_apply_model_transform(steer, delta)
	_update_camera(delta, steer)


func _drive(delta: float, steer: float, drift_held: bool, on_grass: bool, surface_y: float) -> void:
	boost_time = maxf(0.0, boost_time - delta)

	# ----- spin-out overrides control
	if spin_time > 0.0:
		spin_time -= delta
		speed = lerpf(speed, 3.0, delta * 4.0)
		drifting = false
		drift_charge = 0.0
		boost_time = 0.0

	var braking := control_enabled and spin_time <= 0.0 and not finished and Input.is_action_pressed("kart_brake")

	# ----- target speed
	var top := BASE_MAX + coin_bonus
	if not on_grass:
		pass
	elif not on_road:
		top *= GRASS_MULT
	if boost_time > 0.0:
		top = BOOST_MAX + coin_bonus
	var target := top
	if not control_enabled or finished:
		target = 0.0
	elif braking:
		target = BRAKE_TARGET

	var rate := ACCEL
	if braking:
		rate = BRAKE_DECEL
	elif boost_time > 0.0:
		rate = ACCEL * 2.4
	elif target < speed:
		rate = BRAKE_DECEL * 0.5
	speed = move_toward(speed, target, rate * delta)

	# ----- drift logic
	if spin_time <= 0.0 and not finished and control_enabled:
		if drift_held and not drifting and speed > 9.0 and absf(steer) > 0.15:
			drifting = true
			drift_dir = signf(steer)
			drift_charge = 0.0
		if drifting:
			if not drift_held or speed < 6.0:
				_release_drift()
			else:
				drift_charge += delta

	# ----- steering
	var turn_input := steer
	var turn_rate := TURN
	if drifting:
		turn_rate = DRIFT_TURN
		turn_input = clampf(drift_dir * 0.7 + steer * 0.45, -1.2, 1.2)
	var speed_factor := clampf(speed / 12.0, 0.0, 1.0)
	if airborne:
		speed_factor *= 0.3
	yaw -= turn_input * turn_rate * delta * speed_factor

	if spin_time > 0.0:
		yaw += delta * 14.0

	# ----- forward integration
	var f := Vector3(-sin(yaw), 0.0, -cos(yaw))
	position += f * speed * delta

	# ----- ramps / air / ground follow
	_handle_vertical(delta, on_grass, surface_y)


func _handle_vertical(delta: float, on_grass: bool, surface_y: float) -> void:
	if not airborne and ramp_cooldown <= 0.0 and speed > 13.0:
		for pad: Dictionary in track.ramp_pads:
			if position.distance_to(pad["pos"]) < 4.0:
				airborne = true
				vy = 9.0
				ramp_cooldown = 1.5
				break

	if airborne:
		vy -= GRAVITY * delta
		position.y += vy * delta
		if position.y <= surface_y and vy <= 0.0:
			position.y = surface_y
			vy = 0.0
			airborne = false
	elif on_grass:
		position.y = lerpf(position.y, surface_y, clampf(delta * 12.0, 0.0, 1.0))
	else:
		# over the void - fall, then respawn
		vy -= GRAVITY * delta
		position.y += vy * delta
		if position.y < -2.5:
			_respawn()


func _release_drift() -> void:
	drifting = false
	var tier := 0
	for i in MINI_TIERS.size():
		if drift_charge >= MINI_TIERS[i]:
			tier = i + 1
	if tier > 0:
		boost_time = maxf(boost_time, MINI_BOOST[tier - 1])
		boost_tier = tier
		if audio:
			audio.boost()
		_burst_boost()
	drift_charge = 0.0


func _use_item() -> void:
	match current_item:
		"mushroom":
			boost_time = maxf(boost_time, 1.4)
			if audio: audio.boost()
			_burst_boost()
		"banana":
			var f := Vector3(-sin(yaw), 0.0, -cos(yaw))
			if game: game.drop_banana(position - f * 2.4 + Vector3(0, 0.3, 0))
			if audio: audio.item()
		"shell":
			if game: game.fire_shell(track_offset, self)
			if audio: audio.item()
	current_item = ""


func give_item(name: String) -> bool:
	if current_item != "":
		return false
	current_item = name
	if audio: audio.item()
	return true


func add_coin() -> void:
	coins += 1
	coin_bonus = minf(COIN_CAP, coin_bonus + COIN_BONUS)
	speed = minf(BOOST_MAX, speed + 1.2)
	if audio: audio.coin()


func spin_out() -> void:
	if invuln > 0.0 or spin_time > 0.0:
		return
	spin_time = 1.2
	invuln = 1.6
	if audio: audio.hit()


func _respawn() -> void:
	var off := _last_good_offset
	var c: Vector3 = track.sample(off)
	var dir: Vector3 = track.tangent_at(off)
	position = c + Vector3(0, 0.6, 0)
	yaw = atan2(-dir.x, -dir.z)
	speed = 0.0
	vy = 0.0
	airborne = false
	drifting = false
	drift_charge = 0.0
	boost_time = 0.0
	spin_time = 0.0
	invuln = 1.2


func _update_audio() -> void:
	if not audio:
		return
	audio.set_engine(clampf(speed / BOOST_MAX, 0.0, 1.0))
	audio.set_drift(drifting, clampf(drift_charge / MINI_TIERS[2], 0.0, 1.0))


func _apply_model_transform(steer: float, delta: float) -> void:
	var slip := 0.0
	if drifting:
		slip = drift_dir * 0.4
	_model.rotation.y = yaw + slip
	_model.rotation.z = lerpf(_model.rotation.z, -steer * 0.12 - (drift_dir * 0.14 if drifting else 0.0), clampf(delta * 8.0, 0.0, 1.0)) if delta > 0.0 else -steer * 0.12
	var hop := 0.15 if airborne else 0.0
	_model.position.y = lerpf(_model.position.y, hop, 0.2)

	# drift spark colours by tier
	if _spark_mat:
		var t := clampf(drift_charge / MINI_TIERS[2], 0.0, 1.0)
		var col := Color(1, 1, 1)
		if drift_charge >= MINI_TIERS[1]:
			col = Color(0.4, 0.7, 1.0)
		elif drift_charge >= MINI_TIERS[0]:
			col = Color(1.0, 0.6, 0.15)
		_spark_mat.albedo_color = col
		_spark_mat.emission = col
	var sparking := drifting and drift_charge > 0.25
	_spark_l.emitting = sparking
	_spark_r.emitting = sparking
	_boost_fx.emitting = boost_time > 0.0


func _build_fx() -> void:
	_spark_mat = StandardMaterial3D.new()
	_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_mat.albedo_color = Color(1, 1, 1)
	_spark_mat.emission_enabled = true
	_spark_mat.emission = Color(1, 1, 1)
	_spark_mat.emission_energy_multiplier = 2.0

	_spark_l = _make_sparks(Vector3(0.7, 0.05, 1.0))
	_spark_r = _make_sparks(Vector3(-0.7, 0.05, 1.0))

	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.emission_enabled = true
	bmat.emission = Color(1.0, 0.55, 0.1)
	bmat.albedo_color = Color(1.0, 0.55, 0.1)
	bmat.emission_energy_multiplier = 2.5
	_boost_fx = CPUParticles3D.new()
	_boost_fx.amount = 18
	_boost_fx.lifetime = 0.4
	_boost_fx.emitting = false
	_boost_fx.local_coords = false
	_boost_fx.direction = Vector3(0, 0.2, 1)
	_boost_fx.spread = 18.0
	_boost_fx.initial_velocity_min = 4.0
	_boost_fx.initial_velocity_max = 7.0
	_boost_fx.gravity = Vector3(0, 1.0, 0)
	_boost_fx.scale_amount_min = 0.5
	_boost_fx.scale_amount_max = 0.9
	var bq := SphereMesh.new()
	bq.radius = 0.22
	bq.height = 0.44
	bq.radial_segments = 6
	bq.rings = 4
	bq.material = bmat
	_boost_fx.mesh = bq
	_boost_fx.position = Vector3(0, 0.3, 1.1)
	_model.add_child(_boost_fx)


func _make_sparks(pos: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 0.35
	p.emitting = false
	p.local_coords = false
	p.direction = Vector3(0, 0.3, 1)
	p.spread = 35.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -6.0, 0)
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.6
	var q := SphereMesh.new()
	q.radius = 0.12
	q.height = 0.24
	q.radial_segments = 6
	q.rings = 3
	q.material = _spark_mat
	p.mesh = q
	p.position = pos
	_model.add_child(p)
	return p


func _burst_boost() -> void:
	_boost_fx.emitting = true


# ---------------------------------------------------------------- camera

func _snap_camera() -> void:
	if _cam == null:
		return
	var f := Vector3(-sin(yaw), 0.0, -cos(yaw))
	_cam.position = position - f * 8.5 + Vector3(0, 4.2, 0)
	_cam.look_at(position + f * 3.0 + Vector3(0, 1.0, 0), Vector3.UP)
	_cam_ready = true


func _update_camera(delta: float, steer: float) -> void:
	if _cam == null:
		return
	if not _cam_ready:
		_snap_camera()
		return
	var f := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var desired := position - f * 8.5 + Vector3(0, 4.2, 0)
	var k := clampf(delta * 6.0, 0.0, 1.0)
	_cam.position = _cam.position.lerp(desired, k)
	_cam.look_at(position + f * 3.0 + Vector3(0, 1.0, 0), Vector3.UP)
	var roll := -(steer * 0.10 + (drift_dir * 0.10 if drifting else 0.0))
	_cam.rotate_object_local(Vector3(0, 0, 1), roll)
	var ratio := clampf(speed / BOOST_MAX, 0.0, 1.0)
	var fov_target := lerpf(68.0, 86.0, ratio) + (6.0 if boost_time > 0.0 else 0.0)
	_cam.fov = lerpf(_cam.fov, fov_target, k)


func state() -> Dictionary:
	return {
		"t": "pos",
		"x": snappedf(position.x, 0.01),
		"y": snappedf(position.y, 0.01),
		"z": snappedf(position.z, 0.01),
		"yaw": snappedf(yaw, 0.01),
		"sp": snappedf(speed, 0.1),
		"lap": game.laps_completed if game else 0,
		"prog": snappedf(race_progress(), 0.1),
		"fin": finished,
		"name": game.player_name if game else "Me",
	}


func race_progress() -> float:
	var laps: int = (game.laps_completed if game else 0)
	return float(laps) * track.length + track_offset
