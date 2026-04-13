extends CharacterBody3D

# --- STATS ---
@export var max_health: float = 45.0
@export var move_speed: float = 9.5
@export var attack_damage: float = 8.0
@export var attack_range: float = 1.8
@export var chase_range: float = 28.0
@export var leap_range: float = 8.0

# --- LEAP ---
const LEAP_SPEED := 22.0
const LEAP_UPWARD := 5.0
const LEAP_COOLDOWN_MIN := 1.4
const LEAP_COOLDOWN_MAX := 3.5
const LEAP_DAMAGE := 20.0
var leap_cooldown_timer := 0.0
var is_leaping := false

# --- ERRATIC MOVEMENT ---
const ERRATIC_INTERVAL_MIN := 0.3
const ERRATIC_INTERVAL_MAX := 0.8
var erratic_timer := 0.0
var erratic_offset := Vector3.ZERO

# --- STATE ---
var current_health: float
var player: CharacterBody3D = null
var is_dead: bool = false

# --- HIT FLASH ---
var flash_timer := 0.0
const FLASH_DURATION := 0.08
var original_material: Material = null
var flash_material: StandardMaterial3D = null

# --- STAGGER ---
# Angels stagger easily — they're unraveling, not tough
var stagger_timer := 0.0
const STAGGER_DURATION := 0.18
const STAGGER_THRESHOLD := 12.0
var damage_accumulator := 0.0
var is_staggered := false

const GRAVITY = 24.0

# --- NODES ---
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var hit_sound: AudioStreamPlayer = $HitSound
@onready var death_sound: AudioStreamPlayer = $DeathSound
@onready var attack_timer: Timer = $AttackTimer

@export var health_pickup_scene: PackedScene

enum State { IDLE, CHASE, LEAP, ATTACK, DEAD }
var state: State = State.IDLE


func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health
	player = get_tree().get_first_node_in_group("player")
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	attack_timer.start()
	leap_cooldown_timer = randf_range(0.5, LEAP_COOLDOWN_MAX)
	erratic_timer = randf_range(ERRATIC_INTERVAL_MIN, ERRATIC_INTERVAL_MAX)
	original_material = mesh.get_active_material(0)
	flash_material = StandardMaterial3D.new()
	# Angels flash cold blue — not red. They're not evil, just broken.
	flash_material.albedo_color = Color(0.3, 0.4, 1.0)
	flash_material.emission_enabled = true
	flash_material.emission = Color(0.4, 0.5, 1.0)
	flash_material.emission_energy_multiplier = 2.0


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_handle_gravity(delta)
	_handle_stagger(delta)
	_handle_leap_cooldown(delta)
	if not is_staggered:
		_update_state()
		_handle_state(delta)
	_handle_flash(delta)
	move_and_slide()


func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta


func _handle_stagger(delta: float) -> void:
	if is_staggered:
		stagger_timer -= delta
		var away = (global_position - player.global_position).normalized()
		velocity.x = away.x * 4.0
		velocity.z = away.z * 4.0
		if stagger_timer <= 0:
			is_staggered = false


func _handle_leap_cooldown(delta: float) -> void:
	if leap_cooldown_timer > 0.0:
		leap_cooldown_timer -= delta


func _try_leap() -> bool:
	if leap_cooldown_timer > 0.0 or is_leaping or player == null:
		return false
	if global_position.distance_to(player.global_position) > leap_range:
		return false
	if randf() > 0.55:
		return false
	_execute_leap()
	return true


func _execute_leap() -> void:
	is_leaping = true
	leap_cooldown_timer = randf_range(LEAP_COOLDOWN_MIN, LEAP_COOLDOWN_MAX)
	var travel_time = global_position.distance_to(player.global_position) / LEAP_SPEED
	var predicted = player.global_position + player.velocity * travel_time * 0.35
	var dir = (predicted - global_position).normalized()
	velocity.x = dir.x * LEAP_SPEED
	velocity.z = dir.z * LEAP_SPEED
	velocity.y = LEAP_UPWARD


func _check_leap_landing() -> void:
	if is_leaping and is_on_floor():
		is_leaping = false
		if global_position.distance_to(player.global_position) <= attack_range * 1.5:
			player.take_damage(LEAP_DAMAGE)
			if player.has_method("shake"):
				player.shake(0.12)


func _update_erratic(delta: float) -> void:
	erratic_timer -= delta
	if erratic_timer <= 0.0:
		erratic_timer = randf_range(ERRATIC_INTERVAL_MIN, ERRATIC_INTERVAL_MAX)
		var right = transform.basis.x.normalized()
		right.y = 0
		var strength = randf_range(0.3, 1.0) * (1.0 if randf() > 0.5 else -1.0)
		erratic_offset = right * strength * move_speed


func _update_state() -> void:
	if player == null:
		state = State.IDLE
		return
	var dist = global_position.distance_to(player.global_position)
	if dist <= attack_range:
		state = State.ATTACK
	elif dist <= chase_range:
		if dist <= leap_range and not is_leaping:
			if _try_leap():
				state = State.LEAP
				return
		state = State.CHASE
	else:
		state = State.IDLE


func _handle_state(delta: float) -> void:
	match state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0, move_speed)
			velocity.z = move_toward(velocity.z, 0, move_speed)
		State.CHASE:
			_chase(delta)
		State.LEAP:
			_check_leap_landing()
			_face_player()
		State.ATTACK:
			velocity.x = move_toward(velocity.x, 0, move_speed * 2)
			velocity.z = move_toward(velocity.z, 0, move_speed * 2)
			_face_player()


func _chase(delta: float) -> void:
	_update_erratic(delta)
	var to_player = (player.global_position - global_position).normalized()
	to_player.y = 0
	var blended = (to_player * move_speed + erratic_offset).normalized()
	velocity.x = blended.x * move_speed
	velocity.z = blended.z * move_speed
	_face_player()


func _face_player() -> void:
	if player == null:
		return
	look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)


func _on_attack_timer_timeout() -> void:
	if state == State.ATTACK and player != null:
		player.take_damage(attack_damage)


func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_health -= amount
	damage_accumulator += amount
	if damage_accumulator >= STAGGER_THRESHOLD:
		damage_accumulator = 0.0
		is_staggered = true
		stagger_timer = STAGGER_DURATION
		is_leaping = false
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
			mesh.set_surface_override_material(0, original_material)


func die() -> void:
	is_dead = true
	state = State.DEAD
	death_sound.play()
	GameManager.register_kill()
	if player:
		player.add_rage(18.0)
	_spawn_death_particles()
	_try_drop_health()
	await get_tree().create_timer(0.3).timeout
	queue_free()


func _try_drop_health() -> void:
	if health_pickup_scene == null:
		return
	GameManager.health_drop_toggle = !GameManager.health_drop_toggle
	if not GameManager.health_drop_toggle:
		return
	var pickup = health_pickup_scene.instantiate()
	pickup.setup(0, global_position)
	get_tree().current_scene.add_child(pickup)


func _spawn_death_particles() -> void:
	var particles = GPUParticles3D.new()
	get_parent().add_child(particles)
	particles.global_position = global_position + Vector3(0, 0.5, 0)
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, 0)
	material.spread = 75.0
	material.initial_velocity_min = 4.0
	material.initial_velocity_max = 10.0
	material.gravity = Vector3(0, -9.8, 0)
	material.scale_min = 0.06
	material.scale_max = 0.18
	# Angels die in cold blue — not red
	material.color = Color(0.3, 0.4, 1.0)
	var mesh_ref = SphereMesh.new()
	mesh_ref.radius = 0.04
	mesh_ref.height = 0.08
	particles.process_material = material
	particles.draw_pass_1 = mesh_ref
	particles.amount = 18
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.emitting = true
	await get_tree().create_timer(0.8).timeout
	particles.queue_free()
