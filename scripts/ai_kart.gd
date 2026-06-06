extends Node3D
## A CPU opponent. It rail-follows the track centerline (so it can never fall off), but
## with per-racer skill, lane changes (to weave + overtake), corner braking, and gentle
## rubber-banding toward the human so single-player races stay close and winnable. The
## player's shells and bananas can spin it out. It's ranked by `prog` next to the human
## and any live peers, so finishing position is a real result.

const KartBuildC := preload("res://scripts/kart_build.gd")

var track
var pname := "CPU"
var color := Color(0.8, 0.8, 0.8)
var prog := 0.0
var lap := 0
var finished := false
var racing := false

var offset := 0.0
var total_laps := 3
var _length := 1.0
var _top := 24.0
var _skill := 0.6
var _speed := 0.0
var _lane := 0.0
var _lane_target := 0.0
var _lane_timer := 0.0
var _spin := 0.0
var _boost := 0.0
var _boost_cd := 0.0
var _yaw := 0.0
var _tilt := 0.0
var _bob := 0.0

var _start_off := 0.0
var _start_lane := 0.0

var _model: Node3D
var _wheels: Array = []
var _label: Label3D
var _rng := RandomNumberGenerator.new()


func setup(track_ref: Node3D, def: Dictionary) -> void:
	track = track_ref
	_length = maxf(1.0, track.length)
	pname = str(def.get("name", "CPU"))
	color = def.get("color", Color(0.8, 0.8, 0.8))
	_skill = float(def.get("skill", 0.6))
	total_laps = int(def.get("laps", 3))
	offset = float(def.get("offset", 0.0))
	_lane = float(def.get("lane", 0.0))
	_lane_target = _lane
	_start_off = offset
	_start_lane = _lane
	_rng.seed = int(def.get("seed", 1))
	_top = lerpf(20.5, 28.5, _skill)
	_boost_cd = _rng.randf_range(3.0, 7.0)

	var built: Dictionary = KartBuildC.build_def({"color": color, "style": str(def.get("style", "classic"))})
	_model = built["root"]
	var ws: Variant = built.get("wheels", [])
	if ws is Array:
		_wheels = ws
	add_child(_model)

	_label = Label3D.new()
	_label.text = pname
	_label.font_size = 88
	_label.pixel_size = 0.0075
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.modulate = color.lightened(0.45)
	_label.outline_size = 22
	_label.outline_modulate = Color(0, 0, 0, 0.8)
	_label.position = Vector3(0, 2.5, 0)
	add_child(_label)

	_place()


func reset_grid() -> void:
	offset = _start_off
	_lane = _start_lane
	_lane_target = _start_lane
	lap = 0
	prog = _start_off
	finished = false
	racing = false
	_speed = 0.0
	_spin = 0.0
	_boost = 0.0
	_lane_timer = 0.0
	_place()


func hit() -> void:
	if _spin > 0.0:
		return
	_spin = 1.1
	_boost = 0.0


func _place() -> void:
	var c: Vector3 = track.sample(offset)
	var dir: Vector3 = track.tangent_at(offset)
	var nrm := Vector3(-dir.z, 0.0, dir.x)
	position = c + nrm * _lane + Vector3(0.0, 0.6, 0.0)
	_yaw = atan2(-dir.x, -dir.z)
	if _model:
		_model.rotation.y = _yaw


func update(delta: float, player_prog: float) -> void:
	if not racing:
		return
	delta = minf(delta, 0.05)
	_spin = maxf(0.0, _spin - delta)
	_boost = maxf(0.0, _boost - delta)
	_boost_cd = maxf(0.0, _boost_cd - delta)

	var d0: Vector3 = track.tangent_at(offset)
	var d1: Vector3 = track.tangent_at(offset + 9.0)
	var turn := d0.angle_to(d1)
	var corner := clampf(1.0 - turn * 1.25, 0.42, 1.0)

	var target := _top * corner
	var gap := player_prog - prog
	target += clampf(gap * 0.012, -3.5, 6.5)
	target += _rng.randf_range(-0.6, 0.6)

	if _boost_cd <= 0.0 and corner > 0.9 and _rng.randf() < 0.02:
		_boost = 1.0
		_boost_cd = _rng.randf_range(5.0, 9.0)
	if _boost > 0.0:
		target += 9.0
	if _spin > 0.0:
		target = 2.0
	if finished:
		target = minf(target, 9.0)

	var rate := 26.0 if target > _speed else 20.0
	_speed = move_toward(_speed, maxf(0.0, target), rate * delta)
	offset += _speed * delta

	if offset >= _length:
		offset -= _length
		if not finished:
			lap += 1
			if lap >= total_laps:
				finished = true

	_lane_timer -= delta
	if _lane_timer <= 0.0:
		_lane_timer = _rng.randf_range(1.4, 3.4)
		_lane_target = _rng.randf_range(-4.4, 4.4)
	_lane = move_toward(_lane, _lane_target, 3.0 * delta)

	var c: Vector3 = track.sample(offset)
	var dir: Vector3 = track.tangent_at(offset)
	var nrm := Vector3(-dir.z, 0.0, dir.x)
	var pos := c + nrm * _lane + Vector3(0.0, 0.6, 0.0)
	position = position.lerp(pos, clampf(delta * 10.0, 0.0, 1.0))

	var want_yaw := atan2(-dir.x, -dir.z)
	if _spin > 0.0:
		_yaw += delta * 12.0
	else:
		_yaw = lerp_angle(_yaw, want_yaw, clampf(delta * 6.0, 0.0, 1.0))

	prog = float(mini(lap, total_laps)) * _length + offset
	if finished:
		prog = float(total_laps) * _length + offset

	var lane_vel := _lane_target - _lane
	_tilt = lerpf(_tilt, clampf(-lane_vel * 0.07, -0.22, 0.22), clampf(delta * 6.0, 0.0, 1.0))
	if _model:
		_model.rotation.y = _yaw
		_model.rotation.z = _tilt
		_bob += delta * _speed * 0.3
		_model.position.y = sin(_bob) * 0.03
		var roll := _speed * delta * 3.0
		for w: Variant in _wheels:
			if w is Node3D:
				(w as Node3D).rotate_x(roll)
