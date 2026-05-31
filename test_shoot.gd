extends SceneTree

func _init():
	var root = get_root()
	var scene = preload("res://scenes/maps/SplitScreenMap.tscn").instantiate()
	root.add_child(scene)
	
	# Wait a couple frames
	await get_tree().create_timer(1.0).timeout
	
	var p1 = root.find_child("Player1", true, false)
	if p1:
		var shoot = p1.get_node("PlayerShoot")
		shoot.rpc_fire(Vector2(0,0), Vector2(1,0), 20, 1000, 2000, 9999)
	
	await get_tree().create_timer(0.5).timeout
	quit()
