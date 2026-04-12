extends Node

@export var door: Node3D = null
const DOOR_OPEN_SPEED = 2.0

var door_open := false
var door_target_y := 0.0
var door_start_y := 0.0


func _ready() -> void:
	await get_tree().process_frame
	var enemies = get_tree().get_nodes_in_group("enemy")
	print("LevelManager found enemies: ", enemies.size())
	GameManager.start_level(enemies.size())
	GameManager.all_enemies_dead.connect(_on_all_enemies_dead)

	if door:
		print("Door found: ", door.name)
		door_start_y = door.global_position.y
		door_target_y = door_start_y + 6.0
	else:
		print("Door is NULL - not assigned in Inspector")


func _process(delta: float) -> void:
	if door_open and door:
		door.global_position.y = lerp(door.global_position.y, door_target_y, delta * DOOR_OPEN_SPEED)


func _on_all_enemies_dead() -> void:
	print("Signal received - opening door!")
	door_open = true
