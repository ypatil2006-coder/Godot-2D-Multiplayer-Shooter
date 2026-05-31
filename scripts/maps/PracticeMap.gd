extends Node2D

var default_spawns = []

func _ready() -> void:
	if has_node("LevelTileMap"):
		var tm = $LevelTileMap
		tm.clear()
		tm.hide()
	
	var map_name = MapManager.selected_map_name
	var map_data = MapManager.load_map(map_name)
	
	if map_data.is_empty():
		default_spawns.append(Vector2(800, 800))
	else:
		setup_background(map_data)
		setup_blocks(map_data)
		setup_spawns(map_data)
				
	# Darken the map for Fog of War
	var canvas_modulate = CanvasModulate.new()
	canvas_modulate.color = Color(0.15, 0.15, 0.15, 1.0)
	add_child(canvas_modulate)

	# Target Dummy
	if has_node("TargetDummy"):
		if default_spawns.size() > 1:
			$TargetDummy.position = default_spawns[1]
		else:
			$TargetDummy.position = default_spawns[0] - Vector2(0, 200)

	# Local Player Spawning
	var player_scene = preload("res://scenes/player/Player.tscn")
	var p = player_scene.instantiate()
	# Just give it a generic ID since it's local
	p.name = "1"
	p.position = default_spawns[0]
	add_child(p)

func setup_background(map_data: Dictionary):
	var bg_layer = CanvasLayer.new()
	bg_layer.layer = -1
	add_child(bg_layer)
	
	var bg_color_rect = ColorRect.new()
	bg_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_color_rect.color = Color(map_data.get("bg_color", "1e1e1e"))
	bg_layer.add_child(bg_color_rect)
	
	var bg_img_path = map_data.get("bg_image", "")
	if bg_img_path != "":
		var img = Image.new()
		var err = img.load(bg_img_path)
		if err == OK:
			var tex = ImageTexture.create_from_image(img)
			var tr = TextureRect.new()
			tr.texture = tex
			tr.set_anchors_preset(Control.PRESET_FULL_RECT)
			tr.stretch_mode = TextureRect.STRETCH_TILE
			bg_layer.add_child(tr)

func setup_blocks(map_data: Dictionary):
	var block_container = Node2D.new()
	add_child(block_container)
	
	var slippery_mat = PhysicsMaterial.new()
	slippery_mat.friction = 0.0
	var CELL_SIZE = 64
	
	var blocks = []
	if map_data.has("blocks"):
		blocks = map_data["blocks"]
	elif map_data.has("walls"):
		for w in map_data["walls"]:
			blocks.append({"x": w.x, "y": w.y, "c": "ffffff", "s": "square"})
			
	for b in blocks:
		var sb = StaticBody2D.new()
		sb.position = Vector2(b.x * CELL_SIZE, b.y * CELL_SIZE)
		sb.collision_layer = 2 # Matches the old TileMap layer
		sb.collision_mask = 0
		
		var poly = Polygon2D.new()
		poly.color = Color(b.c)
		
		var coll = CollisionPolygon2D.new()
		
		var pts = []
		if b.s == "square":
			pts = [Vector2(0,0), Vector2(CELL_SIZE,0), Vector2(CELL_SIZE,CELL_SIZE), Vector2(0,CELL_SIZE)]
		elif b.s == "tl":
			pts = [Vector2(0,0), Vector2(CELL_SIZE,0), Vector2(0,CELL_SIZE)]
			sb.physics_material_override = slippery_mat
		elif b.s == "tr":
			pts = [Vector2(0,0), Vector2(CELL_SIZE,0), Vector2(CELL_SIZE,CELL_SIZE)]
			sb.physics_material_override = slippery_mat
		elif b.s == "bl":
			pts = [Vector2(0,0), Vector2(CELL_SIZE,CELL_SIZE), Vector2(0,CELL_SIZE)]
			sb.physics_material_override = slippery_mat
		elif b.s == "br":
			pts = [Vector2(CELL_SIZE,0), Vector2(CELL_SIZE,CELL_SIZE), Vector2(0,CELL_SIZE)]
			sb.physics_material_override = slippery_mat
			
		if pts.size() > 0:
			poly.polygon = PackedVector2Array(pts)
			coll.polygon = PackedVector2Array(pts)
			
			sb.add_child(poly)
			sb.add_child(coll)
			block_container.add_child(sb)

func setup_spawns(map_data: Dictionary):
	var CELL_SIZE = 64
	if map_data.has("spawns") and not map_data["spawns"].is_empty():
		for s in map_data["spawns"]:
			default_spawns.append(Vector2(s.x * CELL_SIZE + (CELL_SIZE/2), s.y * CELL_SIZE + (CELL_SIZE/2)))
	else:
		default_spawns.append(Vector2(map_data.get("width", 25) * 32, map_data.get("height", 25) * 32))
