extends CharacterBody3D

# --- STATS ---
@export var max_health: float = 65.0
@export var move_speed: float = 15
@export var attack_damage: float = 14.0
@export var preferred_range: float = 12.0
@export var min_range: float = 6.0
@export var max_range: float = 22.0
@export var projectile_speed: float = 16.0

# --- BURST FIRE ---
@export var burst_count: int = 3
@export var burst_interval: float = 0.18
@export var burst_cooldown: float = 2.8
@export var windup_duration: float = 1.4  # long chant telegraph — readable, fits lore

var burst_timer := 0.0
var burst_cooldown_timer := 0.0
var shots_fired_in_burst := 0
var is_winding_up := false
var is_bursting := false
var windup_timer := 0.0

# --- DODGE ---
const DODGE_SPEED := 14.0
const DODGE_DURATION := 0.22
const DODGE_COOLDOWN := 1.8
var is_dodging := false
var dodge_timer := 0.0
var dodge_cooldown_timer := 0.0
var dodge_direction := Vector3.ZERO

# --- STATE ---
var current_health: float
var player: CharacterBody3D = null
var is_dead: bool = false

# --- HIT FLASH ---
var flash_timer := 0.0
const FLASH_DURATION := 0.1
var original_material: Material = null
var flash_material: StandardMaterial3D = null

# --- WINDUP MATERIAL ---
var windup_material: StandardMaterial3D = null
var windup_glow := 0.0

# --- STAGGER ---
var stagger_timer := 0.0
const STAGGER_DURATION := 0.25
const STAGGER_THRESHOLD := 20.0
var damage_accumulator := 0.0
var is_staggered := false

# --- STRAFE ---
var strafe_timer := 0.0
var strafe_direction := 1.0
const STRAFE_SWITCH_MIN := 1.2
const STRAFE_SWITCH_MAX := 2.8

const GRAVITY = 24.0

# --- NODES ---
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var hit_sound: AudioStreamPlayer = $HitSound
@onready var death_sound: AudioStreamPlayer = $DeathSound
@onready var shoot_point: Marker3D = $ShootPoint

@export var projectile_scene: PackedScene
@export var health_pickup_scene: PackedScene

enum State { IDLE, REPOSITION, RETREAT, ATTACK, DEAD }
var state: State = State.IDLE


func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health
	player = get_tree().get_first_node_in_group("player")
	burst_cooldown_timer = randf_range(0.3, burst_cooldown)
	strafe_timer = randf_range(STRAFE_SWITCH_MIN, STRAFE_SWITCH_MAX)
	original_material = mesh.get_active_material(0)
	flash_material = StandardMaterial3D.new()
	flash_material.albedo_color = Color(1, 0.1, 0.1)
	flash_material.emission_enabled = true
	flash_material.emission = Color(1, 0, 0)
	flash_material.emission_energy_multiplier = 2.0
	windup_material = StandardMaterial3D.new()
	windup_material.albedo_color = Color(0.9, 0.7, 0.1)
	windup_material.emission_enabled = true
	# Corrupt gold glow during chant — matches palette
	windup_material.emission = Color(0.94, 0.75, 0.03)
	windup_material.emission_energy_multiplier = 0.0


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_handle_gravity(delta)
	_handle_stagger(delta)
	_handle_dodge(delta)
	if not is_staggered and not is_dodging:
		_update_state()
		_handle_state(delta)
	_handle_burst(delta)
	_handle_windup_glow(delta)
	_handle_flash(delta)
	move_and_slide()


func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta


func _handle_stagger(delta: float) -> void:
	if is_staggered:
		stagger_timer -= delta
		var away = (global_position - player.global_position).normalized()
		velocity.x = away.x * 5.0
		velocity.z = away.z * 5.0
		if stagger_timer <= 0:
			is_staggered = false


func notify_incoming_projectile(proj_origin: Vector3, proj_vel: Vector3) -> void:
	if is_dead or is_dodging or dodge_cooldown_timer > 0.0:
		return
	if proj_vel.normalized().dot((global_position - proj_origin).normalized()) < 0.7:
		return
	_start_dodge()


func _start_dodge() -> void:
	is_dodging = true
	dodge_timer = DODGE_DURATION
	dodge_cooldown_timer = DODGE_COOLDOWN
	var right = transform.basis.x.normalized()
	right.y = 0
	dodge_direction = right * (1.0 if randf() > 0.5 else -1.0)


func _handle_dodge(delta: float) -> void:
	if dodge_cooldown_timer > 0.0:
		dodge_cooldown_timer -= delta
	if is_dodging:
		dodge_timer -= delta
		velocity.x = dodge_direction.x * DODGE_SPEED
		velocity.z = dodge_direction.z * DODGE_SPEED
		_face_player()
		if dodge_timer <= 0.0:
			is_dodging = false


func _update_state() -> void:
	if player == null:
		state = State.IDLE
		return
	var dist = global_position.distance_to(player.global_position)
	if dist > max_range:
		state = State.IDLE
	elif dist < min_range:
		state = State.RETREAT
	elif abs(dist - preferred_range) > 3.0:
		state = State.REPOSITION
	else:
		state = State.ATTACK


func _handle_state(delta: float) -> void:
	match state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0, move_speed)
			velocity.z = move_toward(velocity.z, 0, move_speed)
		State.REPOSITION:
			var dist = global_position.distance_to(player.global_position)
			var to_player = (player.global_position - global_position).normalized()
			var desired_pos: Vector3
			if dist > preferred_range:
				desired_pos = global_position + to_player * (dist - preferred_range)
			else:
				desired_pos = global_position - to_player * (preferred_range - dist)
			nav_agent.target_position = desired_pos
			_move_along_nav(delta)
			_face_player()
		State.RETREAT:
			var away = (global_position - player.global_position).normalized()
			away.y = 0
			velocity.x = away.x * move_speed * 1.4
			velocity.z = away.z * move_speed * 1.4
			_face_player()
		State.ATTACK:
			_handle_strafe(delta)
			_face_player()


func _handle_strafe(delta: float) -> void:
	strafe_timer -= delta
	if strafe_timer <= 0:
		strafe_direction *= -1.0
		strafe_timer = randf_range(STRAFE_SWITCH_MIN, STRAFE_SWITCH_MAX)
	var right = transform.basis.x.normalized()
	right.y = 0
	velocity.x = right.x * move_speed * strafe_direction
	velocity.z = right.z * move_speed * strafe_direction


func _move_along_nav(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		return
	var next = nav_agent.get_next_path_position()
	var dir = (next - global_position).normalized()
	dir.y = 0
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed


func _face_player() -> void:
	if player == null:
		return
	look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)


func _handle_burst(delta: float) -> void:
	if is_dead or is_staggered or player == null:
		_cancel_windup()
		return
	if state != State.ATTACK and state != State.REPOSITION:
		_cancel_windup()
		return
	if burst_cooldown_timer > 0.0:
		burst_cooldown_timer -= delta
		return
	if not is_winding_up and not is_bursting:
		is_winding_up = true
		windup_timer = windup_duration
		shots_fired_in_burst = 0
		mesh.set_surface_override_material(0, windup_material)
	if is_winding_up:
		windup_timer -= delta
		windup_glow = 1.0 - (windup_timer / windup_duration)
		if windup_timer <= 0.0:
			is_winding_up = false
			is_bursting = true
			burst_timer = 0.0
	if is_bursting:
		burst_timer -= delta
		if burst_timer <= 0.0:
			_fire_projectile()
			shots_fired_in_burst += 1
			if shots_fired_in_burst >= burst_count:
				is_bursting = false
				windup_glow = 0.0
				burst_cooldown_timer = burst_cooldown
				mesh.set_surface_override_material(0, original_material)
			else:
				burst_timer = burst_interval


func _cancel_windup() -> void:
	if not is_winding_up and not is_bursting:
		return
	is_winding_up = false
	is_bursting = false
	windup_glow = 0.0
	mesh.set_surface_override_material(0, original_material)
	burst_cooldown_timer = burst_cooldown * 0.5


func _handle_windup_glow(delta: float) -> void:
	if not is_winding_up and not is_bursting:
		return
	var pulse = sin(windup_glow * PI * 6.0) * 0.15 + windup_glow
	pulse = clamp(pulse, 0.0, 1.0)
	# Corrupt gold chant glow — matches palette
	windup_material.emission = Color(0.94, lerp(0.3, 0.75, pulse), 0.03)
	windup_material.emission_energy_multiplier = lerp(1.0, 8.0, pulse)
	windup_material.albedo_color = Color(lerp(0.6, 0.94, pulse), lerp(0.4, 0.75, pulse), 0.03)


func _fire_projectile() -> void:
	if projectile_scene == null:
		push_warning("CorruptedClergy: projectile_scene not assigned!")
		return
	var proj = projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = shoot_point.global_position
	var travel_time = shoot_point.global_position.distance_to(player.global_position) / projectile_speed
	var predicted_pos = player.global_position + player.velocity * travel_time * 0.4
	var dir = (predicted_pos - shoot_point.global_position).normalized()
	proj.initialize(dir, projectile_speed, attack_damage)


func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_health -= amount
	damage_accumulator += amount
	if damage_accumulator >= STAGGER_THRESHOLD:
		damage_accumulator = 0.0
		is_staggered = true
		stagger_timer = STAGGER_DURATION
		_cancel_windup()
	if is_winding_up and dodge_cooldown_timer <= 0.0:
		_cancel_windup()
		_start_dodge()
	_flash_hit()
	hit_sound.play()
	if current_health <= 0:
		die()


func _flash_hit() -> void:
	flash_timer = FLASH_DURATION
	mesh.set_surface_override_material(0, flash_material)


func _handle_flash(delta: float) -> void:
	if flash_timer > 0:
		flash_timer -= delta
		if flash_timer <= 0:
			if is_winding_up or is_bursting:
				mesh.set_surface_override_material(0, windup_material)
			else:
				mesh.set_surface_override_material(0, original_material)


func die() -> void:
	is_dead = true
	state = State.DEAD
	death_sound.play()
	GameManager.register_kill()
	if player:
		player.add_rage(20.0)
	# Collapse slowly — per lore
	await get_tree().create_timer(1.2).timeout
	_spawn_death_particles()
	await get_tree().create_timer(0.6).timeout
	queue_free()


func _spawn_death_particles() -> void:
	var particles = GPUParticles3D.new()
	get_parent().add_child(particles)
	particles.global_position = global_position + Vector3(0, 0.9, 0)
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, 0)
	material.spread = 60.0
	material.initial_velocity_min = 1.0
	material.initial_velocity_max = 4.0  # slower collapse than other enemies
	material.gravity = Vector3(0, -4.0, 0)
	material.scale_min = 0.1
	material.scale_max = 0.3
	material.color = Color(0.94, 0.75, 0.03)  # corrupt gold decay
	var mesh_ref = SphereMesh.new()
	mesh_ref.radius = 0.05
	mesh_ref.height = 0.1
	particles.process_material = material
	particles.draw_pass_1 = mesh_ref
	particles.amount = 24
	particles.lifetime = 1.4
	particles.one_shot = true
	particles.explosiveness = 0.7  # less explosive, more of a slow crumble
	particles.emitting = true
	await get_tree().create_timer(1.8).timeout
	particles.queue_free()
