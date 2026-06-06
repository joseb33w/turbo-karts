extends Node3D
## A peer's kart, driven by Supabase Realtime broadcast messages. We interpolate
## toward the last reported transform so movement stays smooth between packets.

const KartBuildC := preload("res://scripts/kart_build.gd")

var peer_id := ""
var pname := "Racer"
var lap := 0
var prog := 0.0
var finished := false
var last_seen := 0.0

var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _model: Node3D
var _label: Label3D


func setup(id: String) -> void:
	peer_id = id
	var color: Color = KartBuildC.color_for(id)
	var built: Dictionary = KartBuildC.build(color)
	_model = built["root"]
	add_child(_model)

	_label = Label3D.new()
	_label.text = pname
	_label.font_size = 96
	_label.pixel_size = 0.008
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.modulate = color.lightened(0.3)
	_label.outline_size = 24
	_label.outline_modulate = Color(0, 0, 0, 0.8)
	_label.position = Vector3(0, 2.4, 0)
	add_child(_label)


func apply(data: Dictionary, now: float) -> void:
	_target_pos = Vector3(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("z", 0.0)))
	_target_yaw = float(data.get("yaw", 0.0))
	lap = int(data.get("lap", 0))
	prog = float(data.get("prog", 0.0))
	finished = bool(data.get("fin", false))
	var nm := str(data.get("name", "Racer"))
	if nm != pname and _label != null:
		pname = nm
		_label.text = nm
	last_seen = now
	if position == Vector3.ZERO:
		position = _target_pos


func _process(delta: float) -> void:
	var k := clampf(delta * 10.0, 0.0, 1.0)
	position = position.lerp(_target_pos, k)
	if _model:
		_model.rotation.y = lerp_angle(_model.rotation.y, _target_yaw, k)
