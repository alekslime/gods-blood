extends Node

# --- STATS ---
var kills: int = 0
var time_elapsed: float = 0.0
var is_timing: bool = false
var total_enemies: int = 0
var health_drop_toggle: bool = false

# --- SIGNALS ---
signal all_enemies_dead


func _process(delta: float) -> void:
	if is_timing:
		time_elapsed += delta


func start_level(enemy_count: int) -> void:
	kills = 0
	time_elapsed = 0.0
	is_timing = true
	total_enemies = enemy_count


func register_kill() -> void:
	kills += 1
	print("Kills: ", kills, "/", total_enemies)
	if kills >= total_enemies:
		is_timing = false
		emit_signal("all_enemies_dead")


func get_time_string() -> String:
	var minutes = int(time_elapsed) / 60
	var seconds = int(time_elapsed) % 60
	return "%02d:%02d" % [minutes, seconds]


func get_rank() -> String:
	var time = time_elapsed
	if time < 30.0:
		return "S"
	elif time < 60.0:
		return "A"
	elif time < 120.0:
		return "B"
	else:
		return "C"
