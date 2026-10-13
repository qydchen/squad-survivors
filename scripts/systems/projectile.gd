class_name Projectile
extends Node2D
## Projectile: pooled, manual collision (distance checks — no physics setup).
## from_player=true hits enemies; false hits squad members.

var active := false
var dir := Vector2.RIGHT
var speed := 400.0
var damage := 10.0
var from_player := true
var color := Color.WHITE
var radius := 6.0
var on_hit := ""  # e.g. "slow_30pct_2s"
var life := 2.0


func _physics_process(delta: float) -> void:
	if not active:
		return
	life -= delta
	if life <= 0.0:
		deactivate()
		return
	global_position += dir * speed * delta
	if from_player:
		for n in get_tree().get_nodes_in_group("enemies"):
			var e := n as Enemy
			if e != null and global_position.distance_to(e.global_position) < radius + e.radius:
				e.take_damage(damage, dir)
				_apply_on_hit(e)
				deactivate()
				return
	else:
		for n in get_tree().get_nodes_in_group("squad_members"):
			var m := n as SquadMember
			if m == null or not bool(m.member.get("alive", true)):
				continue
			if global_position.distance_to(m.global_position) < radius + m.body_radius:
				m.take_damage(damage, dir)
				deactivate()
				return
	queue_redraw()


func _apply_on_hit(e: Enemy) -> void:
	if on_hit == "slow_30pct_2s":
		e.apply_slow(0.7, 2.0)


func activate(pos: Vector2, p_dir: Vector2, p_speed: float, p_damage: float, p_from_player: bool, p_color: Color, p_radius: float, p_on_hit: String) -> void:
	global_position = pos
	dir = p_dir.normalized()
	speed = p_speed
	damage = p_damage
	from_player = p_from_player
	color = p_color
	radius = p_radius
	on_hit = p_on_hit
	life = 2.0
	active = true
	visible = true
	set_physics_process(true)


func deactivate() -> void:
	active = false
	visible = false
	set_physics_process(false)


func _draw() -> void:
	if not active:
		return
	draw_circle(Vector2.ZERO, radius, color)
	draw_line(-dir * radius * 2.2, Vector2.ZERO, Color(color.r, color.g, color.b, 0.5), 3.0)
