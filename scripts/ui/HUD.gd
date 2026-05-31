extends CanvasLayer

@onready var ammo_label: Label = $MarginContainer/AmmoLabel
@onready var health_bar: ProgressBar = $HealthMargin/HealthBar

var current_weapon := "Pistol"

func _ready() -> void:
	$MarginContainer/AmmoLabel.text = ""
	
	if Engine.has_singleton("Network") or has_node("/root/Network"):
		Network.scores_updated.connect(_on_scores_updated)
		_on_scores_updated()

	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0.8, 0) # Green
	health_bar.add_theme_stylebox_override("fill", sb)

func _on_scores_updated() -> void:
	var text = "Leaderboard:\n"
	if has_node("/root/Network"):
		for id in Network.scores.keys():
			var stats = Network.scores[id]
			text += "Player %s - Kills: %d | Deaths: %d\n" % [id, stats["kills"], stats["deaths"]]
	$LeaderboardMargin/LeaderboardLabel.text = text

func _on_health_changed(current: int, max_health: int) -> void:
	health_bar.max_value = max_health
	health_bar.value = current

func _on_weapon_changed(weapon_name: String) -> void:
	current_weapon = weapon_name

func _on_ammo_changed(current: int, max_ammo: int) -> void:
	ammo_label.text = "[" + current_weapon + "] Ammo: " + str(current) + " / " + str(max_ammo)
	if current == 0:
		ammo_label.add_theme_color_override("font_color", Color.RED)
	else:
		ammo_label.add_theme_color_override("font_color", Color.YELLOW)

func _on_reload_started() -> void:
	ammo_label.text = "[" + current_weapon + "] RELOADING..."
	ammo_label.add_theme_color_override("font_color", Color.ORANGE)
