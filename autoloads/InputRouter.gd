extends Node

# This script runs automatically on game start and ensures PC + Controller controls are bound.

func _ready() -> void:
	_setup_pc_bindings()
	_setup_controller_bindings()
	load_custom_binds()

func _setup_pc_bindings() -> void:
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("reload", KEY_R)
	_add_key_action("weapon_1", KEY_1)
	_add_key_action("weapon_2", KEY_2)
	_add_key_action("buy_menu", KEY_B)
	_add_key_action("pause_game", KEY_ESCAPE)
	_add_key_action("throw_frag", KEY_E)
	_add_key_action("throw_flashbang", KEY_Q)
	_add_key_action("throw_toxic", KEY_C)
	_add_key_action("throw_molotov", KEY_X)
	_add_mouse_action("shoot", MOUSE_BUTTON_LEFT)
	_add_mouse_action("grapple", MOUSE_BUTTON_RIGHT)

func _setup_controller_bindings() -> void:
	# Movement is handled via raw axis in PlayerMovement, not via InputMap
	# Jump = A button
	_add_joy_action("joy_jump", JOY_BUTTON_A)
	# Fire = Left Trigger (handled via axis in PlayerShoot)
	# Grapple = Right Trigger (handled via axis in PlayerGrapple)
	# Primary weapon = LB
	_add_joy_action("joy_weapon_1", JOY_BUTTON_LEFT_SHOULDER)
	# Secondary weapon = RB
	_add_joy_action("joy_weapon_2", JOY_BUTTON_RIGHT_SHOULDER)
	# Buy menu = B
	_add_joy_action("joy_buy_menu", JOY_BUTTON_B)
	# Pause = Start
	_add_joy_action("joy_pause", JOY_BUTTON_START)
	# Grenades on D-Pad
	_add_joy_action("joy_frag", JOY_BUTTON_DPAD_UP)
	_add_joy_action("joy_flashbang", JOY_BUTTON_DPAD_LEFT)
	_add_joy_action("joy_toxic", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_action("joy_molotov", JOY_BUTTON_DPAD_DOWN)
	# Reload = Y
	_add_joy_action("joy_reload", JOY_BUTTON_Y)

func _add_key_action(action_name: String, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	else:
		InputMap.action_erase_events(action_name)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action_name, ev)

func _add_mouse_action(action_name: String, button_index: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	else:
		InputMap.action_erase_events(action_name)
	var ev := InputEventMouseButton.new()
	ev.button_index = button_index
	InputMap.action_add_event(action_name, ev)

func _add_joy_action(action_name: String, button: JoyButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	else:
		InputMap.action_erase_events(action_name)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action_name, ev)

func save_custom_binds() -> void:
	var config = ConfigFile.new()
	for action in InputMap.get_actions():
		if action.begins_with("ui_"): continue
		var events = InputMap.action_get_events(action)
		var event_data = []
		for ev in events:
			if ev is InputEventKey:
				event_data.append({"type": "key", "physical_keycode": ev.physical_keycode, "keycode": ev.keycode})
			elif ev is InputEventMouseButton:
				event_data.append({"type": "mouse", "button_index": ev.button_index})
			elif ev is InputEventJoypadButton:
				event_data.append({"type": "joypad_button", "button_index": ev.button_index})
		config.set_value("keybinds", action, event_data)
	config.save("user://keybinds.cfg")

func load_custom_binds() -> void:
	var config = ConfigFile.new()
	if config.load("user://keybinds.cfg") != OK:
		return
	
	for action in config.get_section_keys("keybinds"):
		var event_data = config.get_value("keybinds", action, [])
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		else:
			InputMap.action_erase_events(action)
			
		for data in event_data:
			if data["type"] == "key":
				var ev = InputEventKey.new()
				ev.physical_keycode = data["physical_keycode"]
				ev.keycode = data["keycode"]
				InputMap.action_add_event(action, ev)
			elif data["type"] == "mouse":
				var ev = InputEventMouseButton.new()
				ev.button_index = data["button_index"]
				InputMap.action_add_event(action, ev)
			elif data["type"] == "joypad_button":
				var ev = InputEventJoypadButton.new()
				ev.button_index = data["button_index"]
				InputMap.action_add_event(action, ev)
