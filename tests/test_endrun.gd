extends Node
## Focused test: deploy -> immediately end run -> verify roster XP/wounds
## and stash handoff. No heavy sim.

var failures := 0
var main: Node = null
var phase := 0
var frames := 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: ", label)
	else:
		failures += 1
		print("FAIL: ", label)


func _ready() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	get_tree().root.add_child.call_deferred(main)


func _physics_process(_delta: float) -> void:
	frames += 1
	match phase:
		0:
			if main == null or not is_instance_valid(main) or frames < 5:
				return
			var ids := []
			for c in Roster.characters.slice(0, 3):
				ids.append(String(c.get("id")))
			main._on_deployed(ids)
			phase = 1
			frames = 0
		1:
			if frames < 5:
				return
			# Simulate: one member went down, loot in the bag.
			Game.squad[0]["downed"] = true
			Game.loot_bag.append({"id": "test_loot_1", "name": "Test Blade", "slot": "weapon", "rarity": "rare", "stats": {}, "affix": ""})
			var stash_before := Stash.items.size()
			var char_id: String = Game.squad[0]["char_id"]
			var xp_before := int(Roster.get_character(char_id).get("roster_xp", 0))
			Game.end_run(false)
			phase = 2
			frames = 0
		2:
			if frames < 5:
				return
			check(not Game.in_run, "run ended")
			check(Stash.items.size() > 0, "loot moved to stash")
			var found_wound := false
			for c in Roster.characters:
				if int(c.get("wounded_runs_left", 0)) > 0:
					found_wound = true
			check(found_wound, "downed character was wounded")
			var found_xp := false
			for c in Roster.characters:
				if int(c.get("roster_xp", 0)) > 0:
					found_xp = true
			check(found_xp, "survivors gained roster XP")
			print("TEST FAILURES: ", failures)
			get_tree().quit(1 if failures > 0 else 0)
