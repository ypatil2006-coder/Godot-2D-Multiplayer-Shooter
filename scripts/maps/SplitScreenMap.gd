extends Control

var p2_node: Node2D = null
var cam2_node: Camera2D = null

func _ready() -> void:
	var vp1 = $HSplitContainer/SubViewportContainer1/SubViewport1
	var vp2 = $HSplitContainer/SubViewportContainer2/SubViewport2

	# Load the map into SubViewport1
	var map = preload("res://scenes/maps/MapBase.tscn").instantiate()
	map.skip_auto_spawn = true
	vp1.add_child(map)

	# Share the world so both viewports see the same game objects
	vp2.world_2d = vp1.world_2d

	# Get spawn positions from the map
	var spawn1 = Vector2(800, 800)
	var spawn2 = Vector2(900, 800)
	if map.default_spawns.size() > 0:
		spawn1 = map.default_spawns[0]
		spawn2 = map.default_spawns[0] + Vector2(64, 0)
	if map.default_spawns.size() > 1:
		spawn2 = map.default_spawns[1]

	var player_scene = preload("res://scenes/player/Player.tscn")

	# --- Player 1: Keyboard + Mouse (left screen) ---
	var p1 = player_scene.instantiate()
	p1.name = "Player1"
	p1.set_meta("device_id", -1)  # Keyboard
	p1.position = spawn1
	p1.get_node("ColorRect").color = Color(0.8, 0.2, 0.2)  # Red
	map.get_node("Players").add_child(p1)
	if p1.has_node("MultiplayerSynchronizer"):
		p1.get_node("MultiplayerSynchronizer").queue_free()
	p1.get_node("Camera2D").make_current()

	# --- Player 2: Controller (right screen) ---
	var p2 = player_scene.instantiate()
	p2.name = "Player2"
	p2.set_meta("device_id", 0)  # Joypad 0
	p2.position = spawn2
	p2.get_node("ColorRect").color = Color(0.2, 0.4, 0.8)  # Blue
	map.get_node("Players").add_child(p2)
	if p2.has_node("MultiplayerSynchronizer"):
		p2.get_node("MultiplayerSynchronizer").queue_free()

	# Disable Player 2's embedded camera (it lives in Viewport1's world)
	p2.get_node("Camera2D").enabled = false

	# Assign Player 2's HUD and BuyMenu to SubViewport2 without breaking hierarchy
	p1.ui_viewport = vp1
	p2.ui_viewport = vp2
	
	var hud2 = p2.get_node("HUD")
	hud2.custom_viewport = vp2
	var buy2 = p2.get_node("BuyMenu")
	buy2.custom_viewport = vp2

	# Set up visibility layers so each player only sees their own laser and grapple
	# Set up visibility layers so each player only sees their own laser and grapple
	vp1.canvas_cull_mask = 1 | 2 # Layer 1 (Default) and Layer 2 (P1 specific)
	p1.get_node("GunPivot/LaserLine").visibility_layer = 2
	p1.get_node("GrappleHook/Line2D").visibility_layer = 2
	if p1.has_node("VisionLight"):
		p1.get_node("VisionLight").visibility_layer = 2

	vp2.canvas_cull_mask = 1 | 4 # Layer 1 (Default) and Layer 3 (P2 specific)
	p2.get_node("GunPivot/LaserLine").visibility_layer = 4
	p2.get_node("GrappleHook/Line2D").visibility_layer = 4
	if p2.has_node("VisionLight"):
		p2.get_node("VisionLight").visibility_layer = 4

	var cam2 = Camera2D.new()
	cam2.name = "P2Camera"
	cam2.position_smoothing_enabled = true
	vp2.add_child(cam2)
	cam2.make_current()

	p2_node = p2
	cam2_node = cam2

	# Use RemoteTransform2D to make cam2 follow Player 2
	var rt = RemoteTransform2D.new()
	rt.name = "CameraFollower"
	rt.remote_path = cam2.get_path()
	rt.update_rotation = false
	rt.update_scale = false
	p2.add_child(rt)

	# Hide cursor in gameplay
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	# Remove unneeded nodes
	if map.has_node("TargetDummy"):
		map.get_node("TargetDummy").queue_free()
	if map.has_node("MultiplayerSpawner"):
		map.get_node("MultiplayerSpawner").queue_free()

func _process(delta: float) -> void:
	if is_instance_valid(p2_node) and is_instance_valid(cam2_node):
		cam2_node.zoom = cam2_node.zoom.lerp(p2_node.target_zoom, 10.0 * delta)
