extends CharacterBody2D

signal health_changed(current: int, max_health: int)
signal player_died()

var max_health := 100
var current_health := 100
var is_dead := false
var spawn_position := Vector2.ZERO
var is_invulnerable := false
var original_color: Color
var ui_viewport: Viewport = null

# Zoom - shared across all local players in split-screen
static var shared_zoom := Vector2(1.0, 1.0)
var target_zoom := Vector2(1.0, 1.0)
const ZOOM_SPEED := 0.1
const MIN_ZOOM := 0.3
const MAX_ZOOM := 2.5

func _get_device_id() -> int:
	if has_meta("device_id"):
		return get_meta("device_id")
	return -1

func _ready() -> void:
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(name.to_int())
	add_to_group("player")
	spawn_position = global_position
	original_color = $ColorRect.color
	if not ui_viewport:
		ui_viewport = get_viewport()
	call_deferred("emit_signal", "health_changed", current_health, max_health)

	# Camera setup
	var is_local = true
	if has_node("MultiplayerSynchronizer"):
		is_local = $MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id()

	if is_local:
		$Camera2D.make_current()
	else:
		$Camera2D.enabled = false

	# Fog of War vision light
	var vision_light = PointLight2D.new()
	vision_light.name = "VisionLight"
	vision_light.shadow_enabled = true
	vision_light.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	vision_light.shadow_filter_smooth = 2.0

	var tex = GradientTexture2D.new()
	var grad = Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1, 0.5)
	tex.width = 2048
	tex.height = 2048
	vision_light.texture = tex
	vision_light.blend_mode = Light2D.BLEND_MODE_MIX
	add_child(vision_light)

	# Hide cursor during gameplay
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func take_damage(amount: int) -> void:
	if is_dead:
		return

	current_health = max(0, current_health - amount)
	emit_signal("health_changed", current_health, max_health)

	var dmg_num = preload("res://scenes/ui/DamageNumber.tscn").instantiate()
	get_parent().add_child(dmg_num)
	dmg_num.global_position = global_position + Vector2(0, -40)
	dmg_num.setup(amount, amount > 30)

	if current_health <= 0:
		die()

func die() -> void:
	is_dead = true
	velocity *= 0.3
	emit_signal("player_died")
	$ColorRect.color = Color.DIM_GRAY
	$GunPivot.hide()

	if multiplayer.has_multiplayer_peer() and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		Network.rpc("rpc_add_death", name)
	else:
		Network.rpc_add_death(name)

	if has_node("GrappleHook/PlayerGrapple"):
		$GrappleHook/PlayerGrapple._release()
		$GrappleHook/Line2D.hide()

	await get_tree().create_timer(3.0).timeout
	respawn()

func respawn() -> void:
	is_dead = false
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)

	var map = get_parent().get_parent()
	if map and "default_spawns" in map and map.default_spawns.size() > 0:
		var spawn_idx = randi() % map.default_spawns.size()
		global_position = map.default_spawns[spawn_idx]
	else:
		global_position = spawn_position

	velocity = Vector2.ZERO
	$ColorRect.color = original_color
	$GunPivot.show()
	if has_node("GrappleHook/Line2D"):
		$GrappleHook/Line2D.show()

	if has_node("PlayerShoot"):
		var shoot = $PlayerShoot
		shoot.is_reloading = false
		for w in shoot.weapons:
			w["current_ammo"] = w["max_ammo"]
		var current_w = shoot.weapons[shoot.loadout[shoot.current_slot_idx]]
		shoot.emit_signal("ammo_changed", current_w["current_ammo"], current_w["max_ammo"])

func _unhandled_input(event: InputEvent) -> void:
	var is_local = true
	if has_node("MultiplayerSynchronizer"):
		is_local = $MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id()
	if not is_local:
		return

	if event.is_action_pressed("pause_game") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START):
		if has_node("PauseMenu"):
			$PauseMenu.show()

	# Only keyboard player zooms (controller player gets synced zoom)
	if _get_device_id() < 0:
		if event is InputEventMouseButton and event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				shared_zoom += Vector2(ZOOM_SPEED, ZOOM_SPEED)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				shared_zoom -= Vector2(ZOOM_SPEED, ZOOM_SPEED)
			shared_zoom.x = clamp(shared_zoom.x, MIN_ZOOM, MAX_ZOOM)
			shared_zoom.y = clamp(shared_zoom.y, MIN_ZOOM, MAX_ZOOM)

func _process(delta: float) -> void:
	var is_local = true
	if has_node("MultiplayerSynchronizer"):
		is_local = $MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id()
	if not is_local:
		return

	# Both players share zoom
	target_zoom = shared_zoom
	if has_node("Camera2D"):
		$Camera2D.zoom = $Camera2D.zoom.lerp(target_zoom, 10.0 * delta)

@rpc("any_peer", "call_local")
func blind(duration: float = 2.5) -> void:
	if is_dead: return
	
	var blind_rect = ColorRect.new()
	blind_rect.color = Color.WHITE
	blind_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	blind_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var layer = CanvasLayer.new()
	layer.layer = 100 # Draw over everything including UI
	layer.add_child(blind_rect)
	
	# Keep the blind effect strictly on this player's viewport
	layer.custom_viewport = ui_viewport
	add_child(layer)
	
	# Tween to fade out
	var tween = create_tween()
	tween.tween_property(blind_rect, "modulate:a", 0.0, duration)
	await tween.finished
	layer.queue_free()
