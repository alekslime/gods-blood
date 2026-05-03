extends Area3D

# Set by the enemy via initialize()
var direction: Vector3 = Vector3.FORWARD
var speed: float = 16.0
var damage: float = 12.0

# --- ACCELERATION ---
# Projectile starts slow and ramps to max_speed — terrifying to watch approach
const SPEED_RAMP_TIME := 0.6      # seconds to reach max speed
const SPEED_MULTIPLIER := 2.2     # max_speed = initial speed * this
var elapsed := 0.0
var initial_speed: float = 0.0

# --- LIFETIME ---
const LIFETIME := 5.0
var lifetime_timer := 0.0

# --- VISUAL SCALE PULSE ---
var base_scale := Vector3.ONE
var pulse_time := 0.0

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var light: OmniLight3D = $OmniLight3D
@onready var trail: GPUParticles3D = $Trail


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func initialize(dir: Vector3, proj_speed: float, proj_damage: float) -> void:
	direction = dir.normalized()
	speed = proj_speed
	initial_speed = proj_speed
	damage = proj_damage

	if direction != Vector3.ZERO:
		look_at(global_position + direction, Vector3.UP)

	# Set up glowing orange orb material procedurally
	if mesh:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.5, 0.0)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.4, 0.0)
		mat.emission_energy_multiplier = 4.0
		mesh.set_surface_override_material(0, mat)

	if light:
		light.light_color = Color(1.0, 0.4, 0.0)
		light.light_energy = 2.0
		light.omni_range = 3.0


func _physics_process(delta: float) -> void:
	lifetime_timer += delta
	elapsed += delta
	pulse_time += delta

	if lifetime_timer >= LIFETIME:
		_destroy()
		return

	# --- Acceleration curve ---
	# Ease-in: slow at first, then rockets forward
	var t = clamp(elapsed / SPEED_RAMP_TIME, 0.0, 1.0)
	var eased = t * t   # quadratic ease-in
	speed = lerp(initial_speed, initial_speed * SPEED_MULTIPLIER, eased)

	global_position += direction * speed * delta

	# --- Visual: scale pulse and light intensity ramp ---
	if mesh:
		var pulse = 1.0 + sin(pulse_time * 12.0) * 0.08
		mesh.scale = base_scale * pulse

	if light:
		# Light grows as projectile accelerates — looks like it's charging
		light.light_energy = lerp(2.0, 6.0, eased)
		light.omni_range = lerp(3.0, 6.0, eased)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.take_damage(damage)
		_destroy()
	elif not body.is_in_group("enemy"):
		_destroy()


func _destroy() -> void:
	_spawn_impact_particles()
	set_physics_process(false)
	if mesh:
		mesh.visible = false
	if light:
		light.visible = false
	if trail:
		trail.emitting = false
	await get_tree().create_timer(0.5).timeout
	queue_free()


func _spawn_impact_particles() -> void:
	var particles = GPUParticles3D.new()
	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position

	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 80.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 9.0
	mat.gravity = Vector3(0, -9.8, 0)
	mat.scale_min = 0.05
	mat.scale_max = 0.2
	mat.color = Color(1.0, 0.45, 0.0)

	# Secondary ring — makes the impact feel meaty
	mat.radial_accel_min = 2.0
	mat.radial_accel_max = 6.0

	var mesh_ref = SphereMesh.new()
	mesh_ref.radius = 0.05
	mesh_ref.height = 0.1

	particles.process_material = mat
	particles.draw_pass_1 = mesh_ref
	particles.amount = 28
	particles.lifetime = 0.55
	particles.one_shot = true
	particles.explosiveness = 0.98
	particles.emitting = true

	await get_tree().create_timer(0.7).timeout
	particles.queue_free()
