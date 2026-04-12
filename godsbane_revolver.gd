extends BaseWeapon

@onready var shoot_sound: AudioStreamPlayer = $ShootSound
@onready var cycle_sound: AudioStreamPlayer = $CycleSound
@onready var reload_sound: AudioStreamPlayer = $ReloadSound
@onready var reload_bullet_sound: AudioStreamPlayer = $ReloadBulletSound
@onready var empty_sound: AudioStreamPlayer = $EmptySound
@onready var ads_sound: AudioStreamPlayer = $AdsSound
@onready var hit_sound: AudioStreamPlayer = $HitSound

const BULLET_RANGE := 80.0
const STAGGER_DURATION := 1.2
const RELOAD_TIME := 2.4

# --- PROGRESSIVE RELOAD ---
const BULLET_RELOAD_TIME := 0.55   # time per bullet insert
const RELOAD_START_DELAY := 0.3    # brief pause before first bullet
var is_reloading := false
var reload_bullets_remaining := 0
var reload_timer := 0.0
var reload_start_timer := 0.0
var reload_started := false

var recoil_offset := Vector3.ZERO
const RECOIL_KICK := Vector3(0, 0.08, 0.14)
const RECOIL_RETURN_SPEED := 8.0

var original_pos := Vector3.ZERO
var muzzle_light: OmniLight3D = null


func _ready() -> void:
	weapon_name = "Godsbane Revolver"
	damage = 45.0
	fire_rate = 1.2
	ammo_current = 6
	ammo_max = 6
	is_infinite_ammo = false
	original_pos = position
	super._ready()

	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(1.0, 0.7, 0.3)
	muzzle_light.light_energy = 0.0
	muzzle_light.omni_range = 10.0
	add_child(muzzle_light)


func _physics_process(delta: float) -> void:
	_handle_reload(delta)
	recoil_offset = recoil_offset.lerp(Vector3.ZERO, RECOIL_RETURN_SPEED * delta)
	position = original_pos + recoil_offset
	if muzzle_light:
		muzzle_light.light_energy = move_toward(muzzle_light.light_energy, 0.0, 40.0 * delta)


func _handle_reload(delta: float) -> void:
	if not is_reloading:
		return

	# Start delay before first bullet
	if not reload_started:
		reload_start_timer -= delta
		if reload_start_timer <= 0.0:
			reload_started = true
			reload_timer = 0.0
		return

	# Load one bullet at a time
	reload_timer -= delta
	if reload_timer <= 0.0:
		ammo_current += 1
		reload_bullets_remaining -= 1
		if reload_bullet_sound:
			reload_bullet_sound.pitch_scale = randf_range(0.95, 1.05)
			reload_bullet_sound.play()
		if reload_bullets_remaining <= 0:
			# All bullets loaded — wait for last sound to finish then allow firing
			is_reloading = false
			reload_started = false
			can_fire = true
		else:
			reload_timer = BULLET_RELOAD_TIME


func _start_reload() -> void:
	if is_reloading or ammo_current == ammo_max:
		return
	is_reloading = true
	reload_started = false
	reload_start_timer = RELOAD_START_DELAY
	reload_bullets_remaining = ammo_max - ammo_current
	reload_timer = BULLET_RELOAD_TIME
	can_fire = false
	if reload_sound:
		reload_sound.play()


func try_fire() -> void:
	if is_reloading:
		return
	if ammo_current <= 0:
		if empty_sound:
			empty_sound.pitch_scale = randf_range(0.95, 1.05)
			empty_sound.play()
		_start_reload()
		return
	super.try_fire()


func fire() -> void:
	shoot_sound.play()
	# Cycle sound plays shortly after shot — the SHKEKKEK
	_play_cycle_sound()
	recoil_offset = RECOIL_KICK
	if muzzle_light:
		muzzle_light.light_energy = 14.0

	var cam = get_viewport().get_camera_3d()
	var origin = cam.global_position
	var dir = -cam.global_transform.basis.z
	var target = origin + dir * BULLET_RANGE

	var query = PhysicsRayQueryParameters3D.create(origin, target)
	query.exclude = [get_parent().get_parent().get_parent()]
	var result = get_world_3d().direct_space_state.intersect_ray(query)

	var hit_pos = result.position if result else target
	var tracer_start = origin + dir * 2.0
	_draw_tracer(tracer_start, hit_pos, Color(1.0, 0.85, 0.1), 0.08, 1.2)

	if result:
		deal_damage(result.collider)
		if result.collider.has_method("stagger"):
			result.collider.stagger(STAGGER_DURATION)
		elif result.collider.get_parent() and result.collider.get_parent().has_method("stagger"):
			result.collider.get_parent().stagger(STAGGER_DURATION)
		_spawn_hit_effect(result.position, result.normal)
		GoreManager.spawn_blood(result.position, result.normal, get_tree().current_scene)
		if hit_sound:
			hit_sound.pitch_scale = randf_range(0.9, 1.1)
			hit_sound.play()

	if ammo_current <= 0:
		_start_reload()


func _play_cycle_sound() -> void:
	await get_tree().create_timer(0.12).timeout
	if cycle_sound:
		cycle_sound.pitch_scale = randf_range(0.95, 1.05)
		cycle_sound.play()


func start_ads() -> void:
	is_ads = true
	if ads_sound:
		ads_sound.pitch_scale = randf_range(0.98, 1.02)
		ads_sound.play()


func add_ammo(amount: int) -> void:
	ammo_current = min(ammo_current + amount, ammo_max)
	is_reloading = false
	reload_timer = 0.0


func _draw_tracer(from: Vector3, to: Vector3, color: Color, thickness: float, duration: float) -> void:
	var length = from.distance_to(to)
	if length < 0.5:
		return
	var tracer = MeshInstance3D.new()
	get_tree().current_scene.add_child(tracer)
	var box = BoxMesh.new()
	box.size = Vector3(thickness, thickness, length)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 1.0)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 6.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	box.surface_set_material(0, mat)
	tracer.mesh = box
	tracer.global_position = (from + to) / 2.0
	var d = (to - from).normalized()
	var up = Vector3.UP if abs(d.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var right = d.cross(up).normalized()
	var nup = right.cross(d).normalized()
	tracer.global_transform.basis = Basis(right, nup, -d)
	var hold := duration * 0.15
	var fade := duration * 0.85
	await get_tree().create_timer(hold).timeout
	if not is_instance_valid(tracer):
		return
	var tween = get_tree().create_tween()
	tween.tween_method(func(a: float):
		if is_instance_valid(mat):
			mat.albedo_color.a = a
			mat.emission_energy_multiplier = a * 6.0
	, 1.0, 0.0, fade)
	await get_tree().create_timer(fade + 0.05).timeout
	if is_instance_valid(tracer):
		tracer.queue_free()


func _spawn_hit_effect(pos: Vector3, normal: Vector3) -> void:
	var particles = GPUParticles3D.new()
	get_tree().current_scene.add_child(particles)
	particles.global_position = pos
	var mat = ParticleProcessMaterial.new()
	mat.direction = normal
	mat.spread = 45.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 9.0
	mat.gravity = Vector3(0, -9.8, 0)
	mat.scale_min = 0.06
	mat.scale_max = 0.22
	mat.color = Color(1.0, 0.85, 0.3)
	var mesh_ref = SphereMesh.new()
	mesh_ref.radius = 0.05
	mesh_ref.height = 0.1
	particles.process_material = mat
	particles.draw_pass_1 = mesh_ref
	particles.amount = 24
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.emitting = true
	await get_tree().create_timer(0.8).timeout
	particles.queue_free()
