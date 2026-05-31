extends Area2D

var direction := Vector2.RIGHT
var damage := 20
var speed := 1200.0
var max_distance := 2000.0
var drop_distance := 99999.0
var active := false

var shooter: Node2D = null

var start_pos := Vector2.ZERO
var current_velocity := Vector2.ZERO
var traveled := 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func reset() -> void:
	active = true
	start_pos = global_position
	current_velocity = direction * speed
	traveled = 0.0
	rotation = current_velocity.angle()
	print("Bullet spawned at: ", global_position, " visible: ", visible, " parent: ", get_parent().name)

func _physics_process(delta: float) -> void:
	if not active:
		return
		
	if traveled > drop_distance:
		# Apply gravity downwards
		current_velocity.y += 1800.0 * delta
		
	var step = current_velocity * delta
	global_position += step
	traveled += step.length()
	rotation = current_velocity.angle()
	
	if traveled > max_distance:
		deactivate()

func deactivate() -> void:
	active = false
	BulletPool.recycle(self)

func _on_body_entered(body: Node2D) -> void:
	if not active or body == shooter:
		return
		
	if body.has_method("take_damage"):
		_deal_damage(body)
		
	# Hit a wall or enemy
	deactivate()

func _on_area_entered(area: Area2D) -> void:
	if not active:
		return
	if area.name == "HitBox":
		var player = area.get_parent()
		if player == shooter:
			return
			
		if player.has_method("take_damage"):
			_deal_damage(player)
			
		deactivate()

func _deal_damage(target: Node2D) -> void:
	var was_alive = false
	if "current_health" in target and target.current_health > 0:
		was_alive = true
		
	target.take_damage(damage)
	
	if was_alive and "current_health" in target and target.current_health <= 0:
		if is_instance_valid(shooter):
			if multiplayer.has_multiplayer_peer() and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
				# Only the server or the shooter should report the kill to avoid duplicates
				if multiplayer.is_server() or shooter.name == str(multiplayer.get_unique_id()):
					Network.rpc("rpc_add_kill", shooter.name)
			else:
				Network.rpc_add_kill(shooter.name)
