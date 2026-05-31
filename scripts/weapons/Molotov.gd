extends RigidBody2D

var duration := 7.0
var damage_per_sec := 20
var fire_width := 320.0 # 5 blocks wide fire patch
var fire_height := 64.0 # 1 block high fire patch

var shooter: Node2D = null

@onready var color_rect = $ColorRect
@onready var backup_timer = $BackupTimer

var area: Area2D = null
var burn_mark: ColorRect = null
var fire_sprite: CPUParticles2D = null
var affected_bodies = {}

func _ready() -> void:
	if shooter:
		add_collision_exception_with(shooter)
	
	body_entered.connect(_on_impact)
	backup_timer.timeout.connect(_explode)

func _on_impact(body: Node) -> void:
	# Only explode on walls/floors (Layer 2)
	# Layer 1 is player. Wait, if body is TileMap, it doesn't have collision layer property directly accessible sometimes,
	# but we can check if it's in a group or just check if it's NOT a player.
	if not body.is_in_group("player"):
		_explode()

func _explode() -> void:
	# Prevent multiple explosions
	body_entered.disconnect(_on_impact)
	backup_timer.stop()
	
	freeze = true
	linear_velocity = Vector2.ZERO
	color_rect.hide()
	
	# Raycast down to find the floor to place the fire exactly on it
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, 2000))
	query.collision_mask = 2 # walls
	var result = space_state.intersect_ray(query)
	var spawn_pos = global_position
	if result:
		spawn_pos = result.position
	
	# Create permanent burn mark on the floor
	burn_mark = ColorRect.new()
	burn_mark.color = Color(0.05, 0.05, 0.05, 0.9)
	burn_mark.size = Vector2(fire_width, 8)
	burn_mark.position = spawn_pos - Vector2(fire_width / 2.0, 0)
	get_parent().add_child(burn_mark)
	
	# Create fire visual (CPUParticles2D instead of ColorRect)
	fire_sprite = CPUParticles2D.new() # Using the variable name fire_sprite for simplicity
	fire_sprite.amount = 100
	fire_sprite.lifetime = 1.0
	fire_sprite.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fire_sprite.emission_rect_extents = Vector2(fire_width / 2.0, 4)
	fire_sprite.direction = Vector2(0, -1)
	fire_sprite.spread = 15.0
	fire_sprite.gravity = Vector2(0, -200)
	fire_sprite.initial_velocity_min = 50.0
	fire_sprite.initial_velocity_max = 100.0
	fire_sprite.scale_amount_min = 8.0
	fire_sprite.scale_amount_max = 16.0
	fire_sprite.color = Color(1.0, 0.4, 0.0, 0.9)
	fire_sprite.global_position = spawn_pos
	get_parent().add_child(fire_sprite)
	
	area = Area2D.new()
	area.add_to_group("fire") # Tag it so toxic gas can find it for napalm
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(fire_width, fire_height)
	col.shape = shape
	area.add_child(col)
	area.global_position = spawn_pos - Vector2(0, fire_height / 2.0)
	get_parent().add_child(area)
	
	area.body_entered.connect(_on_fire_entered)
	area.body_exited.connect(_on_fire_exited)
	
	var tick_timer = Timer.new()
	tick_timer.wait_time = 1.0
	tick_timer.autostart = true
	tick_timer.timeout.connect(_on_tick)
	add_child(tick_timer)
	
	await get_tree().create_timer(duration).timeout
	
	tick_timer.stop()
	if is_instance_valid(area):
		area.queue_free()
	
	if is_instance_valid(fire_sprite):
		fire_sprite.emitting = false
		await get_tree().create_timer(1.0).timeout
		fire_sprite.queue_free()
	
	queue_free()

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

func _on_fire_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		affected_bodies[body] = true
		_deal_damage(body, damage_per_sec) # Initial tick

func _on_fire_exited(body: Node2D) -> void:
	if affected_bodies.has(body):
		affected_bodies.erase(body)

func _on_tick() -> void:
	var bodies = affected_bodies.keys()
	for body in bodies:
		if is_instance_valid(body) and body.has_method("take_damage") and not body.is_dead:
			# Fire is on the floor, assume standing in it burns you (no strict LoS needed for ground fire)
			_deal_damage(body, damage_per_sec)
		else:
			affected_bodies.erase(body)
