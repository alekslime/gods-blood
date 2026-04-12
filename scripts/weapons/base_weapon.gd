extends Node3D
class_name BaseWeapon

@export var weapon_name: String = "Weapon"
@export var damage: float = 10.0
@export var fire_rate: float = 0.2
@export var ammo_current: int = 30
@export var ammo_max: int = 30
@export var is_infinite_ammo: bool = false

var can_fire: bool = true
var is_ads: bool = false
var ads_default_position: Vector3 = Vector3.ZERO
@export var ads_position: Vector3 = Vector3(0.0, -0.05, -0.1)
const ADS_SPEED := 12.0

@onready var fire_timer: Timer = $FireTimer

# --- HITSTOP ---
const HITSTOP_DURATION := 0.04   # seconds — 2-3 frames at 60fps
const HITSTOP_KILL_DURATION := 0.07  # slightly longer on kill
var hitstop_timer := 0.0
var is_hitstopping := false


# --- WEAPON SWAY ---
const SWAY_AMOUNT := 0.004       # how far it moves per mouse unit
const SWAY_MAX := 0.06           # clamp so it doesn't go crazy
const SWAY_RETURN_SPEED := 6.0   # how fast it returns to center
const SWAY_ROTATION_AMOUNT := 0.0015  # subtle rotation on top of position sway
var sway_offset := Vector3.ZERO
var mouse_delta := Vector2.ZERO  # captured from _input each frame


func _ready() -> void:
	await get_tree().process_frame
	fire_timer.wait_time = fire_rate
	fire_timer.one_shot = true
	if not fire_timer.timeout.is_connected(_on_fire_timer_timeout):
		fire_timer.timeout.connect(_on_fire_timer_timeout)
	ads_default_position = position


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_delta = event.relative


func _process(delta: float) -> void:
	if is_hitstopping:
		hitstop_timer -= delta
		if hitstop_timer <= 0.0:
			is_hitstopping = false
			Engine.time_scale = 1.0
	_handle_ads(delta)
	_handle_sway(delta)
	mouse_delta = Vector2.ZERO  # reset after consuming


func _handle_sway(delta: float) -> void:
	if is_ads:
		# Reduce sway while aiming
		sway_offset = sway_offset.lerp(Vector3.ZERO, SWAY_RETURN_SPEED * 2.0 * delta)
		rotation.x = lerp(rotation.x, 0.0, SWAY_RETURN_SPEED * delta)
		rotation.y = lerp(rotation.y, 0.0, SWAY_RETURN_SPEED * delta)
		return

	# Target sway from mouse movement
	var target_x = clamp(-mouse_delta.y * SWAY_AMOUNT, -SWAY_MAX, SWAY_MAX)
	var target_y = clamp(-mouse_delta.x * SWAY_AMOUNT, -SWAY_MAX, SWAY_MAX)
	sway_offset.x = lerp(sway_offset.x, target_x, SWAY_RETURN_SPEED * delta)
	sway_offset.y = lerp(sway_offset.y, target_y, SWAY_RETURN_SPEED * delta)

	# Apply as rotation for a more natural feel
	rotation.x = lerp(rotation.x, -mouse_delta.y * SWAY_ROTATION_AMOUNT, SWAY_RETURN_SPEED * delta)
	rotation.y = lerp(rotation.y, -mouse_delta.x * SWAY_ROTATION_AMOUNT, SWAY_RETURN_SPEED * delta)


func _handle_ads(delta: float) -> void:
	var target_pos = ads_position if is_ads else ads_default_position
	position = position.lerp(target_pos, ADS_SPEED * delta)


func start_ads() -> void:
	is_ads = true


func stop_ads() -> void:
	is_ads = false


func _on_fire_timer_timeout() -> void:
	can_fire = true


func equip() -> void:
	show()


func unequip() -> void:
	hide()


func try_fire() -> void:
	if not can_fire:
		return
	if ammo_current <= 0 and not is_infinite_ammo:
		on_empty()
		return
	can_fire = false
	fire_timer.start(fire_rate)
	if not is_infinite_ammo:
		ammo_current -= 1
	fire()


func fire() -> void:
	pass


func on_empty() -> void:
	pass


func spawn_tracer(from: Vector3, to: Vector3, color: Color, thickness: float = 0.1, duration: float = 0.5) -> void:
	var tracer = MeshInstance3D.new()
	get_tree().current_scene.add_child(tracer)

	var length = from.distance_to(to)
	if length < 0.1:
		tracer.queue_free()
		return

	var box = BoxMesh.new()
	box.size = Vector3(thickness, thickness, length)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 1.0)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 14.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	box.surface_set_material(0, mat)
	tracer.mesh = box
	tracer.global_position = (from + to) / 2.0

	var dir = (to - from).normalized()
	var up = Vector3.UP if abs(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var right = dir.cross(up).normalized()
	var new_up = right.cross(dir).normalized()
	tracer.global_transform.basis = Basis(right, new_up, -dir)

	var hold := duration * 0.4
	var fade := duration * 0.6
	await get_tree().create_timer(hold).timeout
	var tween = get_tree().create_tween()
	tween.tween_method(func(a: float):
		mat.albedo_color.a = a
		mat.emission_energy_multiplier = a * 14.0
	, 1.0, 0.0, fade)
	await get_tree().create_timer(fade + 0.05).timeout
	if is_instance_valid(tracer):
		tracer.queue_free()


func deal_damage(target: Node) -> void:
	if not target.has_method("take_damage"):
		return

	var player = get_tree().get_first_node_in_group("player")
	var multiplier = 1.0

	if player and player.is_raging:
		multiplier = player.RAGE_DAMAGE_MULTIPLIER

	if player and player.get("fire_revenge_active") == true:
		multiplier *= player.FIRE_REVENGE_MULTIPLIER
		player.fire_revenge_active = false
		player.fire_revenge_timer = 0.0
		if player.has_method("shake"):
			player.shake(0.14)
		if player.hud:
			player.hud.flash_fire_regen()

	var was_alive = target.get("current_health") > 0.0
	target.take_damage(damage * multiplier)
	var is_dead_now = target.get("is_dead") == true or target.get("current_health") <= 0.0

	# --- HITSTOP ---
	var killed = was_alive and is_dead_now
	_trigger_hitstop(killed)

	# --- HITMARKER ---
	if player:
		var crosshair = _get_crosshair(player)
		if crosshair:
			if killed:
				crosshair.on_kill()
			else:
				crosshair.on_hit()

	if player and player.has_method("add_rage") and not player.is_raging:
		player.add_rage(0.8)


func _trigger_hitstop(killed: bool) -> void:
	is_hitstopping = true
	hitstop_timer = HITSTOP_KILL_DURATION if killed else HITSTOP_DURATION
	# Freeze time briefly — brutal, satisfying
	Engine.time_scale = 0.05


func _get_crosshair(player: Node) -> Node:
	# Walk up to HUD and find crosshair
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		for child in hud.get_children():
			if child.has_method("on_hit"):
				return child
	# Fallback — search directly on player's camera subtree
	var crosshair = player.get_node_or_null("Head/Camera3D/Crosshair")
	if crosshair == null:
		crosshair = player.get_node_or_null("Head/Crosshair")
	return crosshair
