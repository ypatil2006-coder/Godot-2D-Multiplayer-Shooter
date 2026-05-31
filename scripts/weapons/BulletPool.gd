extends Node

const POOL_SIZE := 30
var _pool: Array[Node] = []
var _idx: int = 0

func _ready() -> void:
	var scene := preload("res://scenes/player/Bullet.tscn")
	for i in POOL_SIZE:
		var b := scene.instantiate()
		b.visible = false
		b.set_process(false)
		b.set_physics_process(false)
		add_child(b)
		_pool.append(b)

func fire(pos: Vector2, dir: Vector2, damage: int = 20, speed: float = 1200.0, max_distance: float = 2000.0, drop_distance: float = 99999.0, shooter: Node2D = null) -> void:
	var b := _pool[_idx % POOL_SIZE]
	_idx += 1
	
	if shooter and is_instance_valid(shooter.get_parent()):
		if b.get_parent() != shooter.get_parent():
			b.reparent(shooter.get_parent())
			
	b.global_position = pos
	b.direction       = dir
	b.damage          = damage
	b.speed           = speed
	b.max_distance    = max_distance
	b.drop_distance   = drop_distance
	b.shooter         = shooter
	b.visible         = true
	b.set_process(true)
	b.set_physics_process(true)
	b.reset()

func recycle(bullet: Node) -> void:
	bullet.visible = false
	bullet.set_process(false)
	bullet.set_physics_process(false)
