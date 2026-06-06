class_name Garage
extends RefCounted
## Vehicle catalog. Each kart has a price (coins), a colour + visual style, and
## stat multipliers applied to the base handling constants in kart.gd. Prices here
## MUST match the server-authoritative price table in the tk_buy RPC (schema.sql).

const STARTER := "starter"


static func all() -> Array:
	return [
		{
			"id": "starter", "name": "Sprout Cart", "price": 0,
			"desc": "Balanced and friendly. Yours from the start.",
			"color": Color(0.30, 0.80, 0.35), "style": "classic",
			"stats": {"speed": 1.00, "accel": 1.00, "turn": 1.00, "drift": 1.00},
		},
		{
			"id": "speedster", "name": "Turbo Roadster", "price": 800,
			"desc": "Higher top speed, slightly looser in corners.",
			"color": Color(0.95, 0.27, 0.21), "style": "sport",
			"stats": {"speed": 1.18, "accel": 0.96, "turn": 0.95, "drift": 1.00},
		},
		{
			"id": "drifter", "name": "Drift King", "price": 1200,
			"desc": "Razor handling and long, easy mini-turbos.",
			"color": Color(0.70, 0.35, 0.90), "style": "drift",
			"stats": {"speed": 1.05, "accel": 1.06, "turn": 1.16, "drift": 1.28},
		},
		{
			"id": "heavy", "name": "Bruiser", "price": 1600,
			"desc": "Brutal acceleration, shrugs off rough ground.",
			"color": Color(1.00, 0.50, 0.20), "style": "heavy",
			"stats": {"speed": 1.10, "accel": 1.22, "turn": 0.92, "drift": 0.96},
		},
		{
			"id": "gt", "name": "Rocket GT", "price": 3200,
			"desc": "Blistering speed with strong all-round grip.",
			"color": Color(0.20, 0.55, 0.95), "style": "gt",
			"stats": {"speed": 1.28, "accel": 1.12, "turn": 1.02, "drift": 1.08},
		},
		{
			"id": "ace", "name": "Phantom Ace", "price": 6500,
			"desc": "The ultimate machine. Fast everywhere.",
			"color": Color(0.12, 0.85, 0.85), "style": "ace",
			"stats": {"speed": 1.36, "accel": 1.20, "turn": 1.12, "drift": 1.16},
		},
	]


static func by_id(id: String) -> Dictionary:
	for k in all():
		if k["id"] == id:
			return k
	return all()[0]


static func price(id: String) -> int:
	return int(by_id(id)["price"])
