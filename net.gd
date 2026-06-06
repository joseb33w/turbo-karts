extends Node
## Serverless multiplayer client (Supabase Realtime broadcast via web/bridge.js).
## Register as an autoload named "Net" (Project Settings → Autoload).
##
## Usage from game code:
##   Net.message.connect(_on_net)        # inbound {Dictionary} from a peer
##   Net.connected.connect(func(room, you): ...)
##   Net.connect_room()                  # after tap-to-start
##   Net.send({ "t": "pos", "x": p.x, "y": p.y })   # broadcast; bridge adds "from"
## Spawn / update remote players keyed by data["from"]; despawn on a timeout.

signal connected(room: String, you: String)
signal disconnected()
signal message(data: Dictionary)

var local_id: String = ""
var room: String = ""
var display_name: String = "Racer"

var _bridge: Variant = null
var _cb: Variant = null


func _ready() -> void:
	if not OS.has_feature("web"):
		push_warning("[Net] non-web build - serverless multiplayer is web-only")
		var c := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
		local_id = "p_local"
		display_name = "Player" + c[randi() % c.length()] + c[randi() % c.length()]
		return
	await get_tree().process_frame
	_bridge = JavaScriptBridge.get_interface("gameNet")
	if _bridge == null:
		push_warning("[Net] gameNet bridge missing - is bridge.js in the export head_include?")
		return
	_cb = JavaScriptBridge.create_callback(_on_js)
	_bridge.setOnMessage(_cb)
	local_id = str(_bridge.getUserId())
	display_name = str(_bridge.getName())


func connect_room(code: String = "") -> void:
	if _bridge != null:
		_bridge.connectRoom(code)


func send(data: Dictionary) -> void:
	if _bridge != null:
		_bridge.send(JSON.stringify(data))


func _on_js(args: Array) -> void:
	if args.is_empty():
		return
	var parsed: Variant = JSON.parse_string(str(args[0]))
	if not (parsed is Dictionary):
		return
	var d: Dictionary = parsed
	match str(d.get("t", "")):
		"_connected":
			room = str(d.get("room", ""))
			local_id = str(d.get("you", local_id))
			connected.emit(room, local_id)
		"_disconnected":
			disconnected.emit()
		_:
			message.emit(d)
