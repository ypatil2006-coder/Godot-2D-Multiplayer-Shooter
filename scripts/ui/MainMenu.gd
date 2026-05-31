extends Control

var available_maps = []

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$VBoxContainer/HostContainer/HostButton.pressed.connect(_on_host_pressed)
	$VBoxContainer/HBoxContainer/JoinButton.pressed.connect(_on_join_pressed)

	var map_option = $VBoxContainer/MapOption
	available_maps = MapManager.get_all_maps()
	if available_maps.is_empty():
		map_option.add_item("My First Arena")
	else:
		for map in available_maps:
			map_option.add_item(map["name"])

	$VBoxContainer/CustomMapButton.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/ui/CustomMapMenu.tscn"))
	$VBoxContainer/PracticeButton.pressed.connect(_on_practice_pressed)
	$VBoxContainer/SplitScreenButton.pressed.connect(_on_split_screen_pressed)
	$VBoxContainer/SettingsButton.pressed.connect(_on_settings_pressed)

func _apply_selected_map():
	var map_option = $VBoxContainer/MapOption
	if available_maps.is_empty():
		MapManager.selected_map_name = "My First Arena"
	elif map_option.item_count > 0:
		MapManager.selected_map_name = available_maps[map_option.selected]["_filename"]

func _on_host_pressed():
	_apply_selected_map()
	Network.host_game()
	get_tree().change_scene_to_file("res://scenes/maps/MapBase.tscn")

func _on_join_pressed():
	var ip = $VBoxContainer/HBoxContainer/IPLineEdit.text
	Network.join_game(ip)
	get_tree().change_scene_to_file("res://scenes/maps/MapBase.tscn")

func _on_practice_pressed():
	_apply_selected_map()
	get_tree().change_scene_to_file("res://scenes/maps/PracticeMap.tscn")

func _on_split_screen_pressed():
	_apply_selected_map()
	get_tree().change_scene_to_file("res://scenes/maps/SplitScreenMap.tscn")

func _on_settings_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/Settings.tscn")
