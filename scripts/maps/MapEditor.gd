extends Node2D

const CELL_SIZE = 64

@onready var camera = $Camera2D
@onready var spawn_container = $SpawnContainer

var map_data = {}
var map_name = ""
var current_brush = "wall" # "wall" or "spawn"
var current_color = Color.WHITE
var current_shape = "square" # "square", "tl", "tr", "bl", "br"

var zoom_level = 1.0
const MIN_ZOOM = 0.2
const MAX_ZOOM = 3.0
var is_panning = false

var palette_colors = [
	Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.CYAN, 
	Color.MAGENTA, Color.ORANGE, Color.PURPLE, Color.PINK, Color.BROWN,
	Color.WHITE, Color.LIGHT_GRAY, Color.GRAY, Color.DARK_GRAY, Color.BLACK,
	Color.MAROON, Color.OLIVE, Color.html("000080"), Color.html("008080"), Color.html("00ff00")
]

func _ready():
	map_name = MapManager.selected_map_name
	map_data = MapManager.load_map(map_name)
	
	if map_data.is_empty():
		map_data = {"width": 25, "height": 25, "blocks": [], "spawns": [], "bg_color": "1e1e1e", "bg_image": ""}
	else:
		# Compatibility with old maps
		if map_data.has("walls"):
			map_data["blocks"] = []
			for w in map_data["walls"]:
				map_data["blocks"].append({"x": w.x, "y": w.y, "c": "ffffff", "s": "square"})
			map_data.erase("walls")
			
		if not map_data.has("bg_color"): map_data["bg_color"] = "1e1e1e"
		if not map_data.has("bg_image"): map_data["bg_image"] = ""
			
	# Init UI
	var ui_top = $CanvasLayer/UI/VBoxContainer/TopRow
	ui_top.get_node("WallButton").pressed.connect(func(): current_brush = "wall")
	ui_top.get_node("SpawnButton").pressed.connect(func(): current_brush = "spawn")
	ui_top.get_node("SaveExitButton").pressed.connect(_on_save_exit)
	
	ui_top.get_node("ShapeSquare").pressed.connect(func(): current_shape = "square")
	ui_top.get_node("ShapeTL").pressed.connect(func(): current_shape = "tl")
	ui_top.get_node("ShapeTR").pressed.connect(func(): current_shape = "tr")
	ui_top.get_node("ShapeBL").pressed.connect(func(): current_shape = "bl")
	ui_top.get_node("ShapeBR").pressed.connect(func(): current_shape = "br")

	_add_icon(ui_top.get_node("ShapeSquare"), [Vector2(8,8), Vector2(32,8), Vector2(32,32), Vector2(8,32)])
	_add_icon(ui_top.get_node("ShapeTL"), [Vector2(8,8), Vector2(32,8), Vector2(8,32)])
	_add_icon(ui_top.get_node("ShapeTR"), [Vector2(8,8), Vector2(32,8), Vector2(32,32)])
	_add_icon(ui_top.get_node("ShapeBL"), [Vector2(8,8), Vector2(32,32), Vector2(8,32)])
	_add_icon(ui_top.get_node("ShapeBR"), [Vector2(32,8), Vector2(32,32), Vector2(8,32)])
	
	var bg_color_picker = ui_top.get_node("BGColorPicker")
	bg_color_picker.color = Color(map_data["bg_color"])
	bg_color_picker.color_changed.connect(func(color: Color): 
		map_data["bg_color"] = color.to_html(false)
		update_bg()
	)
	
	var custom_bg_btn = ui_top.get_node("CustomBGBtn")
	custom_bg_btn.pressed.connect(func(): $CanvasLayer/FileDialog.popup_centered(Vector2(600, 400)))
	$CanvasLayer/FileDialog.file_selected.connect(func(path: String):
		map_data["bg_image"] = path
		update_bg()
	)
	
	update_bg()
	
	var palette = $CanvasLayer/UI/VBoxContainer/BottomRow/PaletteContainer
	for i in range(20):
		var cp = ColorPickerButton.new()
		cp.custom_minimum_size = Vector2(30, 30)
		cp.color = palette_colors[i]
		cp.color_changed.connect(func(color: Color): current_color = color)
		cp.pressed.connect(func(): current_color = cp.color)
		palette.add_child(cp)
		
	if map_data.has("spawns"):
		for s in map_data["spawns"]:
			add_spawn_visual(Vector2i(int(s.x), int(s.y)))

func _add_icon(btn: Button, pts: Array):
	var poly = Polygon2D.new()
	poly.polygon = PackedVector2Array(pts)
	poly.color = Color(0.8, 0.8, 0.8)
	btn.add_child(poly)

func update_bg():
	$BGLayer/BGColorRect.color = Color(map_data["bg_color"])
	if map_data["bg_image"] != "":
		var img = Image.new()
		var err = img.load(map_data["bg_image"])
		if err == OK:
			var tex = ImageTexture.create_from_image(img)
			$BGLayer/BGTextureRect.texture = tex
			$BGLayer/BGTextureRect.show()
	else:
		$BGLayer/BGTextureRect.hide()

func _process(delta):
	handle_camera(delta)
	queue_redraw()

func _draw():
	if not map_data.has("width"): return
	var w = map_data["width"]
	var h = map_data["height"]
	
	draw_rect(Rect2(0, 0, w * CELL_SIZE, h * CELL_SIZE), Color.RED, false, 2.0)
	
	for x in range(w + 1):
		draw_line(Vector2(x * CELL_SIZE, 0), Vector2(x * CELL_SIZE, h * CELL_SIZE), Color(1,1,1,0.2))
	for y in range(h + 1):
		draw_line(Vector2(0, y * CELL_SIZE), Vector2(w * CELL_SIZE, y * CELL_SIZE), Color(1,1,1,0.2))

	if map_data.has("blocks"):
		for block in map_data["blocks"]:
			var bx = block.x * CELL_SIZE
			var by = block.y * CELL_SIZE
			var color = Color(block.c)
			
			if block.s == "square":
				draw_rect(Rect2(bx, by, CELL_SIZE, CELL_SIZE), color)
			elif block.s == "tl":
				draw_polygon(PackedVector2Array([Vector2(bx, by), Vector2(bx + CELL_SIZE, by), Vector2(bx, by + CELL_SIZE)]), PackedColorArray([color]))
			elif block.s == "tr":
				draw_polygon(PackedVector2Array([Vector2(bx, by), Vector2(bx + CELL_SIZE, by), Vector2(bx + CELL_SIZE, by + CELL_SIZE)]), PackedColorArray([color]))
			elif block.s == "bl":
				draw_polygon(PackedVector2Array([Vector2(bx, by), Vector2(bx + CELL_SIZE, by + CELL_SIZE), Vector2(bx, by + CELL_SIZE)]), PackedColorArray([color]))
			elif block.s == "br":
				draw_polygon(PackedVector2Array([Vector2(bx + CELL_SIZE, by), Vector2(bx + CELL_SIZE, by + CELL_SIZE), Vector2(bx, by + CELL_SIZE)]), PackedColorArray([color]))

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_level = clamp(zoom_level * 1.1, MIN_ZOOM, MAX_ZOOM)
			camera.zoom = Vector2(zoom_level, zoom_level)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_level = clamp(zoom_level / 1.1, MIN_ZOOM, MAX_ZOOM)
			camera.zoom = Vector2(zoom_level, zoom_level)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = event.pressed
			
	elif event is InputEventMouseMotion and is_panning:
		camera.position -= event.relative / zoom_level

	# Handle painting in unhandled input so UI consumes clicks first
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			var mouse_pos = get_global_mouse_position()
			var grid_x = floor(mouse_pos.x / CELL_SIZE)
			var grid_y = floor(mouse_pos.y / CELL_SIZE)
			
			if grid_x < 0 or grid_x >= map_data["width"] or grid_y < 0 or grid_y >= map_data["height"]:
				return
				
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				if current_brush == "wall":
					erase_block(grid_x, grid_y)
					map_data["blocks"].append({"x": grid_x, "y": grid_y, "c": current_color.to_html(false), "s": current_shape})
					remove_spawn_at(Vector2i(grid_x, grid_y))
				elif current_brush == "spawn":
					erase_block(grid_x, grid_y)
					if not has_spawn_at(Vector2i(grid_x, grid_y)):
						add_spawn_visual(Vector2i(grid_x, grid_y))
						
			elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				erase_block(grid_x, grid_y)
				remove_spawn_at(Vector2i(grid_x, grid_y))

func handle_camera(delta):
	var move = Vector2.ZERO
	if Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D): move.x += 1
	if Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A): move.x -= 1
	if Input.is_action_pressed("ui_down") or Input.is_physical_key_pressed(KEY_S): move.y += 1
	if Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W): move.y -= 1
	
	camera.position += move * 500 * delta

func erase_block(gx, gy):
	for i in range(map_data["blocks"].size() - 1, -1, -1):
		var b = map_data["blocks"][i]
		if b.x == gx and b.y == gy:
			map_data["blocks"].remove_at(i)

func add_spawn_visual(grid_pos: Vector2i):
	var rect = ColorRect.new()
	rect.color = Color(0, 1, 0, 0.5)
	rect.size = Vector2(CELL_SIZE, CELL_SIZE)
	rect.position = Vector2(grid_pos.x * CELL_SIZE, grid_pos.y * CELL_SIZE)
	rect.name = str(grid_pos.x) + "_" + str(grid_pos.y)
	spawn_container.add_child(rect)

func remove_spawn_at(grid_pos: Vector2i):
	var node_name = str(grid_pos.x) + "_" + str(grid_pos.y)
	var node = spawn_container.get_node_or_null(node_name)
	if node:
		node.queue_free()

func has_spawn_at(grid_pos: Vector2i) -> bool:
	var node_name = str(grid_pos.x) + "_" + str(grid_pos.y)
	return spawn_container.has_node(node_name)

func _on_save_exit():
	var new_spawns = []
	for child in spawn_container.get_children():
		var parts = child.name.split("_")
		if parts.size() == 2:
			new_spawns.append({"x": int(parts[0]), "y": int(parts[1])})
			
	map_data["spawns"] = new_spawns
	
	MapManager.save_map(map_name, map_data)
	get_tree().change_scene_to_file("res://scenes/ui/CustomMapMenu.tscn")
