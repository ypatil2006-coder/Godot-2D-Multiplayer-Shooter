extends Control

var actions = ["move_left", "move_right", "jump", "shoot", "reload", "grapple"]
var action_labels = ["Move Left", "Move Right", "Jump", "Shoot", "Reload", "Grapple"]

var awaiting_input = false
var current_action = ""

func _ready() -> void:
	$VBoxContainer/BackButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn"))
	
	for i in range(actions.size()):
		var action = actions[i]
		var hbox = HBoxContainer.new()
		var label = Label.new()
		label.text = action_labels[i]
		label.custom_minimum_size = Vector2(200, 40)
		
		var btn = Button.new()
		var events = InputMap.action_get_events(action)
		if events.size() > 0:
			btn.text = events[0].as_text()
		else:
			btn.text = "Unbound"
			
		btn.pressed.connect(_on_rebind_pressed.bind(action, btn))
		
		hbox.add_child(label)
		hbox.add_child(btn)
		$VBoxContainer/ScrollContainer/ActionList.add_child(hbox)

func _on_rebind_pressed(action_name: String, btn: Button) -> void:
	awaiting_input = true
	current_action = action_name
	btn.text = "Press any key..."
	
	# Store reference to button to update text later
	set_meta("active_btn", btn)

func _input(event: InputEvent) -> void:
	if not awaiting_input: return
	
	if (event is InputEventKey and event.pressed) or (event is InputEventJoypadButton and event.pressed) or (event is InputEventMouseButton and event.pressed):
		InputMap.action_erase_events(current_action)
		InputMap.action_add_event(current_action, event)
		
		var btn = get_meta("active_btn")
		btn.text = event.as_text()
		
		InputRouter.save_custom_binds()
		
		awaiting_input = false
		get_viewport().set_input_as_handled()
