extends Node

const MAPS_DIR = "user://custom_maps/"

var selected_map_name: String = ""
var current_map_data: Dictionary = {}

func _ready():
	# Ensure the directory exists
	var dir = DirAccess.open("user://")
	if not dir.dir_exists(MAPS_DIR):
		dir.make_dir(MAPS_DIR)
		
	var maps = get_all_maps()
	if maps.is_empty():
		_create_default_map()
	elif selected_map_name == "":
		selected_map_name = maps[0].name

func _create_default_map():
	var new_map = {
		"name": "My First Arena",
		"width": 25,
		"height": 25,
		"is_favourite": true,
		"walls": [],
		"spawns": [{"x": 5, "y": 20}, {"x": 20, "y": 20}]
	}
	# Add boundary walls
	for x in range(25):
		new_map.walls.append({"x": x, "y": 0})
		new_map.walls.append({"x": x, "y": 24})
	for y in range(1, 24):
		new_map.walls.append({"x": 0, "y": y})
		new_map.walls.append({"x": 24, "y": y})
		
	save_map("My First Arena", new_map)
	selected_map_name = "My First Arena"

func save_map(map_name: String, map_data: Dictionary) -> void:
	# Add name and favourite status if not present
	if not map_data.has("name"):
		map_data["name"] = map_name
	if not map_data.has("is_favourite"):
		map_data["is_favourite"] = false
		
	var file_path = MAPS_DIR + map_name + ".json"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(map_data)
		file.store_string(json_string)
		file.close()
	else:
		print("Failed to save map: ", file_path)

func load_map(map_name: String) -> Dictionary:
	var file_path = MAPS_DIR + map_name + ".json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			return json.data
		else:
			print("JSON Parse Error: ", json.get_error_message())
	return {}

func get_all_maps() -> Array:
	var maps = []
	var dir = DirAccess.open(MAPS_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				var map_name = file_name.replace(".json", "")
				var map_data = load_map(map_name)
				if not map_data.is_empty():
					map_data["_filename"] = map_name
					maps.append(map_data)
			file_name = dir.get_next()
	return maps

func delete_map(map_name: String) -> void:
	var file_path = MAPS_DIR + map_name + ".json"
	var dir = DirAccess.open(MAPS_DIR)
	if dir and dir.file_exists(file_path):
		dir.remove(file_path)

func toggle_favourite(map_name: String) -> void:
	var map_data = load_map(map_name)
	if not map_data.is_empty():
		map_data["is_favourite"] = not map_data.get("is_favourite", false)
		save_map(map_name, map_data)
