extends CharacterBody3D

# --- STATS ---
@export var max_health: float = 280.0
@export var move_speed: float = 15
@export var attack_damage: float = 35.0
@export var attack_range: float = 1.5
@export var chase_range: float = 30.0

# --- KNOCKBACK RESISTANCE ---
const KNOCKBACK_RESISTANCE := 0.85


# --- STATE ---
var current_health: float
var player: CharacterBody3D = null
var is_dead: bool = false
var can_attack: bool = true

# --- HIT FLASH ---
var flash_timer := 0.0
const FLASH_DURATION := 0.1
var original_material: Material = null
var flash_material: StandardMaterial3D = null

# --- STAGGER ---
# Demons don't stagger — they just don't stop
var stagger_timer := 0.0
const STAGGER_DURATION := 0.0
const STAGGER_THRESHOLD := 999.0
var damage_accumulator := 0.0
var is_staggered := false

# --- NODES ---
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var attack_timer: Timer = $AttackTimer
@onready var mesh: MeshInstance3D = $Ch36_nonPBR/Skeleton3D/Ch36
@onready var hit_sound: AudioStreamPlayer = $HitSound
@onready var death_sound: AudioStreamPlayer = $DeathSound

@export var health_pickup_scene: PackedScene
@onready var anim: AnimationPlayer = $Ch36_nonPBR/AnimationPlayer
const GRAVITY = 24.0

enum State { IDLE, CHASE, ATTACK, DEAD }
var state: State = State.IDLE


func _ready() -> void:
	anim.play("idle")
	add_to_group("enemies")
	current_health = max_health
	player = get_tree().get_first_node_in_group("player")
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	attack_timer.start()
	original_material = mesh.get_active_material(0)
	flash_material = StandardMaterial3D.new()
	flash_material.albedo_color = Color(0.8, 0.0, 0.0)
	flash_material.emission_enabled = true
	flash_material.emission = Color(1, 0, 0)
	flash_material.emission_energy_multiplier = 2.0


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_handle_gravity(delta)
	# Demons don't stagger — skip stagger handling
	_update_state()
	_handle_state(delta)
	_handle_flash(delta)
	move_and_slide()


func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta


func _update_state() -> void:
	if player == null:
		state = State.IDLE
		return
	var dist = global_position.distance_to(player.global_position)
	if dist <= attack_range:
		state = State.ATTACK
	elif dist <= chase_range:
		state = State.CHASE
	else:
		# Demons never fully idle — they always know where you are
		state = State.CHASE


func _handle_state(delta: float) -> void:
	match state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0, move_speed)
			velocity.z = move_toward(velocity.z, 0, move_speed)
		State.CHASE:
			_chase()
		State.ATTACK:
			velocity.x = move_toward(velocity.x, 0, move_speed * 2)
			velocity.z = move_toward(velocity.z, 0, move_speed * 2)
			_face_player()


func _chase() -> void:
	var direction = (player.global_position - global_position).normalized()
	direction.y = 0
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	_face_player()


func _face_player() -> void:
	if player == null:
		return
	var look_target = Vector3(player.global_position.x, global_position.y, player.global_position.z)
	look_at(look_target, Vector3.UP)


func _on_attack_timer_timeout() -> void:
	if state == State.ATTACK and player != null:
		player.take_damage(attack_damage)


func take_damage(amount: float) -> void:
	if is_dead:
		return
	# Apply knockback resistance — Demons barely flinch
	var resisted = amount * (1.0 - KNOCKBACK_RESISTANCE)
	current_health -= amount  # full damage, just no stagger
	_flash_hit()
	hit_sound.play()
	if current_health <= 0:
		die()


func _flash_hit() -> void:
	flash_timer = FLASH_DURATION
	mesh.set_surface_override_material(0, flash_material)


func die() -> void:
	is_dead = true
	state = State.DEAD
	death_sound.play()
	GameManager.register_kill()
	if player:
		player.add_rage(25.0)
	_spawn_death_particles()
	await get_tree().create_timer(0.5).timeout
	queue_free()


func _spawn_death_particles() -> void:
	var particles = GPUParticles3D.new()
	get_parent().add_child(particles)
	particles.global_position = global_position + Vector3(0, 0.9, 0)
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, 0)
	material.spread = 60.0
	material.initial_velocity_min = 3.0
	material.initial_velocity_max = 8.0
	material.gravity = Vector3(0, -9.8, 0)
	material.scale_min = 0.1
	material.scale_max = 0.3
	material.color = Color(0.8, 0.1, 0.1)
	var mesh_ref = SphereMesh.new()
	mesh_ref.radius = 0.05
	mesh_ref.height = 0.1
	particles.process_material = material
	particles.draw_pass_1 = mesh_ref
	particles.amount = 24
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.emitting = true
	await get_tree().create_timer(1.2).timeout
	particles.queue_free()


func _handle_flash(delta: float) -> void:
	if flash_timer > 0:
		flash_timer -= delta
		if flash_timer <= 0:
			mesh.set_surface_override_material(0, original_material)
