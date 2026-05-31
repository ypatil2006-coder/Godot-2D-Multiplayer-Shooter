extends Node

signal ammo_changed(current: int, max_ammo: int)
signal reload_started()
signal weapon_changed(weapon_name: String)

var weapons = [
	{
		"name": "G18",
		"type": "secondary",
		"texture": preload("res://assets/textures/guns/G18.png"),
		"sprite_scale": Vector2(0.0072, 0.0072),
		"sprite_offset": Vector2(10, -2),
		"max_ammo": 20,
		"current_ammo": 20,
		"fire_rate": 0.23,
		"reload_time": 0.5,
		"damage": 20,
		"bullets_per_shot": 1,
		"spread": 0.0,
		"range": 2000.0,
		"speed": 1200.0,
		"drop_distance": 320.0,
		"recoil_free_shots": 6,
		"recoil_amount": 0.15
	},
	{
		"name": "Deagle",
		"type": "secondary",
		"texture": preload("res://assets/textures/guns/Deagle.png"),
		"sprite_scale": Vector2(0.0108, 0.0108),
		"sprite_offset": Vector2(12, -2),
		"max_ammo": 7,
		"current_ammo": 7,
		"fire_rate": 0.5,
		"reload_time": 0.7,
		"damage": 67,
		"bullets_per_shot": 1,
		"spread": 0.0,
		"range": 2000.0,
		"speed": 1800.0,
		"drop_distance": 99999.0,
		"recoil_free_shots": 999,
		"recoil_amount": 0.0
	},
	{
		"name": "Sawed-Off",
		"type": "secondary",
		"texture": preload("res://assets/textures/guns/Sawed-off.png"),
		"sprite_scale": Vector2(0.0135, 0.0135),
		"sprite_offset": Vector2(15, -1),
		"max_ammo": 2,
		"current_ammo": 2,
		"fire_rate": 0.8,
		"reload_time": 0.2,
		"damage": 20,
		"bullets_per_shot": 5,
		"spread": 0.3,
		"range": 280.0,
		"speed": 1000.0,
		"drop_distance": 99999.0,
		"recoil_free_shots": 999,
		"recoil_amount": 0.0
	},
	{
		"name": "AK",
		"type": "primary",
		"texture": preload("res://assets/textures/guns/Ak-47.png"),
		"sprite_scale": Vector2(0.018, 0.018),
		"sprite_offset": Vector2(18, -3),
		"max_ammo": 30,
		"current_ammo": 30,
		"fire_rate": 0.1,
		"reload_time": 0.8,
		"damage": 36,
		"bullets_per_shot": 1,
		"spread": 0.0,
		"range": 2000.0,
		"speed": 1500.0,
		"drop_distance": 960.0,
		"recoil_free_shots": 2,
		"recoil_amount": 0.35
	},
	{
		"name": "M4A4-S",
		"type": "primary",
		"texture": preload("res://assets/textures/guns/M4A4-S.png"),
		"sprite_scale": Vector2(0.018, 0.018),
		"sprite_offset": Vector2(20, -2),
		"max_ammo": 20,
		"current_ammo": 20,
		"fire_rate": 0.1,
		"reload_time": 0.8,
		"damage": 23,
		"bullets_per_shot": 1,
		"spread": 0.0,
		"range": 2000.0,
		"speed": 1600.0,
		"drop_distance": 1280.0,
		"recoil_free_shots": 7,
		"recoil_amount": 0.2
	}
]

var loadout = [0, -1]
var current_slot_idx := 0
var fire_timer := 0.0
var reload_timer := 0.0

var current_grenade_type := 0
const GRENADES = [
	preload("res://scenes/weapons/Grenade.tscn"),
	preload("res://scenes/weapons/Flashbang.tscn"),
	preload("res://scenes/weapons/ToxicGrenade.tscn"),
	preload("res://scenes/weapons/Molotov.tscn")
]

var is_reloading := false
var time_since_last_shot := 0.0
var grenade_cooldown := 0.0
var consecutive_shots := 0

# Debounce for controller buttons (prevent repeat triggers)
var _prev_frag := false
var _prev_flashbang := false
var _prev_toxic := false
var _prev_molotov := false
var _prev_buy := false
var _prev_slot1 := false
var _prev_slot2 := false

@onready var player: CharacterBody2D = owner
@onready var gun_pivot: Node2D = $"../GunPivot"
@onready var gun_sprite: Sprite2D = $"../GunPivot/GunSprite"
@onready var gun_muzzle: Marker2D = $"../GunPivot/Muzzle"
@onready var laser_cast: RayCast2D = $"../GunPivot/LaserCast"
@onready var laser_line: Line2D = $"../GunPivot/LaserLine"

func _get_device_id() -> int:
	if owner.has_meta("device_id"):
		return owner.get_meta("device_id")
	return -1

func _ready() -> void:
	loadout = [-1, 0]  # G18 only
	call_deferred("_equip_slot", 1)

func _physics_process(delta: float) -> void:
	# Multiplayer authority check
	if player.has_node("MultiplayerSynchronizer"):
		if player.get_node("MultiplayerSynchronizer").get_multiplayer_authority() != multiplayer.get_unique_id():
			return

	if player.is_dead:
		laser_line.hide()
		return
	else:
		laser_line.show()

	time_since_last_shot += delta
	if grenade_cooldown > 0.0:
		grenade_cooldown -= delta

	var device_id = _get_device_id()

	# --- Read inputs based on device ---
	var throw_frag := false
	var throw_flashbang := false
	var throw_toxic := false
	var throw_molotov := false
	var shoot_pressed := false
	var reload_pressed := false
	var slot1_pressed := false
	var slot2_pressed := false
	var buy_pressed := false

	if device_id >= 0:
		# Controller inputs
		var cur_frag = Input.is_joy_button_pressed(device_id, JOY_BUTTON_DPAD_UP)
		var cur_flashbang = Input.is_joy_button_pressed(device_id, JOY_BUTTON_DPAD_LEFT)
		var cur_toxic = Input.is_joy_button_pressed(device_id, JOY_BUTTON_DPAD_RIGHT)
		var cur_molotov = Input.is_joy_button_pressed(device_id, JOY_BUTTON_DPAD_DOWN)
		var cur_buy = Input.is_joy_button_pressed(device_id, JOY_BUTTON_B)
		var cur_slot1 = Input.is_joy_button_pressed(device_id, JOY_BUTTON_LEFT_SHOULDER)
		var cur_slot2 = Input.is_joy_button_pressed(device_id, JOY_BUTTON_RIGHT_SHOULDER)

		# Just pressed detection (rising edge)
		throw_frag = cur_frag and not _prev_frag
		throw_flashbang = cur_flashbang and not _prev_flashbang
		throw_toxic = cur_toxic and not _prev_toxic
		throw_molotov = cur_molotov and not _prev_molotov
		buy_pressed = cur_buy and not _prev_buy
		slot1_pressed = cur_slot1 and not _prev_slot1
		slot2_pressed = cur_slot2 and not _prev_slot2

		_prev_frag = cur_frag
		_prev_flashbang = cur_flashbang
		_prev_toxic = cur_toxic
		_prev_molotov = cur_molotov
		_prev_buy = cur_buy
		_prev_slot1 = cur_slot1
		_prev_slot2 = cur_slot2

		# LT = fire (axis, held)
		shoot_pressed = Input.get_joy_axis(device_id, JOY_AXIS_TRIGGER_LEFT) > 0.5
		reload_pressed = Input.is_joy_button_pressed(device_id, JOY_BUTTON_Y)
	else:
		# Keyboard inputs
		throw_flashbang = Input.is_physical_key_pressed(KEY_Q) and not _prev_flashbang
		throw_frag = Input.is_physical_key_pressed(KEY_E) and not _prev_frag
		throw_toxic = Input.is_physical_key_pressed(KEY_C) and not _prev_toxic
		throw_molotov = Input.is_physical_key_pressed(KEY_X) and not _prev_molotov
		_prev_flashbang = Input.is_physical_key_pressed(KEY_Q)
		_prev_frag = Input.is_physical_key_pressed(KEY_E)
		_prev_toxic = Input.is_physical_key_pressed(KEY_C)
		_prev_molotov = Input.is_physical_key_pressed(KEY_X)

		shoot_pressed = Input.is_action_pressed("shoot")
		reload_pressed = Input.is_action_just_pressed("reload")
		slot1_pressed = Input.is_physical_key_pressed(KEY_1) and not _prev_slot1
		slot2_pressed = Input.is_physical_key_pressed(KEY_2) and not _prev_slot2
		_prev_slot1 = Input.is_physical_key_pressed(KEY_1)
		_prev_slot2 = Input.is_physical_key_pressed(KEY_2)
		buy_pressed = Input.is_action_just_pressed("buy_menu")

	# --- Buy Menu toggle ---
	if buy_pressed:
		if owner.has_node("BuyMenu"):
			owner.get_node("BuyMenu").visible = !owner.get_node("BuyMenu").visible

	# --- Grenades ---
	if grenade_cooldown <= 0.0:
		if throw_frag:
			current_grenade_type = 0
			grenade_cooldown = 1.5
			_throw_grenade()
		elif throw_flashbang:
			current_grenade_type = 1
			grenade_cooldown = 1.5
			_throw_grenade()
		elif throw_toxic:
			current_grenade_type = 2
			grenade_cooldown = 1.5
			_throw_grenade()
		elif throw_molotov:
			current_grenade_type = 3
			grenade_cooldown = 1.5
			_throw_grenade()

	if time_since_last_shot > 0.4:
		consecutive_shots = 0

	# --- Laser sight ---
	_update_laser()

	# --- Weapon Switching ---
	if not is_reloading:
		if slot1_pressed: _equip_slot(0)
		elif slot2_pressed: _equip_slot(1)

	var w = null
	if loadout[current_slot_idx] != -1:
		w = weapons[loadout[current_slot_idx]]

	# Don't shoot while buy menu is open
	var is_menu_open = false
	if owner.has_node("BuyMenu"):
		is_menu_open = owner.get_node("BuyMenu").visible
	if is_menu_open:
		return

	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			_finish_reload()
		return

	if fire_timer > 0.0:
		fire_timer -= delta

	if w == null:
		return

	if reload_pressed and w["current_ammo"] < w["max_ammo"]:
		_start_reload()
		return

	if shoot_pressed and fire_timer <= 0.0:
		if w["current_ammo"] > 0:
			fire()
			fire_timer = w["fire_rate"]
		else:
			_start_reload()

	if w["current_ammo"] <= 0 and not is_reloading:
		_start_reload()

func _update_laser() -> void:
	if laser_cast.is_colliding():
		laser_line.set_point_position(1, laser_line.to_local(laser_cast.get_collision_point()))
		var collider = laser_cast.get_collider()
		if collider and (collider.is_in_group("enemies") or (collider.is_in_group("player") and collider != player)):
			laser_line.default_color = Color(1, 0, 0, 0.6)
		else:
			laser_line.default_color = Color(0, 1, 0, 0.6)
	else:
		laser_line.set_point_position(1, laser_cast.target_position)
		laser_line.default_color = Color(0, 1, 0, 0.6)

func _equip_weapon(weapon_idx: int) -> void:
	var w = weapons[weapon_idx]
	if w["type"] == "primary":
		loadout[0] = weapon_idx
		if current_slot_idx == 0:
			current_slot_idx = -1
		_equip_slot(0)
	elif w["type"] == "secondary":
		loadout[1] = weapon_idx
		if current_slot_idx == 1:
			current_slot_idx = -1
		_equip_slot(1)

func _equip_slot(slot_idx: int) -> void:
	if is_reloading or loadout[slot_idx] == -1 or (current_slot_idx == slot_idx and Engine.get_frames_drawn() > 0):
		return
	current_slot_idx = slot_idx
	var w = weapons[loadout[current_slot_idx]]
	consecutive_shots = 0
	
	if "texture" in w:
		gun_sprite.texture = w["texture"]
		if "sprite_scale" in w:
			gun_sprite.scale = w["sprite_scale"]
		if "sprite_offset" in w:
			gun_sprite.position = w["sprite_offset"]

	if w["name"] == "G18":
		gun_muzzle.position = Vector2(20, 0)
		laser_cast.position = Vector2(20, 0)
		laser_line.set_point_position(0, Vector2(20, 0))
	elif w["name"] == "Deagle":
		gun_muzzle.position = Vector2(26, 0)
		laser_cast.position = Vector2(26, 0)
		laser_line.set_point_position(0, Vector2(26, 0))
	elif w["name"] == "Sawed-Off":
		gun_muzzle.position = Vector2(30, 0)
		laser_cast.position = Vector2(30, 0)
		laser_line.set_point_position(0, Vector2(30, 0))
	elif w["name"] == "AK":
		gun_muzzle.position = Vector2(38, 0)
		laser_cast.position = Vector2(38, 0)
		laser_line.set_point_position(0, Vector2(38, 0))
	elif w["name"] == "M4A4-S":
		gun_muzzle.position = Vector2(42, 0)
		laser_cast.position = Vector2(42, 0)
		laser_line.set_point_position(0, Vector2(42, 0))

	call_deferred("emit_signal", "weapon_changed", w["name"])
	emit_signal("ammo_changed", w["current_ammo"], w["max_ammo"])
	fire_timer = 0.0

func _start_reload() -> void:
	if loadout[current_slot_idx] == -1: return
	is_reloading = true
	var w = weapons[loadout[current_slot_idx]]
	reload_timer = w["reload_time"]
	consecutive_shots = 0
	emit_signal("reload_started")

func _finish_reload() -> void:
	is_reloading = false
	var w = weapons[loadout[current_slot_idx]]
	w["current_ammo"] = w["max_ammo"]
	emit_signal("ammo_changed", w["current_ammo"], w["max_ammo"])

func fire() -> void:
	var w = weapons[loadout[current_slot_idx]]
	w["current_ammo"] -= 1

	consecutive_shots += 1
	time_since_last_shot = 0.0

	var device_id = _get_device_id()
	var base_dir = Vector2.RIGHT

	if device_id >= 0:
		# Controller: aim direction from right joystick
		var joy_x = Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X)
		var joy_y = Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y)
		var joy_aim = Vector2(joy_x, joy_y)
		if joy_aim.length() > 0.15:
			base_dir = joy_aim.normalized()
		else:
			base_dir = Vector2.from_angle(gun_pivot.rotation)
	else:
		var mouse_pos = player.get_global_mouse_position()
		base_dir = (mouse_pos - gun_muzzle.global_position).normalized()

	var recoil_spread = 0.0
	if consecutive_shots > w["recoil_free_shots"]:
		recoil_spread = w["recoil_amount"]

	for i in w["bullets_per_shot"]:
		var dir = base_dir
		if w["bullets_per_shot"] > 1:
			dir = dir.rotated(randf_range(-w["spread"], w["spread"]))
		if recoil_spread > 0.0:
			dir = dir.rotated(randf_range(-recoil_spread, recoil_spread))
		if multiplayer.has_multiplayer_peer() and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
			rpc("rpc_fire", gun_muzzle.global_position, dir, w["damage"], w["speed"], w["range"], w["drop_distance"])
		else:
			rpc_fire(gun_muzzle.global_position, dir, w["damage"], w["speed"], w["range"], w["drop_distance"])

	emit_signal("ammo_changed", w["current_ammo"], w["max_ammo"])

@rpc("any_peer", "call_local")
func rpc_fire(spawn_pos: Vector2, direction: Vector2, damage: int, speed: float, max_dist: float, drop_dist: float) -> void:
	BulletPool.fire(spawn_pos, direction, damage, speed, max_dist, drop_dist, player)

func _throw_grenade() -> void:
	var device_id = _get_device_id()
	var dir: Vector2

	if device_id >= 0:
		var joy_x = Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X)
		var joy_y = Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y)
		var joy_aim = Vector2(joy_x, joy_y)
		if joy_aim.length() > 0.15:
			dir = joy_aim.normalized()
		else:
			dir = Vector2.from_angle(gun_pivot.rotation)
	else:
		var mouse_pos = player.get_global_mouse_position()
		dir = (mouse_pos - player.global_position).normalized()

	var velocity = dir * 800.0 + player.velocity * 1.0
	if multiplayer.has_multiplayer_peer() and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		rpc("rpc_throw_grenade", gun_muzzle.global_position, velocity, current_grenade_type)
	else:
		rpc_throw_grenade(gun_muzzle.global_position, velocity, current_grenade_type)

@rpc("any_peer", "call_local")
func rpc_throw_grenade(spawn_pos: Vector2, velocity: Vector2, g_type: int) -> void:
	var grenade = GRENADES[g_type].instantiate()
	if "shooter" in grenade:
		grenade.shooter = player
	player.get_parent().add_child(grenade)
	grenade.global_position = spawn_pos
	grenade.linear_velocity = velocity
	if grenade is RigidBody2D:
		grenade.angular_velocity = randf_range(-15.0, 15.0)
