extends RigidBody2D

var fuse_time := 3.0
var max_damage := 100
var radius := 192.0

@onready var color_rect = $ColorRect
@onready var timer = $Timer

var shooter: Node2D = null

func _deal_damage(target: Node2D, dmg: int) -> void:
	var was_alive = false
	if "current_health" in target and target.current_health > 0:
		was_alive = true
		
	target.take_damage(dmg)
	
	if was_alive and "current_health" in target and target.current_health <= 0:
		if is_instance_valid(shooter):
			if multiplayer.has_multiplayer_peer() and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
				if multiplayer.is_server() or shooter.name == str(multiplayer.get_unique_id()):
					Network.rpc("rpc_add_kill", shooter.name)
			else:
				Network.rpc_add_kill(shooter.name)

func _ready() -> void:
	timer.wait_time = fuse_time
	timer.start()
	timer.timeout.connect(_explode)
	
	var sprite = Sprite2D.new()
	sprite.name = "ExplosionSprite"
	var grad_tex = GradientTexture2D.new()
	var grad = Gradient.new()
	grad.set_color(0, Color(1, 0.5, 0, 1))
	grad.set_color(1, Color(1, 0.1, 0, 0))
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(1.0, 0.5)
	grad_tex.width = int(radius * 2)
	grad_tex.height = int(radius * 2)
	sprite.texture = grad_tex
	sprite.hide()
	add_child(sprite)

func _explode() -> void:
	freeze = true
	linear_velocity = Vector2.ZERO
	color_rect.hide()
	
	var explosion = get_node("ExplosionSprite")
	explosion.show()
	explosion.scale = Vector2(0.1, 0.1)
	var tween = create_tween()
	tween.tween_property(explosion, "scale", Vector2(1.0, 1.0), 0.15)
	
	var space_state = get_world_2d().direct_space_state
	var shape = CircleShape2D.new()
	shape.radius = radius
	
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = global_transform
	
	var result = space_state.intersect_shape(query)
	for hit in result:
		var col = hit.collider
		if col.has_method("take_damage"):
			var los_query = PhysicsRayQueryParameters2D.create(global_position, col.global_position)
			los_query.collision_mask = 2 # walls
			var los_result = space_state.intersect_ray(los_query)
			
			if not los_result:
				var dist = global_position.distance_to(col.global_position)
				var dmg = 25
				if dist <= 64:
					dmg = 100
				elif dist <= 128:
					dmg = 75
				_deal_damage(col, dmg)
			
	await get_tree().create_timer(0.15).timeout
	var fade_tween = create_tween()
	fade_tween.tween_property(explosion, "modulate:a", 0.0, 0.3)
	await fade_tween.finished
	queue_free()
