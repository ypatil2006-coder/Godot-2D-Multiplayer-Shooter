extends CanvasLayer

var _prev_start := false

func _ready():
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS  # Keep processing while tree is paused
	$ColorRect/VBoxContainer/ResumeButton.pressed.connect(_on_resume)
	$ColorRect/VBoxContainer/QuitButton.pressed.connect(_on_quit)
	if has_node("ColorRect/VBoxContainer/IPContainer/CopyButton"):
		$ColorRect/VBoxContainer/IPContainer/CopyButton.pressed.connect(_on_copy)

func _on_copy():
	var text = $ColorRect/VBoxContainer/IPContainer/IPLabel.text
	DisplayServer.clipboard_set(text)

func _process(_delta: float) -> void:
	# Check controller Start button for pause
	# This runs on all connected joypads
	for joy_id in Input.get_connected_joypads():
		var cur = Input.is_joy_button_pressed(joy_id, JOY_BUTTON_START)
		if cur and not _prev_start:
			_toggle_pause()
		_prev_start = cur

func _input(event):
	# Only handle pause in game scenes (not menus)
	var current_scene = get_tree().current_scene
	if current_scene:
		var path = current_scene.scene_file_path
		if path.contains("MainMenu") or path.contains("CustomMapMenu") or path.contains("MapEditor") or path.contains("Settings"):
			return

	if event.is_action_pressed("pause_game"):
		_toggle_pause()

func _toggle_pause() -> void:
	if visible:
		_on_resume()
	else:
		show()
		get_tree().paused = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		# Show IP info if hosting
		if has_node("ColorRect/VBoxContainer/IPContainer"):
			var ip_container = $ColorRect/VBoxContainer/IPContainer
			if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
				$ColorRect/VBoxContainer/IPContainer/IPLabel.text = Network.get_local_ip() + ":7777"
				ip_container.show()
			else:
				ip_container.hide()

func _on_resume():
	hide()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _on_quit():
	hide()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
