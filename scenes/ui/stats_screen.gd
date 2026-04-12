extends CanvasLayer

@onready var kills_label: Label = $Control/KillsLabel
@onready var time_label: Label = $Control/TimeLabel
@onready var rank_label: Label = $Control/RankLabel


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	kills_label.text = "SOULS CLAIMED: " + str(GameManager.kills)
	time_label.text = "TIME: " + GameManager.get_time_string()
	rank_label.text = "RANK: " + GameManager.get_rank()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		get_tree().change_scene_to_file("res://scenes/ui/StatsScreen.tscn")
