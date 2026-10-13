extends Node
## Game: in-run state (the VS + XCOM half). Autoloaded last.
## Owns the squad, run timer, shared XP pool, pause, and level-up flow.

signal xp_changed(pool: int, level: int)
signal level_up_ready  # shared pool crossed a threshold: pick a character
signal run_ended(victory: bool)
signal loot_dropped(item: Dictionary)  # a gear pickup entered the loot bag

const RUN_DURATION := 20.0 * 60.0  # 20 minutes
const MAX_SQUAD := 5

const RARITY_COLORS := {
	"common": Color(0.7, 0.7, 0.7),
	"magic": Color(0.35, 0.55, 1.0),
	"rare": Color(0.7, 0.4, 1.0),
	"epic": Color(1.0, 0.6, 0.2),
	"legendary": Color(1.0, 0.85, 0.35),
}

var in_run := false
var run_time := 0.0
var tactically_paused := false
var stance := "tight"  # "tight" | "spread" — group-level stance
var focus_target: Node2D = null  # group focus target (right-click); validated by users

# Tuning (data/tuning.json) — the balance knobs. Missing file = sane defaults.
var tuning := {}

# Squad: Array of Dictionaries {char_id, class_id, name, roster_level, level,
# hp, max_hp, alive, downed, abilities [], stat_mults {}, buffs {}, shield}
var squad: Array[Dictionary] = []

# Loot bag: gear picked up this run, not yet equipped. Survives to the stash.
var loot_bag: Array[Dictionary] = []
# Item registry: id -> def (data/items/items.json).
var item_defs := {}


func _ready() -> void:
	_load_tuning()
	_load_items()


func _load_tuning() -> void:
	var path := "res://data/tuning.json"
	if FileAccess.file_exists(path):
		tuning = JSON.parse_string(FileAccess.get_file_as_string(path))
	if tuning == null:
		tuning = {}


func tun(path: String, fallback: Variant) -> Variant:
	# tun("drops.base_chance", 0.03) — dotted lookup into the tuning config.
	var node: Variant = tuning
	for part in path.split("."):
		if node is Dictionary and node.has(part):
			node = node[part]
		else:
			return fallback
	return node


func _load_items() -> void:
	var path := "res://data/items/items.json"
	if not FileAccess.file_exists(path):
		return
	var items: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
	for it in items:
		item_defs[String(it.get("id", ""))] = it


func rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)


var xp_pool := 0
var run_level := 1  # number of level-ups earned from the shared pool


func start_run(char_ids: Array) -> void:
	var chars: Array = []
	for cid in char_ids.slice(0, MAX_SQUAD):
		var c: Dictionary = Roster.get_character(String(cid))
		if not c.is_empty():
			chars.append(c)
	_begin(chars)


func start_run_debug(class_ids: Array) -> void:
	# v0.1: throwaway characters that are NOT saved to the persistent roster.
	var chars: Array = []
	for i in class_ids.size():
		var cid := String(class_ids[i])
		chars.append({
			"id": "debug_%d" % i,
			"class_id": cid,
			"name": cid.capitalize(),
			"roster_level": 1,
			"roster_xp": 0,
			"gear": {"weapon": {}, "armor": {}, "trinket": {}},
			"wounded_runs_left": 0,
		})
	_begin(chars)


func _begin(chars: Array) -> void:
	squad.clear()
	loot_bag.clear()
	for c in chars.slice(0, MAX_SQUAD):
		squad.append(_make_runner(c))
	run_time = 0.0
	xp_pool = 0
	run_level = 1
	stance = "tight"
	focus_target = null
	in_run = true
	tactically_paused = false


func _make_runner(c: Dictionary) -> Dictionary:
	# Everyone starts at level 1 every run. Roster level gives a small bump
	# (target: ~15% total power from meta systems).
	var rlevel := int(c.get("roster_level", 1))
	var hp_bonus := 1.0 + 0.02 * (rlevel - 1)
	return {
		"char_id": c.get("id"),
		"class_id": c.get("class_id"),
		"name": c.get("name"),
		"roster_level": int(c.get("roster_level", 1)),
		"level": 1,
		"xp_to_next": _xp_for_level(1),
		"hp": 100.0 * hp_bonus,
		"max_hp": 100.0 * hp_bonus,
		"alive": true,
		"downed": false,
		"abilities": [],       # [{id, name, cooldown, cd_left, rank}]
		"stat_mults": {"attack_power": 1.0, "max_hp_mult": 1.0, "move_speed": 1.0, "pickup": 1.0, "crit": 0.0},
		"buffs": {},           # {name: time_left}
		"shield": 0.0,         # absorb pool (Aegis)
		"gear": {"weapon": {}, "armor": {}, "trinket": {}},
	}


func _xp_for_level(level: int) -> int:
	var base := float(tun("xp.base", 8.0))
	var quad := float(tun("xp.quad", 2.5))
	return int(base + level * level * quad)


func add_xp(amount: int) -> void:
	if not in_run:
		return
	xp_pool += amount
	if xp_pool >= _xp_for_level(run_level):
		xp_pool -= _xp_for_level(run_level)
		run_level += 1
		level_up_ready.emit()
	xp_changed.emit(xp_pool, run_level)


func apply_level_up(char_id: String, _upgrade_id: String) -> void:
	# Called by the level-up UI: which character levels + which upgrade they take.
	# Upgrade resolution (ability unlock / rank / stat) lives in the ability system (v0.1).
	for m in squad:
		if m.get("char_id") == char_id:
			m["level"] = int(m.get("level", 1)) + 1


func set_tactical_pause(paused: bool) -> void:
	tactically_paused = paused
	get_tree().paused = paused


func _process(delta: float) -> void:
	if not in_run or tactically_paused:
		return
	run_time += delta
	if run_time >= RUN_DURATION:
		end_run(true)


func end_run(victory: bool) -> void:
	in_run = false
	set_tactical_pause(false)
	# Survivors keep their loot: everything in the bag goes to the stash.
	for item in loot_bag:
		Stash.add_item(item)
	loot_bag.clear()
	# Roster consequences: XP for survivors, wounds for the downed.
	# (Debug characters aren't on the roster — skip them.)
	for m in squad:
		var cid := String(m.get("char_id", ""))
		if cid.begins_with("debug_"):
			continue
		var was_downed := bool(m.get("downed", false))
		Roster.apply_post_run(cid, run_level * 10, was_downed)
	run_ended.emit(victory)


# ---- Gear drops ----

func roll_drop(min_rarity: String = "") -> Dictionary:
	# Called on enemy death. Returns an item def (as a fresh instance dict) or {}.
	# min_rarity forces the roll to that rarity or better (elites).
	var minutes := run_time / 60.0
	var chance: float = minf(float(tun("drops.max_chance", 0.09)),
		float(tun("drops.base_chance", 0.035)) + minutes * float(tun("drops.time_scale_per_min", 0.004)))
	if min_rarity != "":
		chance = 1.0
	if randf() > chance or item_defs.is_empty():
		return {}
	var weights: Dictionary = (tun("drops.rarity_weights", {"common": 50.0, "magic": 28.0, "rare": 14.0, "epic": 6.0, "legendary": 2.0}) as Dictionary).duplicate()
	# Legendary odds creep up over the run. (Duplicate above: never mutate the live tuning config.)
	weights["legendary"] = float(weights.get("legendary", 2.0)) + minutes * float(tun("drops.legendary_weight_per_min", 0.35))
	if min_rarity != "":
		# Zero out everything below the floor.
		var order := ["common", "magic", "rare", "epic", "legendary"]
		var floor_idx := order.find(min_rarity)
		for i in order.size():
			if i < floor_idx:
				weights[order[i]] = 0.0
	# Legendary odds creep up over the run.
	weights["legendary"] = float(weights.get("legendary", 2.0)) + minutes * float(tun("drops.legendary_weight_per_min", 0.35))
	var total := 0.0
	for w in weights.values():
		total += float(w)
	var roll := randf() * total
	var rarity := "common"
	for r in weights.keys():
		roll -= float(weights[r])
		if roll <= 0.0:
			rarity = String(r)
			break
	var pool: Array = []
	for it in item_defs.values():
		if String(it.get("rarity", "common")) == rarity:
			pool.append(it)
	if pool.is_empty():
		return {}
	var def: Dictionary = pool[randi() % pool.size()]
	# Fresh instance: unique id so stash/equip can track it.
	var inst := (def as Dictionary).duplicate(true)
	inst["id"] = "loot_%d_%d" % [Time.get_unix_time_from_system(), randi() % 100000]
	inst["def_id"] = def.get("id")
	return inst


func collect_loot(item: Dictionary) -> void:
	loot_bag.append(item)
	loot_dropped.emit(item)
