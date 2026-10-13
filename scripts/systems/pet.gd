class_name Pet
extends Node2D
## Pet: the Ranger's animal companion. Follows its owner, mauls the nearest
## enemy. Granted by the "animal_companion" ability (passive while owned).

var owner_member: SquadMember = null
var damage_mult := 0.7
var slow_on_hit := false
var attack_cd := 0.0
var body_radius := 10.0


func _physics_process(delta: float) -> void:
	if owner_member == null or not is_instance_valid(owner_member):
		queue_free()
		return
	if not bool(owner_member.member.get("alive", true)):
		visible = false
		return
	visible = true
	attack_cd = maxf(0.0, attack_cd - delta)
	# Stick near the owner.
	var anchor: Vector2 = owner_member.global_position + Vector2(-24, 18)
	var to_anchor: Vector2 = anchor - global_position
	var target := _nearest_enemy(420.0)
	var move := Vector2.ZERO
	if target != null and to_anchor.length() < 260.0:
		# Engage: run at the enemy.
		var to: Vector2 = target.global_position - global_position
		move = to.normalized() if to.length() > 26.0 else Vector2.ZERO
		if to.length() < 34.0 and attack_cd <= 0.0:
			var dmg: float = owner_member.get_stat("attack_power") * damage_mult
			target.take_damage(dmg, to.normalized(), true)
			if slow_on_hit:
				target.apply_slow(0.7, 1.5)
			attack_cd = 0.9
	elif to_anchor.length() > 12.0:
		move = to_anchor.normalized()
	global_position += move * 190.0 * delta
	queue_redraw()


func _nearest_enemy(max_range: float) -> Enemy:
	var best: Enemy = null
	var best_d := max_range * max_range
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e == null:
			continue
		var d := global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _draw() -> void:
	# A very good beast.
	draw_circle(Vector2.ZERO, body_radius, Color(0.75, 0.55, 0.3))
	draw_circle(Vector2(-4, -3), 3.0, Color(0.5, 0.35, 0.2))
	draw_circle(Vector2(4, -3), 3.0, Color(0.5, 0.35, 0.2))
	draw_circle(Vector2(-2, -1), 1.2, Color.BLACK)
	draw_circle(Vector2(2, -1), 1.2, Color.BLACK)
