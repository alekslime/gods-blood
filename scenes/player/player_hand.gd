extends Node3D

# ================================================================
# PLAYER HAND
# Attach to a Node3D called "Hand" as a child of Camera3D
# Scene tree:
#   Camera3D
#   └── Hand  ← this script
#       └── MeshInstance3D  ← your hand mesh or placeholder box
# ================================================================

# --- POSITION ---
# Base resting position of the hand in camera space
const REST_POSITION := Vector3(0.18, -0.22, -0.35)
const REST_ROTATION := Vector3(0.0, 0.0, 0.0)

# --- BOB ---
const BOB_FREQ_WALK := 8.0
const BOB_FREQ_SPRINT := 12.0
const BOB_AMOUNT_X := 0.012    # side to side
const BOB_AMOUNT_Y := 0.018    # up and down
var bob_timer := 0.0

# --- SWAY ---
# Hand lags slightly behind camera rotation — feels weighty
const SWAY_AMOUNT := 0.04
const SWAY_SPEED := 8.0
var sway_offset := Vector3.ZERO
var last_mouse_delta := Vector2.ZERO

# --- LANDING BOB ---
const LAND_BOB_AMOUNT := 0.06
const LAND_BOB_SPEED := 12.0
var land_bob := 0.0
var land_bob_timer := 0.0
const LAND_BOB_DURATION := 0.22

# --- DASH / SLIDE KICK ---
const DASH_KICK_AMOUNT := 0.05
const DASH_KICK_SPEED := 14.0
var dash_kick := 0.0

# --- STATE ---
var player: CharacterBody3D = null
var was_on_floor := false
var weapon_holder: Node3D = null
var weapon_holder_rest: Vector3 = Vector3.ZERO


func _ready() -> void:
	position = REST_POSITION
	rotation = REST_ROTATION
	player = get_tree().get_first_node_in_group("player")
	# Grab WeaponHolder — it's a sibling of Hand under Camera3D
	weapon_holder = get_parent().get_node_or_null("WeaponHolder")
	if weapon_holder:
		weapon_holder_rest = weapon_holder.position


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		last_mouse_delta = event.relative


func _process(delta: float) -> void:
	if player == null:
		return

	var on_floor = player.is_on_floor()
	var vel = player.velocity
	var horizontal_speed = Vector3(vel.x, 0, vel.z).length()
	var is_sprinting = Input.is_action_pressed("sprint")
	var is_dashing = player.get("is_dashing") == true
	var is_sliding = player.get("is_sliding") == true

	# Landing bob
	if not was_on_floor and on_floor:
		land_bob_timer = LAND_BOB_DURATION
	was_on_floor = on_floor
	if land_bob_timer > 0.0:
		land_bob_timer -= delta
		var t = 1.0 - (land_bob_timer / LAND_BOB_DURATION)
		land_bob = sin(t * PI) * LAND_BOB_AMOUNT
	else:
		land_bob = move_toward(land_bob, 0.0, delta * 8.0)

	# Dash kick — hand jerks back then returns
	if is_dashing:
		dash_kick = move_toward(dash_kick, DASH_KICK_AMOUNT, delta * DASH_KICK_SPEED * 3.0)
	else:
		dash_kick = move_toward(dash_kick, 0.0, delta * DASH_KICK_SPEED)

	# Movement bob
	var bob_x := 0.0
	var bob_y := 0.0
	if on_floor and horizontal_speed > 1.0 and not is_sliding and not is_dashing:
		var freq = BOB_FREQ_SPRINT if is_sprinting else BOB_FREQ_WALK
		bob_timer += delta * freq
		bob_x = cos(bob_timer) * BOB_AMOUNT_X
		bob_y = abs(sin(bob_timer)) * BOB_AMOUNT_Y
	else:
		bob_timer = lerp(bob_timer, 0.0, delta * 6.0)
		bob_x = move_toward(bob_x, 0.0, delta * 4.0)
		bob_y = move_toward(bob_y, 0.0, delta * 4.0)

	# Mouse sway — hand lags behind look direction
	var target_sway_x = -last_mouse_delta.x * SWAY_AMOUNT * 0.01
	var target_sway_y = -last_mouse_delta.y * SWAY_AMOUNT * 0.01
	sway_offset.x = lerp(sway_offset.x, target_sway_x, delta * SWAY_SPEED)
	sway_offset.y = lerp(sway_offset.y, target_sway_y, delta * SWAY_SPEED)
	last_mouse_delta = Vector2.ZERO

	# Slide tilt — hand rolls inward
	var slide_tilt = -0.15 if is_sliding else 0.0

	# Compose final position
	var target_pos = REST_POSITION
	target_pos.x += bob_x + sway_offset.x
	target_pos.y += -bob_y - land_bob + sway_offset.y
	target_pos.z += dash_kick

	# Rage — hand trembles slightly
	if player.get("is_raging") == true:
		target_pos.x += randf_range(-0.002, 0.002)
		target_pos.y += randf_range(-0.002, 0.002)

	position = lerp(position, target_pos, delta * 20.0)
	rotation.z = lerp(rotation.z, slide_tilt, delta * 8.0)

	# Sync WeaponHolder so guns bob with the hand
	if weapon_holder:
		var wp = weapon_holder_rest
		wp.x += bob_x + sway_offset.x
		wp.y += -bob_y - land_bob + sway_offset.y
		wp.z += dash_kick
		weapon_holder.position = lerp(weapon_holder.position, wp, delta * 20.0)
		weapon_holder.rotation.z = lerp(weapon_holder.rotation.z, slide_tilt, delta * 8.0)
