class_name Spawner
extends Node2D
## Spawner: the enemy director. Time-based spawn budget; new types unlock over
## the run. Spawns on a ring outside the camera view around the warband anchor.

const ARENA_HALF := 1500.0
const SPAWN_RADIUS := 760.0


func _max_alive() -> int:
	return int(Game.tun("spawner.max_alive", 140))

var elapsed := 0.0
var spawn_timer := 0.0
var elite_timer := 0.0  # counts down to the next elite

const ELITE_AFFIXES := ["swift", "brutal", "titanic", "volatile"]

# {type_id: {hp, unlock_at, weight}}
var table := {
	"swarmer": {"hp": 18.0, "unlock_at": 0.0, "weight": 10.0},
	"shieldbearer": {"hp": 95.0, "unlock_at": 120.0, "weight": 4.0},
	"stinger": {"hp": 32.0, "unlock_at": 240.0, "weight": 5.0},
}


func _physics_process(delta: float) -> void:
	if not Game.in_run or Game.tactically_paused:
		return
	elapsed += delta
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_wave()
		# Interval shrinks over time (tuning: spawner.interval_*).
		spawn_timer = maxf(float(Game.tun("spawner.interval_min", 0.28)),
			float(Game.tun("spawner.interval_base", 1.1)) - elapsed * float(Game.tun("spawner.interval_decay_per_sec", 0.0007)))
	# Elites: first at elite_first_at, then every elite_every seconds.
	elite_timer -= delta
	if elite_timer <= 0.0:
		elite_timer = float(Game.tun("spawner.elite_every", 150.0))
		_try_spawn_elite()


func _spawn_wave() -> void:
	var max_alive := _max_alive()
	var alive := get_tree().get_nodes_in_group("enemies").size()
	if alive >= max_alive:
		return
	var anchor := get_tree().get_first_node_in_group("warband_anchor")
	if anchor == null:
		return
	var batch := int(float(Game.tun("spawner.batch_base", 3.0)) + elapsed * float(Game.tun("spawner.batch_per_sec", 0.022)))
	for i in batch:
		if get_tree().get_nodes_in_group("enemies").size() >= max_alive:
			break
		_spawn_one(anchor.global_position)


func _pick_type() -> String:
	var total := 0.0
	var options: Array = []
	for id in table.keys():
		var row: Dictionary = table[id]
		if elapsed >= float(row["unlock_at"]):
			total += float(row["weight"])
			options.append(id)
	if options.is_empty():
		return "swarmer"
	var roll := randf() * total
	for id in options:
		roll -= float(table[id]["weight"])
		if roll <= 0.0:
			return id
	return options[0]


func reset() -> void:
	elapsed = 0.0
	spawn_timer = 0.0
	elite_timer = float(Game.tun("spawner.elite_first_at", 180.0))


func _try_spawn_elite() -> void:
	var cap := int(Game.tun("spawner.elite_max", 2))
	var elites := 0
	for n in get_tree().get_nodes_in_group("enemies"):
		if (n as Enemy).is_elite:
			elites += 1
	if elites >= cap:
		return
	var anchor := get_tree().get_first_node_in_group("warband_anchor")
	if anchor == null:
		return
	# Elite = a scaled-up base type with 1-2 affixes.
	var type_id := _pick_type()
	var def_path := "res://data/enemies/%s.json" % type_id
	var def: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(def_path))
	def["hp"] = float(table[type_id]["hp"]) * (1.0 + elapsed * float(Game.tun("spawner.hp_scale_per_sec", 0.00167)))
	def["elite"] = true
	var affixes: Array = []
	var pool := ELITE_AFFIXES.duplicate()
	pool.shuffle()
	var count := 1 + (1 if elapsed > 600.0 else 0)
	for i in mini(count, pool.size()):
		affixes.append(pool[i])
	def["affixes"] = affixes
	var e := Enemy.new()
	e.add_to_group("enemies")
	var ang := randf() * TAU
	var pos: Vector2 = (anchor as Node2D).global_position + Vector2(cos(ang), sin(ang)) * SPAWN_RADIUS
	pos.x = clampf(pos.x, -ARENA_HALF, ARENA_HALF)
	pos.y = clampf(pos.y, -ARENA_HALF, ARENA_HALF)
	get_parent().add_child(e)
	e.global_position = pos
	e.setup(def)
	e.died.connect(_on_enemy_died)


func _spawn_one(anchor_pos: Vector2) -> void:
	var type_id := _pick_type()
	var def_path := "res://data/enemies/%s.json" % type_id
	var def: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(def_path))
	# HP scales gently with time so the threat keeps up (tuning knob).
	def["hp"] = float(table[type_id]["hp"]) * (1.0 + elapsed * float(Game.tun("spawner.hp_scale_per_sec", 0.00167)))
	var e := Enemy.new()
	e.add_to_group("enemies")
	# Random point on ring, clamped to arena.
	var ang := randf() * TAU
	var pos := anchor_pos + Vector2(cos(ang), sin(ang)) * SPAWN_RADIUS
	pos.x = clampf(pos.x, -ARENA_HALF, ARENA_HALF)
	pos.y = clampf(pos.y, -ARENA_HALF, ARENA_HALF)
	get_parent().add_child(e)
	e.global_position = pos
	e.setup(def)
	e.died.connect(_on_enemy_died)


func _on_enemy_died(e: Enemy) -> void:
	Puff.burst(get_parent(), e.global_position, e.body_color, 6)
	# Drop XP gems.
	for i in e.xp_value:
		var g := XpGem.new()
		g.value = 1
		get_parent().add_child(g)
		g.global_position = e.global_position + Vector2(randf_range(-14, 14), randf_range(-14, 14))
	# Roll a gear drop. Elites always drop, rare or better.
	var drop := Game.roll_drop("rare" if e.is_elite else "")
	if not drop.is_empty():
		var loot := LootPickup.new()
		get_parent().add_child(loot)
		loot.global_position = e.global_position
		loot.setup(drop)
