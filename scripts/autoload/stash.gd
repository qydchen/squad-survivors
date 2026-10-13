extends Node
## Stash: persistent inventory of gear across runs.
## Items: id, name, slot (weapon/armor/trinket), rarity, stats {}, affix "".

signal stash_changed

const RARITIES := ["common", "magic", "rare", "epic", "legendary"]

var items: Array[Dictionary] = []


func _ready() -> void:
	load_stash()


func load_stash() -> void:
	var data: Dictionary = SaveSystem.load_game()
	items.clear()
	for i in data.get("stash", []):
		if i is Dictionary:
			items.append(i)


func save_stash() -> bool:
	var data: Dictionary = SaveSystem.load_game()
	data["stash"] = items
	var ok := SaveSystem.save_game(data)
	if ok:
		stash_changed.emit()
	return ok


func add_item(item: Dictionary) -> void:
	if not item.has("id"):
		item["id"] = "i_%d" % Time.get_unix_time_from_system()
	items.append(item)
	save_stash()


func remove_item(item_id: String) -> bool:
	for i in items.size():
		if items[i].get("id") == item_id:
			items.remove_at(i)
			save_stash()
			return true
	return false


func get_item(item_id: String) -> Dictionary:
	for i in items:
		if i.get("id") == item_id:
			return i
	return {}


func equip_to_character(item_id: String, char_id: String) -> bool:
	var item := get_item(item_id)
	var char := Roster.get_character(char_id)
	if item.is_empty() or char.is_empty():
		return false
	var slot := String(item.get("slot", ""))
	if not char["gear"].has(slot):
		return false
	# Unequip whatever was there back into the stash.
	var old_id := String(char["gear"][slot])
	char["gear"][slot] = item_id
	remove_item(item_id)
	if old_id != "":
		# Old item definition would be re-added here from the item registry.
		pass
	Roster.save_roster()
	return true
