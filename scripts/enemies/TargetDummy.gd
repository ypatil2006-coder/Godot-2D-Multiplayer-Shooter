extends StaticBody2D

func _ready() -> void:
	add_to_group("enemies")
	$DamageZone.body_entered.connect(_on_damage_zone_body_entered)

func _on_damage_zone_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(20)

func take_damage(amount: int = 0) -> void:
	$ColorRect.color = Color.WHITE
	
	var dmg_num = preload("res://scenes/ui/DamageNumber.tscn").instantiate()
	get_tree().current_scene.add_child(dmg_num)
	dmg_num.global_position = global_position + Vector2(0, -40)
	dmg_num.setup(amount, amount > 30)
	
	await get_tree().create_timer(0.1).timeout
	$ColorRect.color = Color(0.54, 0, 0, 1) # Dark Red
