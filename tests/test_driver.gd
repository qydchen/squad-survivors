extends Node
## Test driver: runs inside the normal scene tree (autoloads available).

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
			if main == null or not is_instance_valid(main):
				return
			if frames < 5:
				return
			check(main.get_node("DraftScreen").visible, "draft screen visible on boot")
			check(not Game.in_run, "not in run before deploy")
			var ids := []
			for c in Roster.characters.slice(0, 5):
				ids.append(String(c.get("id")))
			check(ids.size() == 5, "5 roster characters seeded")
			main._on_deployed(ids)
			phase = 1
			frames = 0
		1:
			if frames < 5:
				return
			check(Game.in_run, "run started after deploy")
			check(get_tree().get_nodes_in_group("squad_members").size() == 5, "5 squad members spawned")
			phase = 2
			frames = 0
		2:
			# Run the sim briefly — enough for spawns.
			if frames < 300:
				return
			check(get_tree().get_nodes_in_group("enemies").size() > 0, "enemies spawned during run")
			var spawner = main.get_node("Spawner")
			spawner.elapsed = 200.0
			spawner._try_spawn_elite()
			phase = 3
			frames = 0
		3:
			if frames < 10:
				return
			var elites := 0
			for n in get_tree().get_nodes_in_group("enemies"):
				if (n as Enemy).is_elite:
					elites += 1
					check((n as Enemy).affixes.size() > 0, "elite has affixes")
			check(elites > 0, "elite spawned")
			# Mass-kill to exercise drops, volatile, puffs.
			for n in get_tree().get_nodes_in_group("enemies"):
				(n as Enemy).take_damage(99999.0, Vector2.ZERO, true)
			phase = 4
			frames = 0
		4:
			if frames < 10:
				return
			Game.end_run(true)
			phase = 5
			frames = 0
		5:
			if frames < 5:
				return
			check(not Game.in_run, "run ended, roster consequences applied")
			print("TEST FAILURES: ", failures)
			get_tree().quit(1 if failures > 0 else 0)
