extends Control

# --- SETTINGS ---
const LINE_LENGTH := 10.0
const LINE_THICKNESS := 2.0
const GAP := 5.0
const COLOR_DEFAULT := Color(1.0, 1.0, 1.0, 0.85)
const COLOR_ENEMY := Color(1.0, 0.27, 0.0, 0.95)  # ember orange on enemy
const COLOR_CRIT := Color(1.0, 1.0, 1.0, 1.0)

var spread := 0.0          # 0 = tight, 1 = fully spread
var on_enemy := false
var crit_flash := 0.0      # 0-1, decays quickly

@onready var player = get_tree().current_scene.get_node_or_null("Player")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	size = Vector2(80, 80)
	position -= size / 2.0
	mouse_filter = MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	var target_spread := 0.0
	if player:
		var vel = Vector3(player.velocity.x, 0, player.velocity.z)
		if vel.length() > 1.0:
			target_spread = 0.4
		if player.is_sliding:
			target_spread = 0.9
		if player.is_dashing:
			target_spread = 1.2
	spread = lerp(spread, target_spread, delta * 12.0)
	crit_flash = move_toward(crit_flash, 0.0, delta * 6.0)
	_check_enemy_aim()
	queue_redraw()

func _check_enemy_aim() -> void:
	if not player:
		return
	var camera = player.get_node_or_null("Head/Camera3D")
	if not camera:
		return
	var space = player.get_world_3d().direct_space_state
	var origin = camera.global_position
	var target = origin + (-camera.global_transform.basis.z * 50.0)
	var query = PhysicsRayQueryParameters3D.create(origin, target)
	query.exclude = [player.get_rid()]
	var result = space.intersect_ray(query)
	on_enemy = result.has("collider") and result["collider"].is_in_group("enemies")

func trigger_crit() -> void:
	crit_flash = 1.0

func trigger_shoot() -> void:
	var crosshair = get_tree().current_scene.get_node_or_null("HUD/HUDRoot/Crosshair")
	if crosshair and crosshair.has_method("trigger_shoot"):
		crosshair.trigger_shoot()
	spread = min(spread + 0.3, 1.5)

func _draw() -> void:
	var center := size / 2.0
	var current_gap = GAP + spread * 8.0
	var color := COLOR_ENEMY if on_enemy else COLOR_DEFAULT
	if crit_flash > 0.0:
		color = color.lerp(COLOR_CRIT, crit_flash)

	# Top
	draw_line(
		center + Vector2(0, -current_gap),
		center + Vector2(0, -current_gap - LINE_LENGTH),
		color, LINE_THICKNESS, true)
	# Bottom
	draw_line(
		center + Vector2(0, current_gap),
		center + Vector2(0, current_gap + LINE_LENGTH),
		color, LINE_THICKNESS, true)
	# Left
	draw_line(
		center + Vector2(-current_gap, 0),
		center + Vector2(-current_gap - LINE_LENGTH, 0),
		color, LINE_THICKNESS, true)
	# Right
	draw_line(
		center + Vector2(current_gap, 0),
		center + Vector2(current_gap + LINE_LENGTH, 0),
		color, LINE_THICKNESS, true)
