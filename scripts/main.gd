extends Node2D
## Main: run bootstrap. v0.1 builds the arena, spawns a debug squad,
## and wires the warband anchor. The draft screen replaces the debug
## squad in v0.2.

@onready var anchor: Node2D = $WarbandAnchor

const SquadMemberScene := preload("res://scripts/characters/squad_member.gd")


func _ready() -> void:
	add_to_group("warband_anchor")
	# Debug squad: Bulwark + Arcanist + Cleric. Replace with draft screen in v0.2.
	var debug_ids: Array = []
	for class_id in ["bulwark", "arcanist", "cleric"]:
		var c := Roster.add_character(class_id, class_id.capitalize())
		debug_ids.append(c["id"])
	Game.start_run(debug_ids)
	_spawn_squad()


func _spawn_squad() -> void:
	for entry in Game.squad:
		var m := CharacterBody2D.new()
		m.set_script(SquadMemberScene)
		m.add_to_group("squad_members")
		add_child(m)
		m.global_position = anchor.global_position + Vector2(randf_range(-60, 60), randf_range(-60, 60))
		m.setup(entry)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("tactical_pause"):
		Game.set_tactical_pause(not Game.tactically_paused)
		get_viewport().set_input_as_handled()
