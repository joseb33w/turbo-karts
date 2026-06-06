class_name Arenas
extends RefCounted
## Catalog of selectable race arenas. Each arena is a self-contained spec: a closed
## set of Catmull-Rom control points (the track shape) plus a visual theme (sky,
## lighting, ground, road, kerbs, fog, water, decor). track.gd builds the world from
## one of these; the menu lets the player pick which one to race.

static func all() -> Array:
	return [_bay(), _forest(), _city(), _dunes()]


static func ids() -> Array:
	var out: Array = []
	for a in all():
		out.append(a["id"])
	return out


static func by_id(id: String) -> Dictionary:
	for a in all():
		if a["id"] == id:
			return a
	return _bay()


static func index_of(id: String) -> int:
	var arr := all()
	for i in arr.size():
		if arr[i]["id"] == id:
			return i
	return 0


# ---------------------------------------------------------------- arenas

static func _bay() -> Dictionary:
	return {
		"id": "bay",
		"name": "Azure Bay",
		"subtitle": "Sunny coastal loop over the water",
		"laps": 3,
		"control": [
			Vector3(0, 0, -62), Vector3(48, 0, -74), Vector3(92, 1.5, -46),
			Vector3(98, 4.5, 4), Vector3(74, 6.0, 46), Vector3(32, 2.0, 62),
			Vector3(-16, 0, 66), Vector3(-62, 0, 48), Vector3(-92, 0, 6),
			Vector3(-78, 0, -36), Vector3(-36, 0, -58),
		],
		"theme": {
			"sky_top": Color(0.25, 0.6, 1.0), "sky_horizon": Color(0.7, 0.88, 1.0),
			"ground_horizon": Color(0.7, 0.88, 1.0), "ground_bottom": Color(0.5, 0.7, 0.9),
			"sun_angle": 30.0, "sun_rot": Vector3(-52, -48, 0),
			"sun_color": Color(1.0, 0.97, 0.9), "sun_energy": 1.15, "ambient": 1.1,
			"fog": true, "fog_color": Color(0.7, 0.86, 1.0), "fog_density": 0.0016,
			"water": true, "water_color": Color(0.30, 0.62, 0.85), "water_y": -5.0,
			"ground": Color(0.34, 0.70, 0.32), "road": Color(0.28, 0.29, 0.34),
			"ground_tex": "grass", "road_tint": Color(1, 1, 1),
			"kerb_a": Color(0.92, 0.2, 0.2), "kerb_b": Color(0.96, 0.96, 0.96), "kerb_emit": 0.0,
			"decor": "trees", "clear": Color(0.42, 0.78, 1.0),
			"shadows": true, "clouds": true, "cloud_color": Color(1, 1, 1),
			"shortcut": true,
		},
	}


static func _forest() -> Dictionary:
	return {
		"id": "forest",
		"name": "Emerald Forest",
		"subtitle": "A misty, winding woodland circuit",
		"laps": 3,
		"control": [
			Vector3(0, 0, -70), Vector3(40, 0, -80), Vector3(80, 0, -58),
			Vector3(72, 0, -16), Vector3(98, 0, 24), Vector3(70, 0, 60),
			Vector3(26, 0, 52), Vector3(8, 0, 82), Vector3(-36, 0, 76),
			Vector3(-60, 0, 40), Vector3(-44, 0, 6), Vector3(-80, 0, -22),
			Vector3(-60, 0, -60), Vector3(-22, 0, -52),
		],
		"theme": {
			"sky_top": Color(0.42, 0.66, 0.55), "sky_horizon": Color(0.82, 0.9, 0.78),
			"ground_horizon": Color(0.78, 0.86, 0.74), "ground_bottom": Color(0.28, 0.4, 0.28),
			"sun_angle": 18.0, "sun_rot": Vector3(-60, -30, 0),
			"sun_color": Color(0.95, 1.0, 0.9), "sun_energy": 1.0, "ambient": 1.15,
			"fog": true, "fog_color": Color(0.78, 0.88, 0.78), "fog_density": 0.0034,
			"water": false, "water_color": Color(0.2, 0.4, 0.3), "water_y": -6.0,
			"ground": Color(0.18, 0.46, 0.20), "road": Color(0.33, 0.31, 0.28),
			"ground_tex": "grass", "road_tint": Color(0.95, 0.94, 0.9),
			"kerb_a": Color(0.85, 0.7, 0.2), "kerb_b": Color(0.96, 0.96, 0.9), "kerb_emit": 0.0,
			"decor": "trees", "clear": Color(0.6, 0.78, 0.62),
			"shadows": true, "clouds": true, "cloud_color": Color(0.92, 0.95, 0.88),
			"shortcut": false,
		},
	}


static func _city() -> Dictionary:
	return {
		"id": "city",
		"name": "Neon City",
		"subtitle": "Night circuit lit by glowing kerbs",
		"laps": 3,
		"control": [
			Vector3(0, 0, -66), Vector3(52, 0, -72), Vector3(88, 0, -50),
			Vector3(86, 0, -6), Vector3(56, 0, 4), Vector3(88, 0, 42),
			Vector3(62, 0, 68), Vector3(16, 0, 60), Vector3(-30, 0, 68),
			Vector3(-72, 0, 46), Vector3(-58, 0, 8), Vector3(-88, 0, -20),
			Vector3(-64, 0, -60), Vector3(-24, 0, -66),
		],
		"theme": {
			"sky_top": Color(0.03, 0.03, 0.11), "sky_horizon": Color(0.28, 0.1, 0.4),
			"ground_horizon": Color(0.18, 0.06, 0.3), "ground_bottom": Color(0.02, 0.02, 0.06),
			"sun_angle": 8.0, "sun_rot": Vector3(-70, -40, 0),
			"sun_color": Color(0.6, 0.6, 0.95), "sun_energy": 0.55, "ambient": 0.55,
			"fog": true, "fog_color": Color(0.12, 0.06, 0.22), "fog_density": 0.0038,
			"water": false, "water_color": Color(0.05, 0.05, 0.12), "water_y": -6.0,
			"ground": Color(0.06, 0.06, 0.10), "road": Color(0.10, 0.10, 0.15),
			"ground_tex": "dark", "road_tint": Color(0.5, 0.55, 0.7),
			"kerb_a": Color(0.1, 0.95, 1.0), "kerb_b": Color(1.0, 0.15, 0.85), "kerb_emit": 2.4,
			"decor": "city", "clear": Color(0.03, 0.03, 0.11),
			"shadows": false, "clouds": false,
			"shortcut": false,
		},
	}


static func _dunes() -> Dictionary:
	return {
		"id": "dunes",
		"name": "Sunset Dunes",
		"subtitle": "Wide, fast sweeps through warm desert sand",
		"laps": 2,
		"control": [
			Vector3(0, 0, -82), Vector3(62, 0, -86), Vector3(106, 0, -44),
			Vector3(110, 0, 18), Vector3(80, 0, 68), Vector3(20, 0, 86),
			Vector3(-42, 0, 82), Vector3(-92, 0, 50), Vector3(-112, 0, -2),
			Vector3(-88, 0, -56), Vector3(-36, 0, -80),
		],
		"theme": {
			"sky_top": Color(0.32, 0.28, 0.6), "sky_horizon": Color(1.0, 0.55, 0.3),
			"ground_horizon": Color(1.0, 0.6, 0.35), "ground_bottom": Color(0.5, 0.35, 0.3),
			"sun_angle": 14.0, "sun_rot": Vector3(-16, -60, 0),
			"sun_color": Color(1.0, 0.72, 0.45), "sun_energy": 1.3, "ambient": 0.95,
			"fog": true, "fog_color": Color(1.0, 0.66, 0.45), "fog_density": 0.0022,
			"water": false, "water_color": Color(0.4, 0.3, 0.25), "water_y": -6.0,
			"ground": Color(0.85, 0.68, 0.40), "road": Color(0.40, 0.34, 0.30),
			"ground_tex": "sand", "road_tint": Color(1.0, 0.96, 0.88),
			"kerb_a": Color(0.9, 0.3, 0.15), "kerb_b": Color(0.98, 0.9, 0.7), "kerb_emit": 0.0,
			"decor": "cacti", "clear": Color(0.95, 0.6, 0.4),
			"shadows": true, "clouds": true, "cloud_color": Color(1.0, 0.92, 0.82),
			"shortcut": false,
		},
	}
