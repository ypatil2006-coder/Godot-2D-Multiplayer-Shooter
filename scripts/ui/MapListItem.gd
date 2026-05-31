extends HBoxContainer

var map_name = ""

func set_map_data(data: Dictionary):
	map_name = data["name"]
	$NameLabel.text = map_name
	
	if data.get("is_favourite", false):
		$FavouriteButton.text = "★"
	else:
		$FavouriteButton.text = "☆"
		
	$PlayButton.pressed.connect(_on_play)
	$EditButton.pressed.connect(_on_edit)
	$FavouriteButton.pressed.connect(_on_favourite)
	$DeleteButton.pressed.connect(_on_delete)

func _on_play():
	MapManager.selected_map_name = map_name
	get_tree().change_scene_to_file("res://scenes/maps/CustomMap.tscn")
	
func _on_edit():
	MapManager.selected_map_name = map_name
	get_tree().change_scene_to_file("res://scenes/maps/MapEditor.tscn")
	
func _on_favourite():
	MapManager.toggle_favourite(map_name)
	# Find the CustomMapMenu and refresh it
	var parent = get_parent()
	while parent and not parent.has_method("refresh_list"):
		parent = parent.get_parent()
	if parent:
		parent.refresh_list()
	
func _on_delete():
	MapManager.delete_map(map_name)
	queue_free()
