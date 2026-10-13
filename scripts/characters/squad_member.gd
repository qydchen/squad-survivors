extends CharacterBody2D
## SquadMember: a deployed character in a run. Data comes from Game.squad;
## visuals/stats are hydrated from data/classes/<class_id>.json.

var member: Dictionary = {}      # the Game.squad entry
var class_def: Dictionary = {}   # loaded from data/classes/
var formation_offset := Vector2.ZERO
var move_order := Vector2.ZERO   # set via tactical pause; ZERO = follow anchor
var has_move_order := false
var attack_cooldown := 0.0


func setup(squad_entry: Dictionary) -> void:
	member = squad_entry
	class_def = _load_class_def(String(squad_entry.get("class_id", "")))
	formation_offset = _formation_offset_for(String(class_def.get("role", "")))


func _load_class_def(class_id: String) -> Dictionary:
	var path := "res://data/classes/%s.json" % class_id
	if not FileAccess.file_exists(path):
		push_error("SquadMember: missing class def %s" % path)
		return {}
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _formation_offset_for(role: String) -> Vector2:
	# Tanks/melee front, healer center, ranged rear. Anchor faces +X.
	match role:
		"tank", "melee_dps":
			return Vector2(70, randf_range(-50, 50))
		"healer", "support":
			return Vector2(-10, randf_range(-40, 40))
		_:
			return Vector2(-80, randf_range(-70, 70))


func _physics_process(delta: float) -> void:
	if not bool(member.get("alive", true)):
		return
	var target := _move_target()
	var to := target - global_position
	if to.length() > 4.0:
		var speed := float(class_def.get("base_stats", {}).get("move_speed", 100.0))
		velocity = to.normalized() * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	_tick_attack(delta)


func _move_target() -> Vector2:
	if has_move_order:
		return move_order
	# Follow the warband anchor (set by the player controller) + formation offset.
	var anchor := get_tree().get_first_node_in_group("warband_anchor")
	if anchor:
		return anchor.global_position + formation_offset
	return global_position


func _tick_attack(_delta: float) -> void:
	# v0.1: basic auto-attack. Ability system plugs in here.
	pass


func take_damage(amount: float) -> void:
	var armor := float(class_def.get("base_stats", {}).get("armor", 0.0))
	var mitigated: float = amount * 100.0 / (100.0 + armor * 5.0)
	member["hp"] = float(member.get("hp", 1.0)) - mitigated
	if float(member["hp"]) <= 0.0:
		member["hp"] = 0.0
		member["alive"] = false
		_on_downed()


func _on_downed() -> void:
	# v0.1: mark downed; revive channel handled by the player controller.
	set_physics_process(false)
