extends Node2D
## Main: run bootstrap. Builds the arena nodes (see main.tscn), starts a debug
## run for v0.1, spawns the squad, and owns pause/restart input + defeat check.

@onready var anchor: Node2D = $WarbandAnchor
@onready var hud: Hud = $HUD
@onready var level_up_screen: LevelUpScreen = $LevelUpScreen
@onready var inventory_screen: InventoryScreen = $InventoryScreen


func _ready() -> void:
	# NOTE: Main stays pausable (default). The R-restart shortcut lives in
	# hud.gd because the HUD is PROCESS_MODE_ALWAYS and works while paused.
	Game.level_up_ready.connect(_on_level_up_ready)
	# Debug squad: 5 of the 6 classes (drops the Arcanist for this comp).
	Game.start_run_debug(["bulwark", "cleric", "ranger", "shadowblade", "stormcaller"])
	_spawn_squad()
	hud.build_squad_frames()


func _spawn_squad() -> void:
	for entry in Game.squad:
		var m := SquadMember.new()
		m.add_to_group("squad_members")
		add_child(m)
		m.global_position = anchor.global_position + Vector2(randf_range(-60, 60), randf_range(-60, 60))
		m.setup(entry)


func _process(_delta: float) -> void:
	if not Game.in_run or Game.tactically_paused:
		return
	var any_alive := false
	for entry in Game.squad:
		if bool(entry.get("alive", false)):
			any_alive = true
			break
	if not any_alive:
		Game.end_run(false)


func _on_level_up_ready() -> void:
	level_up_screen.show_for()


func _unhandled_input(event: InputEvent) -> void:
	# Main is pausable: this only fires while the sim is running.
	if event.is_action_pressed("tactical_pause") and Game.in_run and not level_up_screen.visible:
		Game.set_tactical_pause(not Game.tactically_paused)
		get_viewport().set_input_as_handled()
		return
	# Tab: loot inventory. The game keeps running — sorting loot mid-swarm is a risk.
	if event.is_action_pressed("squad_inventory") and Game.in_run and not level_up_screen.visible:
		inventory_screen.toggle()
		get_viewport().set_input_as_handled()
		return
