extends Node2D
## Spawner: the enemy director. Time-based spawn budget; new types unlock over
## the run. Spawns on a ring outside the camera view around the warband anchor.

const ARENA_HALF := 1500.0
const SPAWN_RADIUS := 760.0
const MAX_ALIVE := 140

var elapsed := 0.0
var spawn_timer := 0.0

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
		# Interval shrinks over time: 1.1s -> ~0.3s at 20 min.
		spawn_timer = maxf(0.28, 1.1 - elapsed * 0.0007)


func _spawn_wave() -> void:
	var alive := get_tree().get_nodes_in_group("enemies").size()
	if alive >= MAX_ALIVE:
		return
	var anchor := get_tree().get_first_node_in_group("warband_anchor")
	if anchor == null:
		return
	var batch := int(3 + elapsed / 45.0)
	for i in batch:
		if get_tree().get_nodes_in_group("enemies").size() >= MAX_ALIVE:
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


func _spawn_one(anchor_pos: Vector2) -> void:
	var type_id := _pick_type()
	var def_path := "res://data/enemies/%s.json" % type_id
	var def: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(def_path))
	# HP scales gently with time so the threat keeps up (tuning knob).
	def["hp"] = float(table[type_id]["hp"]) * (1.0 + elapsed / 600.0)
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
	# Roll a gear drop.
	var drop := Game.roll_drop()
	if not drop.is_empty():
		var loot := LootPickup.new()
		get_parent().add_child(loot)
		loot.global_position = e.global_position
		loot.setup(drop)
