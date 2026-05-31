extends RigidBody2D

var fuse_time := 1.5
var radius_full := 320.0
var radius_partial := 448.0
var duration_full := 5.0
var duration_partial := 2.0

var shooter: Node2D = null

@onready var color_rect = $ColorRect
@onready var timer = $Timer

func _ready() -> void:
	if shooter:
		add_collision_exception_with(shooter)
		
	timer.wait_time = fuse_time
	timer.start()
	timer.timeout.connect(_explode)

func _explode() -> void:
	freeze = true
	linear_velocity = Vector2.ZERO
	color_rect.hide()
	
	# Explosion visual flash
	var flash_sprite = Sprite2D.new()
	var grad_tex = GradientTexture2D.new()
	var grad = Gradient.new()
	grad.set_color(0, Color.WHITE)
	grad.set_color(1, Color(1, 1, 1, 0))
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(1.0, 0.5)
	grad_tex.width = int(radius_partial * 2)
	grad_tex.height = int(radius_partial * 2)
	flash_sprite.texture = grad_tex
	add_child(flash_sprite)
	
	var tween = create_tween()
	flash_sprite.scale = Vector2(0.1, 0.1)
	tween.tween_property(flash_sprite, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Check line of sight to players
	var players = get_tree().get_nodes_in_group("player")
	var space_state = get_world_2d().direct_space_state
	
	for p in players:
		if is_instance_valid(p) and not p.is_dead:
			var dist = global_position.distance_to(p.global_position)
			if dist <= radius_partial:
				var query = PhysicsRayQueryParameters2D.create(global_position, p.global_position)
				query.collision_mask = 2 # Check against walls (Layer 2)
				var result = space_state.intersect_ray(query)
				if not result:
					if p.has_method("blind"):
						var b_dur = duration_full if dist <= radius_full else duration_partial
						p.blind(b_dur)
						
	await get_tree().create_timer(0.1).timeout
	var fade_tween = create_tween()
	fade_tween.tween_property(flash_sprite, "modulate:a", 0.0, 0.2)
	await fade_tween.finished
	queue_free()
