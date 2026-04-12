extends Area3D

var loading := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	print("EndZone ready")


func _on_body_entered(body: Node) -> void:
	print("EndZone detected: ", body.name)
	if body.is_in_group("player") and GameManager.kills >= GameManager.total_enemies:
		_show_stats_screen()

func _show_stats_screen() -> void:
	GameManager.is_timing = false
	call_deferred("_load_stats")

func _load_stats() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/StatsScreen.tscn")
