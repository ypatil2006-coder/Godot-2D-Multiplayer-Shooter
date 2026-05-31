extends RigidBody2D

var fuse_time := 2.0
var duration := 8.0
var radius := 192.0

@onready var timer = $Timer
@onready var color_rect = $ColorRect # Used only for the grenade body now, hide it on explode

var area: Area2D = null
var particles: CPUParticles2D = null
var affected_bodies = {}
var damage_sequence = [4, 6, 12, 18, 26, 32, 44, 60, 80, 100]
var exploded = false

func _ready() -> void:
	timer.wait_time = fuse_time
	timer.start()
	timer.timeout.connect(_explode)

func _explode() -> void:
	if exploded: return
	exploded = true
	
	freeze = true
	linear_velocity = Vector2.ZERO
	color_rect.hide()
	
	area = Area2D.new()
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = radius
	col.shape = shape
	area.add_child(col)
	add_child(area)
	
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	area.area_entered.connect(_on_area_entered)
	
	# Create gas particles
	particles = CPUParticles2D.new()
	particles.amount = 200
	particles.lifetime = 1.5
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = radius * 0.8
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 10.0
	particles.initial_velocity_max = 30.0
	particles.scale_amount_min = 10.0
	particles.scale_amount_max = 30.0
	particles.color = Color(0.2, 0.8, 0.2, 0.5)
	add_child(particles)
	
	var tick_timer = Timer.new()
	tick_timer.wait_time = 1.0
	tick_timer.autostart = true
	tick_timer.timeout.connect(_on_tick)
	add_child(tick_timer)
	
	await get_tree().create_timer(duration).timeout
	_cleanup(tick_timer)

func _cleanup(tick_timer: Timer = null) -> void:
	if tick_timer:
		tick_timer.stop()
	if is_instance_valid(area):
		area.queue_free()
	if is_instance_valid(particles):
		particles.emitting = false
		await get_tree().create_timer(2.0).timeout
		particles.queue_free()
	queue_free()

func _on_area_entered(other_area: Area2D) -> void:
	if other_area.is_in_group("fire"):
		# NAPALM COMBO TRIGGER!
		_trigger_napalm()

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

func _trigger_napalm() -> void:
	# Deal 50 damage instantly to everyone inside
	for body in affected_bodies.keys():
		if is_instance_valid(body) and body.has_method("take_damage") and not body.is_dead:
			_deal_damage(body, 50)
	
	# Napalm visual explosion
	var explosion = Sprite2D.new()
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
	explosion.texture = grad_tex
	add_child(explosion)
	
	var tween = create_tween()
	explosion.scale = Vector2(0.1, 0.1)
	tween.tween_property(explosion, "scale", Vector2(1.0, 1.0), 0.15)
	
	# Instantly cleanup the gas
	if is_instance_valid(area):
		area.queue_free()
	if is_instance_valid(particles):
		particles.queue_free()
		
	await get_tree().create_timer(0.2).timeout
	var fade_tween = create_tween()
	fade_tween.tween_property(explosion, "modulate:a", 0.0, 0.3)
	await fade_tween.finished
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		affected_bodies[body] = 0

func _on_body_exited(body: Node2D) -> void:
	if affected_bodies.has(body):
		affected_bodies.erase(body)

func _on_tick() -> void:
	var bodies = affected_bodies.keys()
	var space_state = get_world_2d().direct_space_state
	for body in bodies:
		if is_instance_valid(body) and body.has_method("take_damage") and not body.is_dead:
			# Check line of sight
			var query = PhysicsRayQueryParameters2D.create(global_position, body.global_position)
			query.collision_mask = 2 # walls
			var result = space_state.intersect_ray(query)
			
			if not result:
				var secs = affected_bodies[body]
				var dmg = damage_sequence[min(secs, damage_sequence.size() - 1)]
				_deal_damage(body, dmg)
				affected_bodies[body] = secs + 1
		else:
			affected_bodies.erase(body)
