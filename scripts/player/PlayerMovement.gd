extends Node

const SPEED = 300.0
const JUMP_VELOCITY = -500.0

@onready var player: CharacterBody2D = owner
@onready var sprite: ColorRect = owner.get_node("ColorRect")
@onready var gun_pivot: Node2D = owner.get_node("GunPivot")
@onready var grapple: Node = owner.get_node_or_null("GrappleHook/PlayerGrapple")

var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")

func _get_device_id() -> int:
	if owner.has_meta("device_id"):
		return owner.get_meta("device_id")
	return -1

func _physics_process(delta: float) -> void:
	# In multiplayer, only control your own player
	if player.has_node("MultiplayerSynchronizer"):
		if player.get_node("MultiplayerSynchronizer").get_multiplayer_authority() != multiplayer.get_unique_id():
			return

	if player.is_dead:
		player.velocity.y += gravity * delta
		if player.is_on_floor():
			player.velocity.x = move_toward(player.velocity.x, 0, 1000 * delta)
		player.move_and_slide()
		return

	# Gravity
	if not player.is_on_floor():
		var current_gravity = gravity
		if grapple:
			current_gravity *= grapple.get_gravity_scale()
		player.velocity.y += current_gravity * delta

	# Jump
	var device_id = _get_device_id()
	var jump_pressed = false
	if device_id >= 0:
		jump_pressed = Input.is_joy_button_pressed(device_id, JOY_BUTTON_A)
	else:
		jump_pressed = _is_kb_action_pressed("jump")

	if jump_pressed and player.is_on_floor():
		player.velocity.y = JUMP_VELOCITY

	# Movement
	var direction := 0.0
	if device_id >= 0:
		direction = Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
		if abs(direction) < 0.2: direction = 0.0
	else:
		var l = float(_is_kb_action_pressed("move_left"))
		var r = float(_is_kb_action_pressed("move_right"))
		direction = r - l

	if direction:
		player.velocity.x = move_toward(player.velocity.x, direction * SPEED, 2000 * delta)
	else:
		if player.is_on_floor():
			player.velocity.x = lerp(player.velocity.x, 0.0, 10.0 * delta)
		else:
			player.velocity.x = lerp(player.velocity.x, 0.0, 1.5 * delta)

	_handle_aiming()
	player.move_and_slide()

func _handle_aiming() -> void:
	var device_id = _get_device_id()
	var is_left = false

	if device_id >= 0:
		# Controller: right joystick for aiming
		var joy_x = Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X)
		var joy_y = Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y)
		var joy_aim = Vector2(joy_x, joy_y)
		if joy_aim.length() > 0.15:
			gun_pivot.rotation = joy_aim.angle()
			is_left = joy_aim.x < 0
		else:
			is_left = sprite.scale.x < 0
			return  # Don't update rotation if no input
	else:
		# Keyboard: mouse for aiming
		var mouse_pos = player.get_global_mouse_position()
		gun_pivot.look_at(mouse_pos)
		is_left = mouse_pos.x < player.global_position.x

	if is_left:
		sprite.scale.x = -1
		gun_pivot.scale.y = -1
	else:
		sprite.scale.x = 1
		gun_pivot.scale.y = 1

func _is_kb_action_pressed(action: String) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			if event.physical_keycode != 0 and Input.is_physical_key_pressed(event.physical_keycode): return true
			elif event.keycode != 0 and Input.is_physical_key_pressed(event.keycode): return true
		elif event is InputEventMouseButton:
			if Input.is_mouse_button_pressed(event.button_index): return true
	return false
