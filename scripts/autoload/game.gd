extends Node
## Game: in-run state (the VS + XCOM half). Autoloaded last.
## Owns the squad, run timer, shared XP pool, pause, and level-up flow.

signal xp_changed(pool: int, level: int)
signal level_up_ready  # shared pool crossed a threshold: pick a character
signal run_ended(victory: bool)

const RUN_DURATION := 20.0 * 60.0  # 20 minutes
const MAX_SQUAD := 5

var in_run := false
var run_time := 0.0
var tactically_paused := false
var stance := "tight"  # "tight" | "spread" — group-level stance
var focus_target: Node2D = null  # group focus target (right-click); validated by users

# Squad: Array of Dictionaries {char_id, class_id, name, level, xp_to_next,
# hp, max_hp, alive, abilities [], stats {}}
var squad: Array[Dictionary] = []

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
			"gear": {"weapon": "", "armor": "", "trinket": ""},
			"wounded_runs_left": 0,
		})
	_begin(chars)


func _begin(chars: Array) -> void:
	squad.clear()
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
	}


func _xp_for_level(level: int) -> int:
	return int(8 + level * level * 2.5)


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
	# Persist: roster XP + wounds, loot to stash. Loot handoff happens via UI first (v0.1).
	run_ended.emit(victory)
