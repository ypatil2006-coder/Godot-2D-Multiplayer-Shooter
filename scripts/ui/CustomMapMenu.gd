extends Control

@onready var map_list = $VBoxContainer/ScrollContainer/MapList
@onready var create_popup = $CreateMapPopup

func _ready():
	$VBoxContainer/Header/BackButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn"))
	$VBoxContainer/Header/CreateButton.pressed.connect(func(): create_popup.popup_centered())
	
	create_popup.get_node("VBoxContainer/CreateConfirmButton").pressed.connect(_on_create_confirm)
	create_popup.get_node("VBoxContainer/CancelButton").pressed.connect(func(): create_popup.hide())
	
	refresh_list()

func refresh_list():
	for child in map_list.get_children():
		child.queue_free()
		
	var maps = MapManager.get_all_maps()
	maps.sort_custom(func(a, b): return a.get("is_favourite", false) > b.get("is_favourite", false))
	
	for map in maps:
		var item = preload("res://scenes/ui/MapListItem.tscn").instantiate()
		item.set_map_data(map)
		map_list.add_child(item)

func _on_create_confirm():
	var map_name = create_popup.get_node("VBoxContainer/NameEdit").text.strip_edges()
	var width = create_popup.get_node("VBoxContainer/HBoxContainer/WidthSpin").value
	var height = create_popup.get_node("VBoxContainer/HBoxContainer/HeightSpin").value
	
	if map_name.is_empty():
		return
		
	var new_map = {
		"name": map_name,
		"width": int(width),
		"height": int(height),
		"is_favourite": false,
		"walls": [],
		"spawns": []
	}
	MapManager.save_map(map_name, new_map)
	MapManager.selected_map_name = map_name
	
	get_tree().change_scene_to_file("res://scenes/maps/MapEditor.tscn")
