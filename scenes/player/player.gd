extends CharacterBody3D

# --- NODES ---
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var hud = get_tree().current_scene.get_node_or_null("HUD")
@onready var footstep_sound: AudioStreamPlayer = $FootstepSound
@onready var rage_activate_sound: AudioStreamPlayer = $RageActivateSound
@onready var rage_breathing_sound: AudioStreamPlayer = $RageBreathingSound
@onready var hit_sound: AudioStreamPlayer = $HitSound
@onready var death_sound: AudioStreamPlayer = $DeathSound
@onready var dash_sound: AudioStreamPlayer = $DashSound
@onready var slide_sound: AudioStreamPlayer = $SlideSound



var weapon_manager = null
var footstep_timer := 0.0
var is_dead := false
var time_scale_target := 1.0
var target_pitch := 1.0
var current_audio_pitch := 1.0

# --- HEALTH ---
var max_health: float = 100.0
var current_health: float = 100.0

const FIRE_TRIGGER_THRESHOLD := 0.35
const FIRE_HEAL_TARGET := 0.60
const FIRE_COOLDOWN := 20.0
const FIRE_MAX_HP_COST := 5.0
const FIRE_HEAL_SPEED := 30.0
const FIRE_TIMESCALE_DURATION := 0.55
const FIRE_TIMESCALE_TARGET := 0.15
const FIRE_FOV_AMOUNT := 25.0
const FIRE_HUD_PULSE_DURATION := 1.2
const FIRE_MAX_TRIGGERS := 3
const FIRE_REVENGE_WINDOW := 0.55
const FIRE_REVENGE_MULTIPLIER := 3.0
var fire_triggers_remaining := 3

var fire_cooldown_timer := 0.0
var fire_is_healing := false
var fire_heal_target_hp := 0.0
var fire_timescale_timer := 0.0
var fire_fov_kick := 0.0
var fire_hud_pulse_timer := 0.0
var fire_revenge_active := false
var fire_revenge_timer := 0.0

# --- SPEED SETTINGS ---
const WALK_SPEED = 16.0
const SPRINT_SPEED = 16.0
const SLIDE_SPEED = 35.0
const DASH_SPEED = 36.0
const JUMP_VELOCITY = 10.5
const GRAVITY = 25.0

# --- ACCELERATION ---
const ACCEL_GROUND = 12.0
const ACCEL_AIR = 4.0
const FRICTION = 10.0
const AIR_FRICTION = 0.6

# --- BUNNYHOP ---
const BHOP_MULTIPLIER = 1.1
const MAX_BHOP_SPEED = 28.0

# --- SLIDE ---
const SLIDE_SPEED_MAX = 26.0
const SLIDE_SPEED_MIN = 8.0
const SLIDE_DECEL = 10.0        # how fast slide slows down while holding
const SLIDE_COOLDOWN = 0.4
var is_sliding := false
var slide_cooldown_timer := 0.0
var slide_direction := Vector3.ZERO
var current_slide_speed := 0.0

# --- DASH (3 charges) ---
const DASH_DURATION = 0.18
const DASH_RECHARGE_TIME = 2.5  # seconds per charge
const DASH_MAX_CHARGES = 3
var dash_charges := 3
var dash_recharge_timers := [0.0, 0.0, 0.0]  # one timer per charge slot
var is_dashing := false
var dash_timer := 0.0
var dash_direction := Vector3.ZERO

# --- MOUSE LOOK ---
var MOUSE_SENSITIVITY = 0.002
var pitch := 0.0

# --- CAMERA BOB ---
const BOB_FREQUENCY_WALK = 8.0
const BOB_FREQUENCY_SPRINT = 12.0
const BOB_AMPLITUDE_WALK = 0.04
const BOB_AMPLITUDE_SPRINT = 0.06
var bob_timer := 0.0
var default_camera_y := 0.0

# --- CAMERA TILT (slide only) ---
const TILT_SLIDE = -0.1
const TILT_SPEED = 8.0
var current_tilt := 0.0
var target_tilt := 0.0

# --- CAMERA FOV ---
const FOV_DEFAULT = 90.0
const FOV_SPRINT = 95.0
const FOV_DASH = 110.0
const FOV_SLIDE = 85.0
const FOV_SPEED = 8.0

const FOV_ADS_MULTIPLIER := 0.65   # matches ads_fov_multiplier in weapon
var is_ads := false

# --- STATE ---
var current_speed := WALK_SPEED
var bhop_speed := WALK_SPEED

# --- SCREEN SHAKE ---
const SHAKE_DECAY = 5.0
var shake_intensity := 0.0

# --- LANDING BOB ---
var was_in_air := false
var land_bob_timer := 0.0
const LAND_BOB_DURATION := 0.18
const LAND_BOB_AMOUNT := 0.08

# --- RAGE ---
const RAGE_PER_KILL = 25.0
const RAGE_PER_DAMAGE = 0.8
const RAGE_DURATION = 8.0
const RAGE_SPEED_MULTIPLIER = 1.4
const RAGE_DAMAGE_MULTIPLIER = 1.5
const RAGE_DECAY = 12.0

var rage := 0.0
var is_raging := false
var rage_timer := 0.0
var rage_vignette_alpha := 0.0


func _ready() -> void:
	weapon_manager = $Head/Camera3D/WeaponHolder
	if weapon_manager == null:
		push_error("WeaponHolder not found!")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	default_camera_y = camera.position.y


func _input(event: InputEvent) -> void:
	if is_dead and event.is_action_pressed("ui_accept"):
		_restart()
		return
	if is_dead:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		pitch = clamp(pitch - event.relative.y * MOUSE_SENSITIVITY, -1.4, 1.4)
		head.rotation.x = pitch
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _restart() -> void:
	set_physics_process(true)
	set_process_unhandled_input(true)
	is_dead = false
	current_health = max_health
	GameManager.kills = 0
	GameManager.time_elapsed = 0.0
	get_tree().reload_current_scene()


func _process(delta: float) -> void:
	Engine.time_scale = lerp(Engine.time_scale, time_scale_target, 0.05)
	current_audio_pitch = lerp(current_audio_pitch, time_scale_target, 0.08)
	footstep_sound.pitch_scale = current_audio_pitch
	rage_breathing_sound.pitch_scale = current_audio_pitch
	rage_activate_sound.pitch_scale = current_audio_pitch


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_handle_gravity(delta)
	_handle_dash(delta)
	_handle_slide(delta)
	_handle_movement(delta)
	_handle_jump()
	_handle_camera(delta)
	_handle_rage(delta)
	_handle_fire_regen(delta)
	_handle_footsteps(delta)
	_handle_dash_recharge(delta)
	_handle_ads_input()
	if weapon_manager:
		weapon_manager.handle_input(delta)
	move_and_slide()


func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta


func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		if is_sliding:
			is_sliding = false
			# NO cooldown on jump cancel — player can slide again immediately on landing
			if slide_sound and slide_sound.playing:
				slide_sound.stop()
		var horizontal = Vector3(velocity.x, 0, velocity.z)
		if horizontal.length() > WALK_SPEED:
			bhop_speed = min(horizontal.length() * BHOP_MULTIPLIER, MAX_BHOP_SPEED)
		else:
			bhop_speed = WALK_SPEED



func _handle_movement(delta: float) -> void:
	if is_dashing or is_sliding:
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if Input.is_action_pressed("sprint"):
		current_speed = SPRINT_SPEED
	else:
		current_speed = WALK_SPEED

	bhop_speed = move_toward(bhop_speed, current_speed, 12.0 * delta)
	var rage_boost = RAGE_SPEED_MULTIPLIER if is_raging else 1.0
	var effective_speed = max(current_speed, bhop_speed) * rage_boost

	var accel = ACCEL_GROUND if is_on_floor() else ACCEL_AIR
	var friction = FRICTION if is_on_floor() else AIR_FRICTION

	if direction:
		velocity.x = move_toward(velocity.x, direction.x * effective_speed, accel * effective_speed * delta)
		velocity.z = move_toward(velocity.z, direction.z * effective_speed, accel * effective_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * effective_speed * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * effective_speed * delta)


# --- SLIDE: hold to slide, release to stop ---
func _handle_slide(delta: float) -> void:
	if slide_cooldown_timer > 0.0:
		slide_cooldown_timer -= delta

	var slide_held = Input.is_action_pressed("slide")

	# Start slide
	if slide_held and is_on_floor() and not is_sliding and not is_dashing and slide_cooldown_timer <= 0.0:
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		slide_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if slide_direction == Vector3.ZERO:
			slide_direction = -transform.basis.z
		current_slide_speed = SLIDE_SPEED_MAX
		is_sliding = true
		if slide_sound:
			slide_sound.pitch_scale = randf_range(0.9, 1.0)
			slide_sound.play()

	# Stop slide when key released or left the floor
	if is_sliding and (not slide_held or not is_on_floor()):
		is_sliding = false
		slide_cooldown_timer = SLIDE_COOLDOWN   # cooldown only on natural end
		if slide_sound and slide_sound.playing:
			slide_sound.stop()
		return

	# While sliding
	if is_sliding:
		current_slide_speed = move_toward(current_slide_speed, SLIDE_SPEED_MIN, SLIDE_DECEL * delta)
		velocity.x = slide_direction.x * current_slide_speed
		velocity.z = slide_direction.z * current_slide_speed


# --- DASH: 3 charges, each recharges independently ---
func _handle_dash(delta: float) -> void:
	if Input.is_action_just_pressed("dash") and dash_charges > 0 and not is_dashing:
		is_dashing = true
		if dash_sound:
			dash_sound.pitch_scale = randf_range(0.95, 1.05)
			dash_sound.play()
		dash_timer = DASH_DURATION
		dash_charges -= 1

		# Start recharge timer for the spent charge
		for i in range(DASH_MAX_CHARGES):
			if dash_recharge_timers[i] <= 0.0 and i >= dash_charges:
				dash_recharge_timers[i] = DASH_RECHARGE_TIME
				break

		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dash_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if dash_direction == Vector3.ZERO:
			dash_direction = -transform.basis.z

		# Cancel slide on dash
		is_sliding = false

	if is_dashing:
		dash_timer -= delta
		velocity.x = dash_direction.x * DASH_SPEED
		velocity.z = dash_direction.z * DASH_SPEED
		velocity.y = 0.0
		if dash_timer <= 0.0:
			is_dashing = false




func _handle_dash_recharge(delta: float) -> void:
	for i in range(DASH_MAX_CHARGES):
		if dash_recharge_timers[i] > 0.0:
			dash_recharge_timers[i] -= delta
			if dash_recharge_timers[i] <= 0.0:
				dash_recharge_timers[i] = 0.0
				dash_charges = min(dash_charges + 1, DASH_MAX_CHARGES)

	# Update HUD dash charges
	if hud and hud.has_method("update_dash_charges"):
		hud.update_dash_charges(dash_charges, dash_recharge_timers, DASH_RECHARGE_TIME)


func _handle_camera(delta: float) -> void:
	_handle_camera_bob(delta)
	_handle_camera_tilt(delta)
	_handle_camera_fov(delta)
	_handle_screen_shake(delta)
	_handle_landing_bob(delta)


func _handle_camera_bob(delta: float) -> void:
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	var speed = horizontal_velocity.length()

	if is_on_floor() and speed > 0.5 and not is_sliding and not is_dashing:
		var freq = BOB_FREQUENCY_SPRINT if Input.is_action_pressed("sprint") else BOB_FREQUENCY_WALK
		var amp = BOB_AMPLITUDE_SPRINT if Input.is_action_pressed("sprint") else BOB_AMPLITUDE_WALK
		bob_timer += delta * freq
		camera.position.y = default_camera_y + sin(bob_timer) * amp
	else:
		bob_timer = 0.0
		camera.position.y = lerp(camera.position.y, default_camera_y, delta * 10.0)


func _handle_camera_tilt(delta: float) -> void:
	# Only tilt on slide, no tilt on dash
	if is_sliding:
		target_tilt = TILT_SLIDE
	else:
		target_tilt = 0.0

	current_tilt = lerp(current_tilt, target_tilt, delta * TILT_SPEED)
	camera.rotation.z = current_tilt


func _handle_camera_fov(delta: float) -> void:
	var target_fov: float
	if is_ads:
		target_fov = FOV_DEFAULT * FOV_ADS_MULTIPLIER
	elif is_dashing:
		target_fov = FOV_DASH
	elif is_sliding:
		target_fov = FOV_SLIDE
	elif Input.is_action_pressed("sprint"):
		target_fov = FOV_SPRINT
	else:
		target_fov = FOV_DEFAULT
	camera.fov = lerp(camera.fov, target_fov + fire_fov_kick, delta * FOV_SPEED)

func take_damage(amount: float) -> void:
	if is_dead:
		return
	if fire_revenge_active:
		return
	current_health -= amount
	shake(0.06)
	if hit_sound and not hit_sound.playing:
		hit_sound.pitch_scale = randf_range(0.9, 1.1)
		hit_sound.play()
	if hud:
		hud.update_health(current_health, max_health)
		hud.flash_damage()
	if current_health > 0 and current_health / max_health < FIRE_TRIGGER_THRESHOLD:
		_try_trigger_fire()
	if current_health <= 0 and not fire_is_healing:
		die()


func die() -> void:
	if is_dead:
		return
	is_dead = true
	current_health = 0
	fire_is_healing = false
	fire_revenge_active = false
	shake(0.45)
	Engine.time_scale = 0.12
	await get_tree().create_timer(0.4).timeout
	Engine.time_scale = 1.0
	if death_sound:
		death_sound.play()
	if hud:
		hud.update_health(0, max_health)
		hud.show_death_screen()
	velocity = Vector3.ZERO
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if weapon_manager and weapon_manager.current_weapon:
		weapon_manager.current_weapon.can_fire = false
	footstep_sound.stop()
	rage_breathing_sound.stop()


func shake(intensity: float) -> void:
	shake_intensity = intensity


func _handle_screen_shake(delta: float) -> void:
	if shake_intensity > 0:
		shake_intensity = lerp(shake_intensity, 0.0, SHAKE_DECAY * delta)
		camera.position.x = randf_range(-shake_intensity, shake_intensity)
		camera.position.y = default_camera_y + randf_range(-shake_intensity, shake_intensity)
	else:
		camera.position.x = lerp(camera.position.x, 0.0, delta * 10.0)


func _handle_landing_bob(delta: float) -> void:
	var on_floor = is_on_floor()
	if was_in_air and on_floor:
		land_bob_timer = LAND_BOB_DURATION
		shake(0.02)
	was_in_air = not on_floor
	if land_bob_timer > 0:
		land_bob_timer -= delta
		var t = 1.0 - (land_bob_timer / LAND_BOB_DURATION)
		var bob = sin(t * PI) * LAND_BOB_AMOUNT
		camera.position.y = default_camera_y - bob


func _handle_footsteps(delta: float) -> void:
	var on_floor = is_on_floor()
	var speed = Vector3(velocity.x, 0, velocity.z).length()
	if on_floor and speed > 1.0:
		var interval = 0.4 if not Input.is_action_pressed("sprint") else 0.25
		footstep_timer -= delta
		if footstep_timer <= 0:
			footstep_sound.play()
			footstep_timer = interval
	else:
		footstep_timer = 0.1


func add_rage(amount: float) -> void:
	if is_raging:
		return
	rage = min(rage + amount, 100.0)
	if hud:
		hud.update_rage(rage)



func _activate_rage() -> void:
	is_raging = true
	rage_timer = RAGE_DURATION
	shake(0.08)
	if hud:
		hud.flash_damage()
	target_pitch = 0.6
	rage_activate_sound.play()
	rage_breathing_sound.play()
	time_scale_target = 0.4


func _handle_rage(delta: float) -> void:
	# Manual activation with G — only if rage is full
	if Input.is_action_just_pressed("rage") and rage >= 100.0 and not is_raging:
		_activate_rage()

	if is_raging:
		rage_timer -= get_process_delta_time() / Engine.time_scale
		rage_vignette_alpha = 0.2 + sin(rage_timer * 4.0) * 0.08
		if hud:
			hud.set_rage_vignette(rage_vignette_alpha)
			hud.update_rage(rage_timer / RAGE_DURATION * 100.0)
		if rage_timer <= 0:
			is_raging = false
			rage = 0.0
			rage_vignette_alpha = 0.0
			rage_breathing_sound.stop()
			time_scale_target = 1.0
			target_pitch = 1.0
			if hud:
				hud.set_rage_vignette(0.0)
				hud.update_rage(0.0)


func heal(amount: float) -> void:
	if is_dead:
		return
	current_health = min(current_health + amount, max_health)
	if hud:
		hud.update_health(current_health, max_health)
		hud.flash_heal()


func _try_trigger_fire() -> void:
	if fire_is_healing:
		return
	if fire_cooldown_timer > 0.0:
		return
	if max_health <= FIRE_MAX_HP_COST:
		return
	if fire_triggers_remaining <= 0:
		return
	fire_is_healing = true
	fire_triggers_remaining -= 1
	fire_cooldown_timer = FIRE_COOLDOWN
	fire_heal_target_hp = max_health * FIRE_HEAL_TARGET
	max_health = max(max_health - FIRE_MAX_HP_COST, FIRE_MAX_HP_COST)
	fire_timescale_timer = FIRE_TIMESCALE_DURATION
	time_scale_target = FIRE_TIMESCALE_TARGET
	fire_fov_kick = FIRE_FOV_AMOUNT
	fire_hud_pulse_timer = FIRE_HUD_PULSE_DURATION
	fire_revenge_active = true
	fire_revenge_timer = FIRE_REVENGE_WINDOW
	shake(0.22)
	if hud:
		hud.flash_fire_regen()
		hud.update_health(current_health, max_health)
	_spawn_fire_shockwave()
	if weapon_manager:
		for weapon in weapon_manager.weapons:
			if weapon.has_method("drain_fuel"):
				weapon.drain_fuel(35.0)
				break


func _handle_fire_regen(delta: float) -> void:
	if fire_cooldown_timer > 0.0:
		fire_cooldown_timer -= delta
	if fire_revenge_active:
		fire_revenge_timer -= delta / Engine.time_scale
		if fire_revenge_timer <= 0.0:
			fire_revenge_active = false
	if fire_timescale_timer > 0.0:
		fire_timescale_timer -= delta / Engine.time_scale
		if fire_timescale_timer <= 0.0:
			time_scale_target = 1.0
	if fire_fov_kick > 0.0:
		fire_fov_kick = move_toward(fire_fov_kick, 0.0, 120.0 * delta)
	if fire_hud_pulse_timer > 0.0:
		fire_hud_pulse_timer -= delta
		if hud:
			hud.pulse_health_bar(abs(sin(fire_hud_pulse_timer * 14.0)))
	elif fire_hud_pulse_timer <= 0.0 and fire_hud_pulse_timer > -0.1:
		fire_hud_pulse_timer = -1.0
		if hud:
			hud.pulse_health_bar(0.0)
	if not fire_is_healing:
		return
	current_health = move_toward(current_health, fire_heal_target_hp, FIRE_HEAL_SPEED * delta)
	if hud:
		hud.update_health(current_health, max_health)
	if current_health >= fire_heal_target_hp:
		fire_is_healing = false
		current_health = fire_heal_target_hp
	if max_health <= FIRE_MAX_HP_COST:
		fire_is_healing = false


func _spawn_fire_shockwave() -> void:
	var particles = GPUParticles3D.new()
	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position + Vector3(0, 0.9, 0)
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 180.0
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 14.0
	mat.gravity = Vector3(0, 2.0, 0)
	mat.scale_min = 0.06
	mat.scale_max = 0.22
	mat.color = Color(1.0, 0.85, 0.1)
	mat.radial_accel_min = 8.0
	mat.radial_accel_max = 16.0
	var mesh_ref = SphereMesh.new()
	mesh_ref.radius = 0.05
	mesh_ref.height = 0.1
	particles.process_material = mat
	particles.draw_pass_1 = mesh_ref
	particles.amount = 48
	particles.lifetime = 0.9
	particles.one_shot = true
	particles.explosiveness = 0.98
	particles.emitting = true
	await get_tree().create_timer(1.1).timeout
	particles.queue_free()

func _handle_ads_input() -> void:
	var wm = weapon_manager
	if not wm or not wm.get("current_weapon"):
		return
	var weapon = wm.current_weapon
	# Flamethrower can't ADS
	if weapon.weapon_name == "The Flame":
		return
	if Input.is_action_just_pressed("ads"):
		is_ads = true
		weapon.start_ads()
	elif Input.is_action_just_released("ads"):
		is_ads = false
		weapon.stop_ads()
	# Safety — release ADS if weapon switched mid-aim
	if is_ads and not Input.is_action_pressed("ads"):
		is_ads = false
		weapon.stop_ads()
