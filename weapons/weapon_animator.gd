# weapon_animator.gd
# Attach this to each weapon's root node.
# It handles all procedural animations via Tween:
#   - Idle sway
#   - Fire kick (unique per weapon)
#   - Reload (unique per weapon)
#   - ADS in/out
#   - Equip/unequip
# Call the public methods from your weapon script.

extends Node

@export var weapon_mesh: Node3D   # assign the MeshInstance3D (the gun model) in inspector

# ── Base positions ─────────────────────────────────────────────────────────────
var origin_pos: Vector3 = Vector3.ZERO
var origin_rot: Vector3 = Vector3.ZERO
var ads_pos: Vector3 = Vector3.ZERO      # set per weapon in _ready()
var ads_rot: Vector3 = Vector3.ZERO

# ── Idle sway ──────────────────────────────────────────────────────────────────
var sway_timer: float = 0.0
const SWAY_SPEED: float = 1.4
const SWAY_AMOUNT_POS: float = 0.004
const SWAY_AMOUNT_ROT: float = 0.006

# ── State ──────────────────────────────────────────────────────────────────────
var is_reloading: bool = false
var is_ads: bool = false
var current_tween: Tween = null

func _ready() -> void:
	if weapon_mesh:
		origin_pos = weapon_mesh.position
		origin_rot = weapon_mesh.rotation

func _process(delta: float) -> void:
	if not weapon_mesh:
		return
	if not is_reloading and not is_ads:
		_handle_idle_sway(delta)

# ── Idle sway — subtle breathing life into the weapon ─────────────────────────
func _handle_idle_sway(delta: float) -> void:
	sway_timer += delta
	var sway_x = sin(sway_timer * SWAY_SPEED) * SWAY_AMOUNT_POS
	var sway_y = sin(sway_timer * SWAY_SPEED * 0.5) * SWAY_AMOUNT_POS * 0.5
	var rot_z = sin(sway_timer * SWAY_SPEED * 0.7) * SWAY_AMOUNT_ROT
	weapon_mesh.position = weapon_mesh.position.lerp(
		origin_pos + Vector3(sway_x, sway_y, 0.0), delta * 6.0
	)
	weapon_mesh.rotation.z = lerp(weapon_mesh.rotation.z, origin_rot.z + rot_z, delta * 6.0)

# ── Kill any running tween cleanly ────────────────────────────────────────────
func _kill_tween() -> void:
	if current_tween and current_tween.is_valid():
		current_tween.kill()

# ── REMNANT animations ─────────────────────────────────────────────────────────
func remnant_fire() -> void:
	_kill_tween()
	current_tween = get_tree().create_tween()
	current_tween.set_parallel(false)
	# Sharp kick back and up
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos + Vector3(0.0, 0.018, 0.06), 0.04).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(-7.0), deg_to_rad(1.5), 0.0), 0.04).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# Slow deliberate return — revolver weight
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func remnant_reload() -> void:
	_kill_tween()
	is_reloading = true
	current_tween = get_tree().create_tween()
	current_tween.set_parallel(false)
	# Drop down and tilt — opening the cylinder
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos + Vector3(0.04, -0.06, 0.0), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(25.0), deg_to_rad(-15.0), deg_to_rad(30.0)), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	# Hold — loading rounds one by one feel
	current_tween.tween_interval(0.9)
	# Snap back up — cylinder closes
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos + Vector3(0.0, 0.01, 0.0), 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(-3.0), 0.0, 0.0), 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# Settle
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

# ── ASHEN REPEATER animations ──────────────────────────────────────────────────
func ashen_fire() -> void:
	_kill_tween()
	current_tween = get_tree().create_tween()
	current_tween.set_parallel(false)
	# Fast light kick — rapid fire feel
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos + Vector3(randf_range(-0.003, 0.003), 0.008, 0.025), 0.02).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(-3.5), deg_to_rad(randf_range(-0.8, 0.8)), 0.0), 0.02).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# Quick return
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos, 0.07).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot, 0.07).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func ashen_reload() -> void:
	_kill_tween()
	is_reloading = true
	current_tween = get_tree().create_tween()
	current_tween.set_parallel(false)
	# Tilt hard left — mag drop
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos + Vector3(-0.05, -0.04, 0.0), 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(15.0), deg_to_rad(20.0), deg_to_rad(-25.0)), 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	# Hold — new mag going in
	current_tween.tween_interval(0.6)
	# Slam back — mag seated, charging handle
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos + Vector3(0.0, 0.012, 0.04), 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(-5.0), 0.0, 0.0), 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# Settle
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

# ── THE GRIEF animations ───────────────────────────────────────────────────────
func grief_fire() -> void:
	_kill_tween()
	current_tween = get_tree().create_tween()
	current_tween.set_parallel(false)
	# Violent slam back — shotgun brutality
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos + Vector3(0.0, 0.03, 0.12), 0.05).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(-12.0), deg_to_rad(2.0), 0.0), 0.05).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# Pump forward — chambering next round
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos + Vector3(0.0, -0.01, -0.04), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(4.0), 0.0, 0.0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	# Settle into ready position
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func grief_reload() -> void:
	_kill_tween()
	is_reloading = true
	current_tween = get_tree().create_tween()
	current_tween.set_parallel(false)
	# Tilt down and right — loading shells one by one
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos + Vector3(0.03, -0.05, 0.0), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(30.0), deg_to_rad(-10.0), deg_to_rad(20.0)), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	# Long hold — feeding shells
	current_tween.tween_interval(1.4)
	# Pump snap
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos + Vector3(0.0, 0.014, 0.05), 0.07).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(-6.0), 0.0, 0.0), 0.07).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# Settle
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

# ── HOLLOW ROUND animations ────────────────────────────────────────────────────
func hollow_fire() -> void:
	_kill_tween()
	current_tween = get_tree().create_tween()
	current_tween.set_parallel(false)
	# Heavy thud back — launching something massive
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos + Vector3(0.0, 0.025, 0.1), 0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(-10.0), deg_to_rad(3.0), 0.0), 0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# Break open — barrel tilts down for reload
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(35.0), deg_to_rad(3.0), 0.0), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	# Hold — new round going in
	current_tween.tween_interval(0.5)
	# Snap closed
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(-4.0), 0.0, 0.0), 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# Settle
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func hollow_reload() -> void:
	_kill_tween()
	is_reloading = true
	current_tween = get_tree().create_tween()
	current_tween.set_parallel(false)
	# Tilt barrel way down — breaking it open
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos + Vector3(0.0, -0.03, 0.0), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(40.0), deg_to_rad(-8.0), 0.0), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	# Long hold — loading
	current_tween.tween_interval(1.2)
	# Violent snap closed
	current_tween.tween_property(weapon_mesh, "rotation",
		origin_rot + Vector3(deg_to_rad(-5.0), 0.0, 0.0), 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(weapon_mesh, "position",
		origin_pos + Vector3(0.0, 0.01, 0.0), 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# Settle
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
