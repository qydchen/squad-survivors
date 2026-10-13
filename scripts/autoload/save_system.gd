extends Node
## SaveSystem: JSON save/load for all persistent data (roster, stash, warband).
## Autoloaded first; Roster/Stash/Game build on top of it.

const SAVE_PATH := "user://squad_survivors_save.json"


func save_game(data: Dictionary) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: could not open save file for writing: %s" % SAVE_PATH)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveSystem: could not open save file for reading: %s" % SAVE_PATH)
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_error("SaveSystem: save file is corrupt, starting fresh")
	return {}
