extends CharacterBody2D
## Enemy: base class for all mobs. Tunables per type live in data/enemies/*.json (v0.2).
## v0.1: simple chase AI; the comp-counter behaviors (silence zones, frontal
## block, healer priority) plug into _special_behavior().

signal died(enemy: Node)

var enemy_id := "swarmer"
var max_hp := 20.0
var hp := 20.0
var speed := 70.0
var damage := 5.0
var xp_value := 1


func _physics_process(delta: float) -> void:
	var target := _acquire_target()
	if target == null:
		velocity = Vector2.ZERO
	else:
		var to: Vector2 = target.global_position - global_position
		velocity = to.normalized() * speed if to.length() > 1.0 else Vector2.ZERO
	move_and_slide()
	_special_behavior(delta)


func _acquire_target() -> Node2D:
	# Nearest living squad member. Menders/focus logic overrides this (v0.2).
	var best: Node2D = null
	var best_d := INF
	for m in get_tree().get_nodes_in_group("squad_members"):
		if not bool(m.get("member", {}).get("alive", true)):
			continue
		var d: float = m.global_position.distance_squared_to(global_position)
		if d < best_d:
			best_d = d
			best = m
	return best


func _special_behavior(_delta: float) -> void:
	pass


func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		died.emit(self)
		queue_free()
