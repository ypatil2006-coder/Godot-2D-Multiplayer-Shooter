extends Node

const SPRING_CONSTANT     := 8.0
const DAMPING             := 0.99
const PROJECTILE_SCENE    = preload("res://scenes/player/GrappleProjectile.tscn")

var active_projectile: Node2D = null
var is_anchored: bool = false
var anchor_pos: Vector2 = Vector2.ZERO
var rest_length: float = 50.0

@onready var line:   Line2D    = $"../Line2D"
@onready var player: CharacterBody2D = owner
@onready var gun_muzzle: Marker2D = owner.get_node("GunPivot/Muzzle")

var _prev_grapple := false

func _get_device_id() -> int:
	if owner.has_meta("device_id"):
		return owner.get_meta("device_id")
	return -1

func _physics_process(delta: float) -> void:
	if owner.is_dead:
		_release()
		line.hide()
		return

	@warning_ignore("unsafe_property_access")
	if owner.get_node("BuyMenu").visible:
		return

	if owner.has_node("MultiplayerSynchronizer"):
		if owner.get_node("MultiplayerSynchronizer").get_multiplayer_authority() != multiplayer.get_unique_id():
			return

	# Grapple input
	var device_id = _get_device_id()
	var grapple_just_pressed := false

	if device_id >= 0:
		# RT = Right Trigger
		var cur = Input.get_joy_axis(device_id, JOY_AXIS_TRIGGER_RIGHT) > 0.5
		grapple_just_pressed = cur and not _prev_grapple
		_prev_grapple = cur
	else:
		grapple_just_pressed = Input.is_action_just_pressed("grapple")

	if grapple_just_pressed:
		if is_instance_valid(active_projectile):
			_release()
		else:
			_fire_projectile()

	_physics_tick(delta)

func _fire_projectile() -> void:
	_release()

	var device_id = _get_device_id()
	var direction: Vector2

	if device_id >= 0:
		var joy_x = Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X)
		var joy_y = Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y)
		var joy_aim = Vector2(joy_x, joy_y)
		if joy_aim.length() > 0.15:
			direction = joy_aim.normalized()
		else:
			direction = Vector2.from_angle(owner.get_node("GunPivot").rotation)
	else:
		var mouse_pos = player.get_global_mouse_position()
		direction = (mouse_pos - gun_muzzle.global_position).normalized()

	var proj = PROJECTILE_SCENE.instantiate()
	player.get_parent().add_child(proj)
	proj.get_node("ColorRect").visibility_layer = line.visibility_layer
	proj.initialize(gun_muzzle.global_position, direction)
	proj.connect("anchored", Callable(self, "_on_projectile_anchored"))
	active_projectile = proj

func _on_projectile_anchored(pos: Vector2) -> void:
	is_anchored = true
	anchor_pos = pos
	rest_length = max(50.0, player.global_position.distance_to(anchor_pos) * 0.1)

func _release() -> void:
	is_anchored = false
	if is_instance_valid(active_projectile):
		active_projectile.queue_free()
	active_projectile = null
	line.clear_points()

func _physics_tick(delta: float) -> void:
	if not is_instance_valid(active_projectile):
		_release()
		return

	line.clear_points()
	var local_muzzle = line.to_local(gun_muzzle.global_position)
	var local_proj = line.to_local(active_projectile.global_position)
	line.add_point(local_muzzle)
	line.add_point(local_proj)

	if is_anchored:
		var to_anchor = anchor_pos - player.global_position
		var current_dist = to_anchor.length()
		var stretch = current_dist - rest_length
		if stretch > 0:
			var force = to_anchor.normalized() * (stretch * SPRING_CONSTANT)
			player.velocity += force * delta
		player.velocity *= DAMPING

func get_gravity_scale() -> float:
	return 1.0
