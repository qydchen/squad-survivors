class_name ProjectilePool
extends Node2D
## ProjectilePool: fixed pool, oldest-reuse. In group "projectile_pool".

const POOL_SIZE := 256

var pool: Array[Projectile] = []
var cursor := 0


func _ready() -> void:
	add_to_group("projectile_pool")
	for i in POOL_SIZE:
		var p := Projectile.new()
		p.deactivate()
		add_child(p)
		pool.append(p)


func fire(pos: Vector2, dir: Vector2, speed: float, damage: float, from_player: bool, color: Color, radius: float, on_hit: String) -> void:
	var p: Projectile = pool[cursor]
	cursor = (cursor + 1) % POOL_SIZE
	p.activate(pos, dir, speed, damage, from_player, color, radius, on_hit)
