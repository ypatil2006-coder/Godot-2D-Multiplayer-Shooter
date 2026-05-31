extends Node2D

var velocity := Vector2(0, -100)
var life_time := 1.0
var timer := 0.0

func _ready() -> void:
	# Add some random scatter so they don't perfectly stack
	velocity.x = randf_range(-40, 40)
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, life_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

func setup(amount: int, is_critical: bool = false) -> void:
	$Label.text = str(amount)
	if is_critical:
		$Label.modulate = Color(1, 0, 0)
		$Label.scale = Vector2(1.5, 1.5)
	else:
		$Label.modulate = Color(1, 0.8, 0)

func _process(delta: float) -> void:
	position += velocity * delta
	timer += delta
	if timer >= life_time:
		queue_free()
