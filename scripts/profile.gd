extends Node
## Persistent player profile: wallet (coins) + owned/selected karts + best laps.
## Backed by Supabase (server-authoritative RPCs via web/bridge.js → window.gameProfile).
## Registered as an autoload named "Profile". On non-web builds it keeps an in-memory
## profile so headless runs and logic tests work without a network.

signal updated()
signal op_failed(reason: String)

var loaded := false
var coins := 0
var owned: Array = ["starter"]
var selected_kart := "starter"
var best_laps := {}
var pname := "Racer"
var selected_arena := "bay"

var _bridge: Variant = null
var _cb: Variant = null
var _web := false


func _ready() -> void:
	_web = OS.has_feature("web")
	if not _web:
		pname = _random_name()
		loaded = true
		updated.emit.call_deferred()
		return
	await get_tree().process_frame
	_bridge = JavaScriptBridge.get_interface("gameProfile")
	if _bridge == null:
		push_warning("[Profile] gameProfile bridge missing - is bridge.js in head_include?")
		pname = _random_name()
		loaded = true
		updated.emit.call_deferred()
		return
	_cb = JavaScriptBridge.create_callback(_on_js)
	_bridge.setCallback(_cb)
	_bridge.init()


func owns(kart_id: String) -> bool:
	return owned.has(kart_id)


func best_lap_ms(arena_id: String) -> int:
	return int(best_laps.get(arena_id, 0))


func set_arena(arena_id: String) -> void:
	if selected_arena == arena_id:
		return
	selected_arena = arena_id
	updated.emit()


func bank(coins_delta: int, arena_id: String, lap_ms: int) -> void:
	if _bridge != null:
		_bridge.bank(coins_delta, arena_id, lap_ms)
		return
	coins += maxi(0, coins_delta)
	if lap_ms > 0 and (not best_laps.has(arena_id) or lap_ms < int(best_laps[arena_id])):
		best_laps[arena_id] = lap_ms
	updated.emit()


func buy(kart_id: String) -> void:
	if _bridge != null:
		_bridge.buy(kart_id)
		return
	var price := Garage.price(kart_id)
	if owned.has(kart_id):
		selected_kart = kart_id
		updated.emit()
		return
	if coins < price:
		op_failed.emit("insufficient")
		return
	coins -= price
	owned.append(kart_id)
	selected_kart = kart_id
	updated.emit()


func select_kart(kart_id: String) -> void:
	if not owned.has(kart_id):
		op_failed.emit("not_owned")
		return
	if _bridge != null:
		_bridge.select(kart_id)
		return
	selected_kart = kart_id
	updated.emit()


func _on_js(args: Array) -> void:
	if args.is_empty():
		return
	var parsed: Variant = JSON.parse_string(str(args[0]))
	if not (parsed is Dictionary):
		return
	var d: Dictionary = parsed
	if str(d.get("t", "")) != "profile":
		return
	if d.has("error") and str(d["error"]) != "":
		op_failed.emit(str(d["error"]))
		return
	coins = int(d.get("coins", coins))
	var own_str := str(d.get("owned", "starter"))
	owned = own_str.split(",", false)
	selected_kart = str(d.get("selected", selected_kart))
	var name_in := str(d.get("name", pname))
	if name_in != "":
		pname = name_in
	var bl: Variant = d.get("best_laps", null)
	if bl is Dictionary:
		best_laps = bl
	loaded = true
	updated.emit()


func _random_name() -> String:
	var a := ["Swift", "Brave", "Sly", "Bright", "Bold", "Wild", "Sharp", "Quick"]
	var b := ["Fox", "Owl", "Hawk", "Bear", "Wolf", "Lynx", "Stag", "Hare"]
	return a[randi() % a.size()] + b[randi() % b.size()]
