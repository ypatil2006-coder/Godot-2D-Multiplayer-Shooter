extends CanvasLayer

signal weapon_equipped(idx: int)

var _equip_buttons := []
var _focus_index := 0
var _prev_joy_up := false
var _prev_joy_down := false
var _prev_joy_left := false
var _prev_joy_right := false
var _prev_a := false

func _get_device_id() -> int:
	if owner and owner.has_meta("device_id"):
		return owner.get_meta("device_id")
	return -1

func _ready() -> void:
	visible = false
	visibility_changed.connect(_on_visibility_changed)

	# Connect buttons
	$ColorRect/CenterContainer/VBoxContainer/SecondaryBox/PistolBox/EquipBtn.pressed.connect(_on_equip_pressed.bind(0))
	$ColorRect/CenterContainer/VBoxContainer/SecondaryBox/DeagleBox/EquipBtn.pressed.connect(_on_equip_pressed.bind(1))
	$ColorRect/CenterContainer/VBoxContainer/SecondaryBox/ShotgunBox/EquipBtn.pressed.connect(_on_equip_pressed.bind(2))
	$ColorRect/CenterContainer/VBoxContainer/PrimaryBox/AKBox/EquipBtn.pressed.connect(_on_equip_pressed.bind(3))
	$ColorRect/CenterContainer/VBoxContainer/PrimaryBox/M4A4Box/EquipBtn.pressed.connect(_on_equip_pressed.bind(4))

	# Build list of equip buttons for controller navigation
	_equip_buttons = [
		$ColorRect/CenterContainer/VBoxContainer/PrimaryBox/AKBox/EquipBtn,
		$ColorRect/CenterContainer/VBoxContainer/PrimaryBox/M4A4Box/EquipBtn,
		$ColorRect/CenterContainer/VBoxContainer/SecondaryBox/PistolBox/EquipBtn,
		$ColorRect/CenterContainer/VBoxContainer/SecondaryBox/DeagleBox/EquipBtn,
		$ColorRect/CenterContainer/VBoxContainer/SecondaryBox/ShotgunBox/EquipBtn,
	]
	
	# Add gun images dynamically to avoid touching the .tscn
	var textures = [
		preload("res://assets/textures/guns/Ak-47.png"),
		preload("res://assets/textures/guns/M4A4-S.png"),
		preload("res://assets/textures/guns/G18.png"),
		preload("res://assets/textures/guns/Deagle.png"),
		preload("res://assets/textures/guns/Sawed-off.png")
	]
	
	var boxes = [
		$ColorRect/CenterContainer/VBoxContainer/PrimaryBox/AKBox,
		$ColorRect/CenterContainer/VBoxContainer/PrimaryBox/M4A4Box,
		$ColorRect/CenterContainer/VBoxContainer/SecondaryBox/PistolBox,
		$ColorRect/CenterContainer/VBoxContainer/SecondaryBox/DeagleBox,
		$ColorRect/CenterContainer/VBoxContainer/SecondaryBox/ShotgunBox
	]
	
	for i in range(boxes.size()):
		var tr = TextureRect.new()
		tr.texture = textures[i]
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(0, 100)
		
		boxes[i].add_child(tr)
		boxes[i].move_child(tr, 1)

func _on_visibility_changed() -> void:
	if _get_device_id() < 0:
		if visible:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _process(_delta: float) -> void:
	if not visible:
		return

	var device_id = _get_device_id()
	if device_id < 0:
		return  # Keyboard player uses mouse clicks

	# Controller navigation with left joystick
	var joy_x = Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
	var joy_y = Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)

	var go_right = joy_x > 0.5 and not _prev_joy_right
	var go_left = joy_x < -0.5 and not _prev_joy_left
	var go_down = joy_y > 0.5 and not _prev_joy_down
	var go_up = joy_y < -0.5 and not _prev_joy_up

	_prev_joy_right = joy_x > 0.5
	_prev_joy_left = joy_x < -0.5
	_prev_joy_down = joy_y > 0.5
	_prev_joy_up = joy_y < -0.5

	if go_right or go_down:
		_focus_index = (_focus_index + 1) % _equip_buttons.size()
		_highlight_focused()
	elif go_left or go_up:
		_focus_index = (_focus_index - 1 + _equip_buttons.size()) % _equip_buttons.size()
		_highlight_focused()

	# A button to select
	var cur_a = Input.is_joy_button_pressed(device_id, JOY_BUTTON_A)
	if cur_a and not _prev_a:
		_equip_buttons[_focus_index].emit_signal("pressed")
	_prev_a = cur_a

func _highlight_focused() -> void:
	for i in _equip_buttons.size():
		if i == _focus_index:
			_equip_buttons[i].add_theme_color_override("font_color", Color.YELLOW)
			_equip_buttons[i].add_theme_color_override("font_hover_color", Color.YELLOW)
			_equip_buttons[i].grab_focus()
		else:
			_equip_buttons[i].remove_theme_color_override("font_color")
			_equip_buttons[i].remove_theme_color_override("font_hover_color")

func _on_equip_pressed(idx: int) -> void:
	emit_signal("weapon_equipped", idx)
	visible = false
