extends Node3D
## Race orchestrator: builds the world, runs the countdown + lap/timer/position
## logic, manages item boxes / coins / bananas / shells, syncs peers over Supabase
## Realtime broadcast, and drives the HUD.

const TrackScript := preload("res://scripts/track.gd")
const KartScript := preload("res://scripts/kart.gd")
const RemoteScript := preload("res://scripts/remote_kart.gd")
const HudScript := preload("res://scripts/hud.gd")
const AudioScript := preload("res://scripts/audio.gd")
const KartBuildC := preload("res://scripts/kart_build.gd")

const TOTAL_LAPS := 3
const ITEM_POOL := ["mushroom", "mushroom", "banana", "shell", "shell"]
const SHELL_SPEED := 46.0
const BROADCAST_HZ := 0.1

var track
var kart
var hud
var audio
var _cam: Camera3D

var player_name := "Racer"
var laps_completed := 0
var best_lap := 0.0
var race_time := 0.0
var _lap_start := 0.0
var _last_frac := 0.0
var _halfway := false
var racing := false
var started := false
var finished := false
var finish_placement := 0

var _remotes := {}
var _boxes: Array[Dictionary] = []
var _coins: Array[Dictionary] = []
var _bananas: Array[Dictionary] = []
var _shells: Array[Dictionary] = []
var _send_accum := 0.0
var _now := 0.0
var _banana_seq := 0


func _ready() -> void:
	track = TrackScript.new()
	add_child(track)
	track.build()

	audio = AudioScript.new()
	add_child(audio)

	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.current = true
	add_child(_cam)

	kart = KartScript.new()
	add_child(kart)
	kart.setup(track, audio, self, KartBuildC.color_for("me_local"))
	kart.attach_camera(_cam)

	hud = HudScript.new()
	add_child(hud)
	hud.setup(self)

	_spawn_pickups()
	_place_grid()
	hud.set_item("")
	hud.set_best(0.0)


func begin() -> void:
	if started:
		return
	started = true
	player_name = Net.display_name
	best_lap = _load_best()
	hud.set_best(best_lap)
	audio.start_engine()

	Net.connected.connect(_on_connected)
	Net.message.connect(_on_message)
	Net.connect_room()

	_start_countdown()


func _place_grid() -> void:
	var grid: Array = track.grid_transforms(1)
	kart.place_at(grid[0])


func _start_countdown() -> void:
	racing = false
	finished = false
	kart.control_enabled = false
	laps_completed = 0
	race_time = 0.0
	_halfway = false
	_last_frac = kart.track_offset / track.length
	var seq := ["3", "2", "1", "GO!"]
	for i in seq.size():
		await get_tree().create_timer(0.85).timeout
		if not is_inside_tree():
			return
		hud.show_count(seq[i])
		if i < seq.size() - 1:
			audio.beep()
		else:
			audio.go()
	await get_tree().create_timer(0.5).timeout
	hud.show_count("")
	_begin_race()


func _begin_race() -> void:
	racing = true
	kart.control_enabled = true
	kart.reset_for_race()
	race_time = 0.0
	_lap_start = 0.0
	_last_frac = kart.track_offset / track.length
	_halfway = false


func reset_race() -> void:
	hud.hide_finish()
	_place_grid()
	_start_countdown()


# ---------------------------------------------------------------- main loop

func _process(delta: float) -> void:
	_now += delta
	_animate_pickups(delta)

	if racing and not finished:
		race_time += delta
		_check_pickups()
		_check_lap()

	_update_bananas(delta)
	_update_shells(delta)
	_update_remotes()
	_broadcast(delta)
	_update_hud()


func _check_lap() -> void:
	var frac: float = kart.track_offset / track.length
	if frac > 0.4 and frac < 0.62:
		_halfway = true
	if _last_frac > 0.82 and frac < 0.18 and _halfway:
		_on_lap_crossed()
		_halfway = false
	_last_frac = frac


func _on_lap_crossed() -> void:
	var lap_time := race_time - _lap_start
	_lap_start = race_time
	if lap_time > 1.0 and (best_lap <= 0.0 or lap_time < best_lap):
		best_lap = lap_time
		_save_best(best_lap)
	laps_completed += 1
	if laps_completed >= TOTAL_LAPS:
		_finish_race()
	else:
		hud.flash("LAP %d" % (laps_completed + 1))


func _finish_race() -> void:
	finished = true
	racing = false
	kart.finished = true
	finish_placement = _compute_position()
	hud.show_finish(finish_placement, _entry_count(), race_time, best_lap)


# ---------------------------------------------------------------- pickups

func _spawn_pickups() -> void:
	for off: float in track.item_offsets:
		var pos: Vector3 = track.sample(off) + Vector3(0, 1.1, 0)
		var node: Node3D = Items.make_item_box()
		node.position = pos
		track.add_child(node)
		_boxes.append({"node": node, "pos": pos, "active": true, "timer": 0.0})

	for spec: Dictionary in track.coin_specs:
		var off: float = spec["offset"]
		var c: Vector3 = track.sample(off)
		var dir: Vector3 = track.tangent_at(off)
		var nrm := Vector3(-dir.z, 0, dir.x)
		var pos := c + nrm * float(spec["side"]) + Vector3(0, 0.6, 0)
		var node: Node3D = Items.make_coin()
		node.position = pos
		track.add_child(node)
		_coins.append({"node": node, "pos": pos, "active": true, "timer": 0.0})


func _animate_pickups(delta: float) -> void:
	for b: Dictionary in _boxes:
		var n: Node3D = b["node"]
		n.rotate_y(delta * 1.8)
		n.position.y = b["pos"].y + sin(_now * 2.0) * 0.15
		if not b["active"]:
			b["timer"] -= delta
			if b["timer"] <= 0.0:
				b["active"] = true
				n.visible = true
	for c: Dictionary in _coins:
		var n: Node3D = c["node"]
		n.rotate_y(delta * 3.0)
		if not c["active"]:
			c["timer"] -= delta
			if c["timer"] <= 0.0:
				c["active"] = true
				n.visible = true


func _check_pickups() -> void:
	for b: Dictionary in _boxes:
		if b["active"] and kart.position.distance_to(b["pos"]) < 2.8:
			if kart.give_item(ITEM_POOL[randi() % ITEM_POOL.size()]):
				b["active"] = false
				b["timer"] = 3.0
				var n: Node3D = b["node"]
				n.visible = false
	for c: Dictionary in _coins:
		if c["active"] and kart.position.distance_to(c["pos"]) < 1.8:
			c["active"] = false
			c["timer"] = 6.0
			var n: Node3D = c["node"]
			n.visible = false
			kart.add_coin()


# ---------------------------------------------------------------- hazards

func drop_banana(pos: Vector3) -> void:
	_spawn_banana(pos, true)
	Net.send({"t": "banana", "x": snappedf(pos.x, 0.1), "z": snappedf(pos.z, 0.1)})


func _spawn_banana(pos: Vector3, mine: bool) -> void:
	var node: Node3D = Items.make_banana()
	node.position = pos
	track.add_child(node)
	_bananas.append({"node": node, "pos": pos, "ttl": 22.0, "mine": mine, "arm": (1.2 if mine else 0.0)})


func _update_bananas(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for b: Dictionary in _bananas:
		b["ttl"] -= delta
		b["arm"] = maxf(0.0, b["arm"] - delta)
		var n: Node3D = b["node"]
		n.rotate_y(delta * 1.0)
		var dead: bool = b["ttl"] <= 0.0
		if not dead and b["arm"] <= 0.0 and kart.position.distance_to(b["pos"]) < 1.5:
			kart.spin_out()
			dead = true
		if dead:
			n.queue_free()
		else:
			keep.append(b)
	_bananas = keep


func fire_shell(offset: float, _owner: Node) -> void:
	var node: Node3D = Items.make_shell()
	node.position = track.sample(offset) + Vector3(0, 0.5, 0)
	track.add_child(node)
	_shells.append({"node": node, "offset": offset, "ttl": 3.5})


func _update_shells(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for s: Dictionary in _shells:
		s["ttl"] -= delta
		s["offset"] = s["offset"] + SHELL_SPEED * delta
		var pos: Vector3 = track.sample(s["offset"]) + Vector3(0, 0.5, 0)
		var n: Node3D = s["node"]
		n.position = pos
		n.rotate_y(delta * 10.0)
		var dead: bool = s["ttl"] <= 0.0
		for id: String in _remotes:
			var rk = _remotes[id]
			if pos.distance_to(rk.position) < 2.6:
				Net.send({"t": "hit", "target": id})
				audio.hit()
				dead = true
				break
		if dead:
			n.queue_free()
		else:
			keep.append(s)
	_shells = keep


# ---------------------------------------------------------------- multiplayer

func _on_connected(room: String, _you: String) -> void:
	hud.set_room(room)


func _on_message(data: Dictionary) -> void:
	var from := str(data.get("from", ""))
	if from == "" or from == Net.local_id:
		return
	match str(data.get("t", "")):
		"pos":
			_apply_remote(from, data)
		"banana":
			_spawn_banana(Vector3(float(data.get("x", 0.0)), 0.3, float(data.get("z", 0.0))), false)
		"hit":
			if str(data.get("target", "")) == Net.local_id:
				kart.spin_out()


func _apply_remote(id: String, data: Dictionary) -> void:
	var rk
	if _remotes.has(id):
		rk = _remotes[id]
	else:
		rk = RemoteScript.new()
		add_child(rk)
		rk.setup(id)
		_remotes[id] = rk
	rk.apply(data, _now)


func _update_remotes() -> void:
	var stale: Array[String] = []
	for id: String in _remotes:
		var rk = _remotes[id]
		if _now - rk.last_seen > 3.5:
			stale.append(id)
	for id: String in stale:
		_remotes[id].queue_free()
		_remotes.erase(id)


func _broadcast(delta: float) -> void:
	if not started:
		return
	_send_accum += delta
	if _send_accum < BROADCAST_HZ:
		return
	_send_accum = 0.0
	Net.send(kart.state())


# ---------------------------------------------------------------- positions + hud

func _entry_count() -> int:
	return 1 + _remotes.size()


func _compute_position() -> int:
	var my_prog: float = kart.race_progress()
	var ahead := 0
	for id: String in _remotes:
		var rk = _remotes[id]
		if rk.prog > my_prog:
			ahead += 1
	return ahead + 1


func _update_hud() -> void:
	hud.set_lap(laps_completed, TOTAL_LAPS)
	hud.set_time(race_time)
	hud.set_best(best_lap)
	hud.set_coins(kart.coins)
	hud.set_item(kart.current_item)
	hud.set_position(_compute_position(), _entry_count())

	var rows: Array = []
	rows.append({"name": player_name, "color": KartBuildC.color_for("me_local"), "prog": kart.race_progress(), "me": true})
	for id: String in _remotes:
		var rk = _remotes[id]
		rows.append({"name": rk.pname, "color": KartBuildC.color_for(id), "prog": rk.prog, "me": false})
	rows.sort_custom(func(a, b): return float(a["prog"]) > float(b["prog"]))
	hud.set_board(rows)


# ---------------------------------------------------------------- best-lap persistence

func _load_best() -> float:
	if OS.has_feature("web"):
		var v: Variant = JavaScriptBridge.eval("window.localStorage.getItem('turbo_best')||''", true)
		var s := str(v)
		if s != "" and s.is_valid_float():
			return float(s)
	return 0.0


func _save_best(v: float) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.localStorage.setItem('turbo_best','%f')" % v, true)
