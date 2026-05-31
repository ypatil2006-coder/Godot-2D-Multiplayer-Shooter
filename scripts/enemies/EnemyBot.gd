extends CharacterBody2D

var max_health := 100
var current_health := 100
var is_dead := false
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

enum State { IDLE, PATROL, CHASE, SHOOT }
var current_state = State.PATROL
var move_dir := 1

@onready var player: Node2D = get_tree().get_first_node_in_group("player")
@onready var gun_pivot = $GunPivot
@onready var muzzle = $GunPivot/Muzzle
@onready var los_cast = $GunPivot/RayCast2D
@onready var color_rect = $ColorRect

var fire_timer := 0.0

func _ready() -> void:
	add_to_group("enemies")

func take_damage(amount: int) -> void:
	if is_dead:
		return
	current_health -= amount
	color_rect.color = Color.WHITE
	await get_tree().create_timer(0.1).timeout
	if is_dead: return
	color_rect.color = Color(0.2, 0.4, 0.8) # Blue
	
	if current_health <= 0:
		die()

func die() -> void:
	is_dead = true
	color_rect.color = Color.DIM_GRAY
	collision_layer = 0
	collision_mask = 2 # only collide with world
	await get_tree().create_timer(3.0).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity.y += gravity * delta
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, 1000 * delta)
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y += gravity * delta

	# Try to find player if null
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	# AI Logic
	if is_instance_valid(player) and player.has_method("die") and not player.is_dead:
		var dist = global_position.distance_to(player.global_position)
		gun_pivot.look_at(player.global_position)
		los_cast.target_position = los_cast.to_local(player.global_position)
		los_cast.force_raycast_update()
		
		# If RayCast hits nothing, we have clear line of sight
		if dist < 800 and not los_cast.is_colliding():
			current_state = State.SHOOT
		else:
			current_state = State.CHASE
	else:
		current_state = State.PATROL

	match current_state:
		State.PATROL:
			if is_on_wall():
				move_dir *= -1
			velocity.x = move_dir * 150.0
		State.CHASE:
			if player and is_instance_valid(player):
				if player.global_position.x < global_position.x:
					move_dir = -1
				else:
					move_dir = 1
			velocity.x = move_dir * 300.0
			
			if is_on_wall() and is_on_floor():
				velocity.y = -600.0 # Jump over obstacle
		State.SHOOT:
			velocity.x = move_toward(velocity.x, 0, 1000 * delta)
			fire_timer -= delta
			if fire_timer <= 0:
				fire_timer = 0.5
				var dir = (player.global_position - muzzle.global_position).normalized()
				# Random spread
				dir = dir.rotated(randf_range(-0.1, 0.1))
				BulletPool.fire(muzzle.global_position, dir, 20, 800.0, 1500.0, 99999.0, self)

	move_and_slide()
