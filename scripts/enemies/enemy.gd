class_name Enemy
extends CharacterBody2D
## Enemy: data-driven mob. Type tunables come from setup().
## Comp-counter hooks: taunt override, stun, slow, frontal block (shieldbearer),
## keep-distance + ranged attack (stinger).

signal died(enemy: Node2D)

var enemy_id := "swarmer"
var max_hp := 20.0
var hp := 20.0
var speed := 70.0
var radius := 10.0
var contact_damage := 5.0
var xp_value := 1
var body_color := Color(0.85, 0.25, 0.25)
var frontal_block := 0.0  # fraction of damage ignored from the front arc
var keep_distance: Array = []  # [min, max] — ranged behavior
var projectile_cooldown := 0.0
var projectile_damage := 0.0
var projectile_speed := 260.0

var facing := Vector2.RIGHT
var taunted_by: SquadMember = null
var taunt_left := 0.0
var stun_left := 0.0
var slow_left := 0.0
var slow_mult := 1.0
var touch_cd := 0.0
var shoot_cd := 0.0


func setup(def: Dictionary) -> void:
	enemy_id = String(def.get("id", "swarmer"))
	# No physical collision: contact damage is distance-based.
	collision_layer = 4
	collision_mask = 0
	max_hp = float(def.get("hp", 20.0))
	hp = max_hp
	speed = float(def.get("speed", 70.0))
	radius = float(def.get("radius", 10.0))
	contact_damage = float(def.get("contact_damage", 5.0))
	xp_value = int(def.get("xp", 1))
	var c: Array = def.get("color", [0.85, 0.25, 0.25])
	body_color = Color(c[0], c[1], c[2])
	frontal_block = float(def.get("frontal_block", 0.0))
	keep_distance = def.get("keep_distance", [])
	projectile_cooldown = float(def.get("projectile_cooldown", 0.0))
	projectile_damage = float(def.get("projectile_damage", 0.0))
	projectile_speed = float(def.get("projectile_speed", 260.0))
	shoot_cd = randf_range(0.5, 1.5)


func _physics_process(delta: float) -> void:
	taunt_left = maxf(0.0, taunt_left - delta)
	stun_left = maxf(0.0, stun_left - delta)
	slow_left = maxf(0.0, slow_left - delta)
	touch_cd = maxf(0.0, touch_cd - delta)
	if taunt_left <= 0.0:
		taunted_by = null
	if stun_left > 0.0:
		velocity = Vector2.ZERO
		move_and_slide()
		queue_redraw()
		return

	var target := _acquire_target()
	var move_dir := Vector2.ZERO
	if target != null:
		var to: Vector2 = target.global_position - global_position
		var dist := to.length()
		if keep_distance.size() == 2:
			var want_min := float(keep_distance[0])
			var want_max := float(keep_distance[1])
			if dist < want_min:
				move_dir = -to.normalized()  # back off
			elif dist > want_max:
				move_dir = to.normalized()  # close in
			# else: hold position and shoot
		else:
			move_dir = to.normalized() if dist > 1.0 else Vector2.ZERO
		if move_dir != Vector2.ZERO:
			facing = move_dir

	# Separation: don't stack on other enemies.
	var sep := Vector2.ZERO
	var checked := 0
	for n in get_tree().get_nodes_in_group("enemies"):
		var o := n as Enemy
		if o == null or o == self or checked >= 6:
			continue
		checked += 1
		var d: Vector2 = global_position - o.global_position
		var l := d.length()
		if l > 0.01 and l < radius + o.radius + 6.0:
			sep += d.normalized() * (1.0 - l / (radius + o.radius + 6.0))
	move_dir = (move_dir + sep * 0.8).normalized() if (move_dir + sep * 0.8).length() > 0.01 else Vector2.ZERO

	var spd := speed * (slow_mult if slow_left > 0.0 else 1.0)
	velocity = move_dir * spd
	move_and_slide()
	_touch_damage()
	_try_shoot(delta, target)
	queue_redraw()


func _acquire_target() -> Node2D:
	if is_instance_valid(taunted_by) and bool(taunted_by.member.get("alive", true)):
		return taunted_by
	var best: SquadMember = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("squad_members"):
		var m := n as SquadMember
		if m == null or not bool(m.member.get("alive", true)):
			continue
		var d: float = m.global_position.distance_squared_to(global_position)
		if d < best_d:
			best_d = d
			best = m
	return best


func _touch_damage() -> void:
	if touch_cd > 0.0:
		return
	for n in get_tree().get_nodes_in_group("squad_members"):
		var m := n as SquadMember
		if m == null or not bool(m.member.get("alive", true)):
			continue
		if global_position.distance_to(m.global_position) < radius + m.body_radius + 2.0:
			var dir: Vector2 = (m.global_position - global_position).normalized()
			m.take_damage(contact_damage, dir)
			touch_cd = 0.6
			break


func _try_shoot(delta: float, target: Node2D) -> void:
	shoot_cd = maxf(0.0, shoot_cd - delta)
	if projectile_cooldown <= 0.0 or shoot_cd > 0.0 or target == null:
		return
	var dist := global_position.distance_to(target.global_position)
	if dist > 620.0:
		return
	var pool := get_tree().get_first_node_in_group("projectile_pool") as ProjectilePool
	if pool == null:
		return
	var dir := (target.global_position - global_position).normalized()
	pool.fire(global_position, dir, projectile_speed, projectile_damage, false, Color(0.8, 0.4, 1.0), 5.0, "")
	shoot_cd = projectile_cooldown


func take_damage(amount: float, from_dir: Vector2 = Vector2.ZERO) -> void:
	var dmg := amount
	# Shieldbearer frontal block: damage from the front arc is reduced.
	if frontal_block > 0.0 and from_dir != Vector2.ZERO:
		if facing.angle_to(-from_dir) < deg_to_rad(60.0):
			dmg *= 1.0 - frontal_block
	hp -= dmg
	if hp <= 0.0:
		died.emit(self)
		queue_free()


func apply_slow(mult: float, duration: float) -> void:
	slow_mult = mult
	slow_left = duration


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, body_color)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 20, Color(0, 0, 0, 0.4), 2.0)
	if enemy_id == "shieldbearer":
		# Shield wedge showing the blocked arc.
		var a := facing.angle()
		draw_arc(Vector2.ZERO, radius + 5, a - 1.0, a + 1.0, 12, Color(0.7, 0.85, 1.0, 0.9), 4.0)
	elif enemy_id == "stinger":
		draw_circle(Vector2.ZERO, radius * 0.45, Color(1, 1, 1, 0.85))
	if stun_left > 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(-6, -radius - 6), "*", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 0.4))
