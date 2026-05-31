extends CharacterBody2D

signal anchored(position: Vector2)

var speed := 1800.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_anchored := false
var max_distance := 1000.0
var start_pos: Vector2

func initialize(start_pos_in: Vector2, direction: Vector2) -> void:
	start_pos = start_pos_in
	global_position = start_pos
	velocity = direction * speed

func _physics_process(delta: float) -> void:
	if is_anchored:
		return
		
	# Apply gravity to the projectile so it flies in an arc like a ball
	velocity.y += gravity * delta
	
	var collision = move_and_collide(velocity * delta)
	if collision:
		is_anchored = true
		emit_signal("anchored", global_position)
		

