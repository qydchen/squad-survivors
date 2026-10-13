class_name ZoneLayer
extends Node2D
## ZoneLayer: timed ground zones (Blizzard, Hallowed Ground). In group "zone_layer".

var zones: Array[Dictionary] = []  # {kind, pos, radius, left, duration, power}


func _ready() -> void:
	add_to_group("zone_layer")


func spawn_blizzard(pos: Vector2, duration: float, power: float) -> void:
	zones.append({"kind": "blizzard", "pos": pos, "radius": 170.0, "left": duration, "duration": duration, "power": power})


func spawn_hallowed(pos: Vector2, duration: float, power: float) -> void:
	zones.append({"kind": "hallowed", "pos": pos, "radius": 190.0, "left": duration, "duration": duration, "power": power})


func _physics_process(delta: float) -> void:
	for i in range(zones.size() - 1, -1, -1):
		var z: Dictionary = zones[i]
		z["left"] = float(z["left"]) - delta
		if float(z["left"]) <= 0.0:
			zones.remove_at(i)
			continue
		if z["kind"] == "blizzard":
			for n in get_tree().get_nodes_in_group("enemies"):
				var e := n as Enemy
				if e != null and z["pos"].distance_to(e.global_position) < float(z["radius"]):
					e.take_damage(float(z["power"]) * delta, Vector2.ZERO)
					e.apply_slow(0.55, 0.5)
		elif z["kind"] == "hallowed":
			for n in get_tree().get_nodes_in_group("squad_members"):
				var m := n as SquadMember
				if m == null or not bool(m.member.get("alive", true)):
					continue
				if z["pos"].distance_to(m.global_position) < float(z["radius"]):
					m.heal(float(z["power"]) * 0.35 * delta)
	queue_redraw()


func _draw() -> void:
	for z in zones:
		var frac: float = float(z["left"]) / maxf(0.01, float(z["duration"]))
		var col := Color(0.5, 0.8, 1.0, 0.25 * frac) if z["kind"] == "blizzard" else Color(1.0, 0.9, 0.5, 0.22 * frac)
		draw_circle(to_local(z["pos"]), float(z["radius"]), col)
		draw_arc(to_local(z["pos"]), float(z["radius"]), 0, TAU, 40, Color(col.r, col.g, col.b, 0.7), 2.0)
