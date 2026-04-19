# weapon_animator.gd
# Procedural weapon animation system — no external animation files needed.
# Handles: idle sway, mouse-look sway, sprint bob, landing impact,
#          damage tilt, empty clip droop, fire kick, reload, equip.

extends Node

@export var weapon_mesh: Node3D

# ── Base transform ─────────────────────────────────────────────────────────────
var origin_pos: Vector3 = Vector3.ZERO
var origin_rot: Vector3 = Vector3.ZERO

# ── Mouse-look sway ────────────────────────────────────────────────────────────
var mouse_delta: Vector2 = Vector2.ZERO
var sway_pos: Vector3 = Vector3.ZERO
var sway_rot: Vector3 = Vector3.ZERO
const SWAY_POS_AMOUNT: float = 0.006
const SWAY_ROT_AMOUNT: float = 0.018
const SWAY_SMOOTH: float = 8.0

# ── Idle breathing sway ────────────────────────────────────────────────────────
var idle_timer: float = 0.0
const IDLE_SPEED: float = 1.3
const IDLE_POS_AMOUNT: float = 0.003
const IDLE_ROT_AMOUNT: float = 0.005

# ── Sprint bob ─────────────────────────────────────────────────────────────────
var bob_timer: float = 0.0
var bob_pos: Vector3 = Vector3.ZERO
const BOB_SPEED: float = 14.0
const BOB_AMOUNT_X: float = 0.006
const BOB_AMOUNT_Y: float = 0.01
const BOB_TILT: float = 0.012

# ── Landing impact ─────────────────────────────────────────────────────────────
var land_impact: float = 0.0
var land_timer: float = 0.0
const LAND_DURATION: float = 0.35
const LAND_AMOUNT: float = 0.055

# ── Damage tilt ────────────────────────────────────────────────────────────────
var damage_tilt: Vector3 = Vector3.ZERO
var damage_tilt_target: Vector3 = Vector3.ZERO
const DAMAGE_TILT_SPEED: float = 12.0

# ── Empty clip droop ───────────────────────────────────────────────────────────
var is_empty: bool = false
var empty_droop: float = 0.0
const EMPTY_DROOP_AMOUNT: float = 0.045
const EMPTY_DROOP_ROT: float = 0.08

# ── State ──────────────────────────────────────────────────────────────────────
var is_reloading: bool = false
var is_sprinting: bool = false
var current_tween: Tween = null

# ── Player reference ───────────────────────────────────────────────────────────
var player = null

func _ready() -> void:
	if weapon_mesh:
		origin_pos = weapon_mesh.position
		origin_rot = weapon_mesh.rotation
	player = get_tree().get_first_node_in_group("player")

func _input(event: InputEvent) -> void:
	# Capture raw mouse delta for look sway
	if event is InputEventMouseMotion:
		mouse_delta = event.relative

func _process(delta: float) -> void:
	if not weapon_mesh:
		return

	is_sprinting = Input.is_action_pressed("sprint")

	_handle_mouse_sway(delta)
	_handle_idle_sway(delta)
	_handle_sprint_bob(delta)
	_handle_landing(delta)
	_handle_damage_tilt(delta)
	_handle_empty_droop(delta)
	_apply_all(delta)

	# Decay mouse delta — prevents drift
	mouse_delta = mouse_delta.lerp(Vector2.ZERO, delta * 20.0)

# ── Mouse-look sway — gun lags behind your look direction ─────────────────────
func _handle_mouse_sway(delta: float) -> void:
	var target_sway_pos = Vector3(
		clamp(-mouse_delta.x * SWAY_POS_AMOUNT, -0.06, 0.06),
		clamp(-mouse_delta.y * SWAY_POS_AMOUNT * 0.6, -0.04, 0.04),
		0.0
	)
	var target_sway_rot = Vector3(
		clamp(mouse_delta.y * SWAY_ROT_AMOUNT, -0.12, 0.12),
		clamp(-mouse_delta.x * SWAY_ROT_AMOUNT, -0.12, 0.12),
		clamp(-mouse_delta.x * SWAY_ROT_AMOUNT * 0.5, -0.06, 0.06)
	)
	sway_pos = sway_pos.lerp(target_sway_pos, delta * SWAY_SMOOTH)
	sway_rot = sway_rot.lerp(target_sway_rot, delta * SWAY_SMOOTH)

# ── Idle breathing — subtle constant life ─────────────────────────────────────
func _handle_idle_sway(delta: float) -> void:
	if is_reloading or is_sprinting:
		return
	idle_timer += delta
	# Lissajous pattern — not a perfect loop, feels more organic
	var idle_x = sin(idle_timer * IDLE_SPEED) * IDLE_POS_AMOUNT
	var idle_y = sin(idle_timer * IDLE_SPEED * 0.617) * IDLE_POS_AMOUNT * 0.6
	var idle_rot_z = sin(idle_timer * IDLE_SPEED * 0.8) * IDLE_ROT_AMOUNT

# ── Sprint bob — gun pumps with movement ──────────────────────────────────────
func _handle_sprint_bob(delta: float) -> void:
	if not player:
		return
	var on_floor = player.is_on_floor() if player.has_method("is_on_floor") else true
	var speed = Vector3(player.velocity.x, 0, player.velocity.z).length() if player.get("velocity") else 0.0

	if on_floor and speed > 2.0:
		bob_timer += delta * BOB_SPEED
		var bob_x = sin(bob_timer) * BOB_AMOUNT_X * (1.5 if is_sprinting else 0.6)
		var bob_y = abs(sin(bob_timer * 0.5)) * BOB_AMOUNT_Y * (1.5 if is_sprinting else 0.6)
		var bob_tilt = sin(bob_timer) * BOB_TILT * (1.2 if is_sprinting else 0.5)
		bob_pos = bob_pos.lerp(Vector3(bob_x, -bob_y, 0.0), delta * 10.0)
		weapon_mesh.rotation.z = lerp(weapon_mesh.rotation.z, origin_rot.z + bob_tilt, delta * 8.0)
	else:
		bob_pos = bob_pos.lerp(Vector3.ZERO, delta * 8.0)

# ── Landing impact ─────────────────────────────────────────────────────────────
func trigger_land(intensity: float = 1.0) -> void:
	land_impact = LAND_AMOUNT * intensity
	land_timer = LAND_DURATION

func _handle_landing(delta: float) -> void:
	if land_timer > 0.0:
		land_timer -= delta
		var t = 1.0 - (land_timer / LAND_DURATION)
		land_impact = sin(t * PI) * LAND_AMOUNT
	else:
		land_impact = move_toward(land_impact, 0.0, delta * 0.08)

# ── Damage tilt — gun kicks sideways on hit ────────────────────────────────────
func trigger_damage() -> void:
	var side = randf_range(-1.0, 1.0)
	damage_tilt_target = Vector3(
		deg_to_rad(randf_range(3.0, 6.0)),
		0.0,
		deg_to_rad(side * randf_range(8.0, 14.0))
	)

func _handle_damage_tilt(delta: float) -> void:
	damage_tilt = damage_tilt.lerp(damage_tilt_target, delta * DAMAGE_TILT_SPEED)
	damage_tilt_target = damage_tilt_target.lerp(Vector3.ZERO, delta * (DAMAGE_TILT_SPEED * 0.7))

# ── Empty clip droop ───────────────────────────────────────────────────────────
func set_empty(empty: bool) -> void:
	is_empty = empty

func _handle_empty_droop(delta: float) -> void:
	var target = 1.0 if (is_empty and not is_reloading) else 0.0
	empty_droop = lerp(empty_droop, target, delta * 5.0)

# ── Apply everything together ──────────────────────────────────────────────────
func _apply_all(delta: float) -> void:
	if is_reloading:
		return  # tween controls position during reload

	var idle_x = sin(idle_timer * IDLE_SPEED) * IDLE_POS_AMOUNT
	var idle_y = sin(idle_timer * IDLE_SPEED * 0.617) * IDLE_POS_AMOUNT * 0.6
	var idle_rot_z = sin(idle_timer * IDLE_SPEED * 0.8) * IDLE_ROT_AMOUNT

	var target_pos = origin_pos \
		+ sway_pos \
		+ bob_pos \
		+ Vector3(idle_x, idle_y, 0.0) \
		+ Vector3(0.0, -land_impact, 0.0) \
		+ Vector3(0.0, -empty_droop * EMPTY_DROOP_AMOUNT, 0.0)

	var target_rot = origin_rot \
		+ sway_rot \
		+ damage_tilt \
		+ Vector3(0.0, 0.0, idle_rot_z) \
		+ Vector3(empty_droop * EMPTY_DROOP_ROT, 0.0, 0.0)

	weapon_mesh.position = weapon_mesh.position.lerp(target_pos, delta * 16.0)
	weapon_mesh.rotation.x = lerp(weapon_mesh.rotation.x, target_rot.x, delta * 16.0)
	weapon_mesh.rotation.y = lerp(weapon_mesh.rotation.y, target_rot.y, delta * 16.0)

# ── Tween helpers ──────────────────────────────────────────────────────────────
func _kill_tween() -> void:
	if current_tween and current_tween.is_valid():
		current_tween.kill()

# ── REMNANT ────────────────────────────────────────────────────────────────────
func remnant_fire() -> void:
	_kill_tween()
	current_tween = get_tree().create_tween()
	current_tween.set_parallel(false)
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos + Vector3(0.0, 0.018, 0.06), 0.04).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(-7.0), deg_to_rad(1.5), 0.0), 0.04).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func remnant_reload() -> void:
	_kill_tween()
	is_reloading = true
	current_tween = get_tree().create_tween()
	current_tween.set_parallel(false)
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos + Vector3(0.04, -0.06, 0.0), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(25.0), deg_to_rad(-15.0), deg_to_rad(30.0)), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	current_tween.tween_interval(0.9)
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos + Vector3(0.0, 0.01, 0.0), 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(-3.0), 0.0, 0.0), 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	current_tween.tween_callback(func(): is_reloading = false)

func remnant_equip() -> void:
	_kill_tween()
	weapon_mesh.position = origin_pos + Vector3(0.0, -0.15, 0.0)
	weapon_mesh.rotation = origin_rot + Vector3(deg_to_rad(20.0), 0.0, 0.0)
	current_tween = get_tree().create_tween()
	current_tween.set_parallel(true)
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# ── ASHEN REPEATER ─────────────────────────────────────────────────────────────
func ashen_fire() -> void:
	_kill_tween()
	current_tween = get_tree().create_tween()
	current_tween.set_parallel(false)
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos + Vector3(randf_range(-0.003, 0.003), 0.008, 0.025), 0.02).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(-3.5), deg_to_rad(randf_range(-0.8, 0.8)), 0.0), 0.02).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos, 0.07).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot, 0.07).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func ashen_reload() -> void:
	_kill_tween()
	is_reloading = true
	current_tween = get_tree().create_tween()
	current_tween.set_parallel(false)
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos + Vector3(-0.05, -0.04, 0.0), 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(15.0), deg_to_rad(20.0), deg_to_rad(-25.0)), 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	current_tween.tween_interval(0.6)
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos + Vector3(0.0, 0.012, 0.04), 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(-5.0), 0.0, 0.0), 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	current_tween.tween_callback(func(): is_reloading = false)

func ashen_equip() -> void:
	_kill_tween()
	weapon_mesh.position = origin_pos + Vector3(0.06, -0.12, 0.0)
	weapon_mesh.rotation = origin_rot + Vector3(0.0, deg_to_rad(-20.0), 0.0)
	current_tween = get_tree().create_tween()
	current_tween.set_parallel(true)
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# ── THE GRIEF ──────────────────────────────────────────────────────────────────
func grief_fire() -> void:
	_kill_tween()
	current_tween = get_tree().create_tween()
	current_tween.set_parallel(false)
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos + Vector3(0.0, 0.03, 0.12), 0.05).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(-12.0), deg_to_rad(2.0), 0.0), 0.05).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos + Vector3(0.0, -0.01, -0.04), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(4.0), 0.0, 0.0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func grief_reload() -> void:
	_kill_tween()
	is_reloading = true
	current_tween = get_tree().create_tween()
	current_tween.set_parallel(false)
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos + Vector3(0.03, -0.05, 0.0), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(30.0), deg_to_rad(-10.0), deg_to_rad(20.0)), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	current_tween.tween_interval(1.4)
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos + Vector3(0.0, 0.014, 0.05), 0.07).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(-6.0), 0.0, 0.0), 0.07).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	current_tween.tween_callback(func(): is_reloading = false)

func grief_equip() -> void:
	_kill_tween()
	weapon_mesh.position = origin_pos + Vector3(0.0, -0.2, 0.0)
	weapon_mesh.rotation = origin_rot + Vector3(deg_to_rad(30.0), 0.0, 0.0)
	current_tween = get_tree().create_tween()
	current_tween.set_parallel(true)
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# ── HOLLOW ROUND ───────────────────────────────────────────────────────────────
func hollow_fire() -> void:
	_kill_tween()
	current_tween = get_tree().create_tween()
	current_tween.set_parallel(false)
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos + Vector3(0.0, 0.025, 0.1), 0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(-10.0), deg_to_rad(3.0), 0.0), 0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(35.0), deg_to_rad(3.0), 0.0), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	current_tween.tween_interval(0.5)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(-4.0), 0.0, 0.0), 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func hollow_reload() -> void:
	_kill_tween()
	is_reloading = true
	current_tween = get_tree().create_tween()
	current_tween.set_parallel(false)
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos + Vector3(0.0, -0.03, 0.0), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(40.0), deg_to_rad(-8.0), 0.0), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	current_tween.tween_interval(1.2)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(-5.0), 0.0, 0.0), 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos + Vector3(0.0, 0.01, 0.0), 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	current_tween.tween_callback(func(): is_reloading = false)

func hollow_equip() -> void:
	_kill_tween()
	weapon_mesh.position = origin_pos + Vector3(0.0, -0.18, 0.0)
	weapon_mesh.rotation = origin_rot + Vector3(deg_to_rad(25.0), deg_to_rad(10.0), 0.0)
	current_tween = get_tree().create_tween()
	current_tween.set_parallel(true)
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
