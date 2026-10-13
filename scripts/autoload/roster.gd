extends Node
## Roster: the persistent collection of characters (the WoW half of the game).
## Each character: id, class_id, name, roster_level, roster_xp,
## gear {weapon, armor, trinket} holding item ids, wounded_runs_left.

signal roster_changed

var characters: Array[Dictionary] = []


func _ready() -> void:
	load_roster()


func load_roster() -> void:
	var data: Dictionary = SaveSystem.load_game()
	characters.clear()
	for c in data.get("roster", []):
		if c is Dictionary:
			characters.append(c)


func save_roster() -> bool:
	var data: Dictionary = SaveSystem.load_game()
	data["roster"] = characters
	var ok := SaveSystem.save_game(data)
	if ok:
		roster_changed.emit()
	return ok


func add_character(class_id: String, char_name: String) -> Dictionary:
	var char := {
		"id": "c_%d" % Time.get_unix_time_from_system(),
		"class_id": class_id,
		"name": char_name,
		"roster_level": 1,
		"roster_xp": 0,
		"gear": {"weapon": "", "armor": "", "trinket": ""},
		"wounded_runs_left": 0,
	}
	characters.append(char)
	save_roster()
	return char


func get_character(char_id: String) -> Dictionary:
	for c in characters:
		if c.get("id") == char_id:
			return c
	return {}


func available_for_draft() -> Array[Dictionary]:
	# Wounded characters sit out.
	return characters.filter(func(c: Dictionary) -> bool: return int(c.get("wounded_runs_left", 0)) <= 0)


func apply_post_run(char_id: String, gained_xp: int, was_downed: bool) -> void:
	var c := get_character(char_id)
	if c.is_empty():
		return
	c["roster_xp"] = int(c.get("roster_xp", 0)) + gained_xp
	# Simple curve: 100 * level xp per roster level.
	while int(c["roster_xp"]) >= 100 * int(c.get("roster_level", 1)):
		c["roster_xp"] = int(c["roster_xp"]) - 100 * int(c.get("roster_level", 1))
		c["roster_level"] = int(c.get("roster_level", 1)) + 1
	if was_downed:
		c["wounded_runs_left"] = 1
	elif int(c.get("wounded_runs_left", 0)) > 0:
		c["wounded_runs_left"] = int(c["wounded_runs_left"]) - 1
	save_roster()
