extends BaseWeapon

@export var shell_casing_scene: PackedScene = preload("res://ShellCasing.tscn")

const PELLET_COUNT = 8
const SPREAD = 0.08
const PELLET_RANGE = 25.0

const RELOAD_TIME := 1.8
var is_reloading := false
var reload_timer := 0.0
@onready var reload_sound: AudioStreamPlayer = $ReloadSound
@onready var shoot_sound: AudioStreamPlayer = $ShootSound
@onready var cock_sound: AudioStreamPlayer = $CockSound
@onready var empty_sound: AudioStreamPlayer = $EmptySound

var kick_timer := 0.0
const KICK_DURATION := 0.12
const KICK_AMOUNT := 0.06
var original_pos := Vector3.ZERO
var is_kicking := false


func _ready() -> void:
	weapon_name = "Godsbane"
	damage = 18.0
	fire_rate = 0.85
	ammo_current = 2
	ammo_max = 2
	is_infinite_ammo = false
	original_pos = position
	super._ready()


func _physics_process(delta: float) -> void:
	_handle_kick(delta)
	_handle_reload(delta)


func _handle_reload(delta: float) -> void:
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			is_reloading = false
			ammo_current = ammo_max
			if reload_sound and reload_sound.playing:
				reload_sound.stop()
			can_fire = true


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


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("reload") and not is_reloading and ammo_current < ammo_max:
		_start_reload()


func fire() -> void:
	shoot_sound.play()
	_play_cock_sound()
	_eject_shell()
	for i in range(PELLET_COUNT):
		_fire_pellet()
	is_kicking = true
	kick_timer = KICK_DURATION
	_muzzle_flash()
	if ammo_current <= 0:
		_start_reload()


func _start_reload() -> void:
	if is_reloading or ammo_current == ammo_max:
		return
	is_reloading = true
	# Scale reload time to shells missing — 1 shell = short sound, 6 shells = full sound
	var shells_missing = ammo_max - ammo_current
	reload_timer = (float(shells_missing) / float(ammo_max)) * RELOAD_TIME
	can_fire = false
	if reload_sound:
		reload_sound.play()


func _play_cock_sound() -> void:
	await get_tree().create_timer(0.12).timeout
	if cock_sound:
		cock_sound.pitch_scale = randf_range(0.95, 1.05)
		cock_sound.play()


func _eject_shell() -> void:
	if not shell_casing_scene:
		return
	var shell = shell_casing_scene.instantiate()
	get_tree().current_scene.add_child(shell)
	var cam = get_viewport().get_camera_3d()
	# Spawn at camera position, slightly to the right and down
	shell.global_position = cam.global_position + \
		cam.global_transform.basis.x * 0.15 + \
		cam.global_transform.basis.y * -0.08
	# Eject right and slightly up with randomness
	var eject_dir = cam.global_transform.basis.x + \
		cam.global_transform.basis.y * 0.4
	shell.linear_velocity = eject_dir * randf_range(2.5, 4.5) + \
		Vector3(randf_range(-0.3, 0.3), randf_range(0.0, 0.5), randf_range(-0.3, 0.3))


func add_ammo(amount: int) -> void:
	ammo_current = min(ammo_current + amount, ammo_max)
	is_reloading = false
	reload_timer = 0.0


func _fire_pellet() -> void:
	var cam = get_viewport().get_camera_3d()
	var spread_x = randf_range(-SPREAD, SPREAD)
	var spread_y = randf_range(-SPREAD, SPREAD)
	var direction = (cam.global_transform.basis * Vector3(spread_x, spread_y, -1)).normalized()
	var origin = cam.global_position
	var target = origin + direction * PELLET_RANGE
	var query = PhysicsRayQueryParameters3D.create(origin, target)
	query.exclude = [get_parent().get_parent().get_parent()]
	var result = get_world_3d().direct_space_state.intersect_ray(query)

	var hit_pos = result.position if result else target

	var tracer_start = origin + direction * 2.0
	_draw_tracer(tracer_start, hit_pos, Color(1.0, 0.55, 0.05), 0.04, 0.6)

	if result:
		deal_damage(result.collider)
		_spawn_hit_effect(result.position)
		GoreManager.spawn_blood(result.position, result.normal, get_tree().current_scene)


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
	mat.emission_energy_multiplier = 5.0
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
	var hold := duration * 0.1
	var fade := duration * 0.9
	await get_tree().create_timer(hold).timeout
	if not is_instance_valid(tracer):
		return
	var tween = get_tree().create_tween()
	tween.tween_method(func(a: float):
		if is_instance_valid(mat):
			mat.albedo_color.a = a
			mat.emission_energy_multiplier = a * 5.0
	, 1.0, 0.0, fade)
	await get_tree().create_timer(fade + 0.05).timeout
	if is_instance_valid(tracer):
		tracer.queue_free()


func _spawn_hit_effect(pos: Vector3) -> void:
	var particles = GPUParticles3D.new()
	get_tree().current_scene.add_child(particles)
	particles.global_position = pos
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, 0)
	material.spread = 90.0
	material.initial_velocity_min = 1.0
	material.initial_velocity_max = 4.0
	material.gravity = Vector3(0, -9.8, 0)
	material.scale_min = 0.4
	material.scale_max = 0.9
	material.color = Color(1.0, 0.85, 0.5)
	var mesh_ref = SphereMesh.new()
	mesh_ref.radius = 0.08
	mesh_ref.height = 0.16
	particles.process_material = material
	particles.draw_pass_1 = mesh_ref
	particles.amount = 12
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.emitting = true
	await get_tree().create_timer(0.6).timeout
	particles.queue_free()


func _handle_kick(delta: float) -> void:
	if is_kicking:
		kick_timer -= delta
		var t = kick_timer / KICK_DURATION
		position.z = original_pos.z + KICK_AMOUNT * t
		if kick_timer <= 0:
			is_kicking = false
			position = original_pos


func _muzzle_flash() -> void:
	var flash = GPUParticles3D.new()
	add_child(flash)
	flash.position = Vector3(0, 0, -0.5)
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, -1)
	material.spread = 30.0
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 5.0
	material.scale_min = 0.8
	material.scale_max = 1.4
	material.color = Color(1.0, 0.7, 0.1)
	var mesh_ref = SphereMesh.new()
	mesh_ref.radius = 0.04
	mesh_ref.height = 0.08
	flash.process_material = material
	flash.draw_pass_1 = mesh_ref
	flash.amount = 16
	flash.lifetime = 0.1
	flash.one_shot = true
	flash.explosiveness = 1.0
	flash.emitting = true
	await get_tree().create_timer(0.2).timeout
	flash.queue_free()
