extends BaseWeapon

@export var range: float = 150.0
@export var bullet_trace_scene: PackedScene

const SPREAD_MIN: float = 0.01
const SPREAD_MAX: float = 0.09
const SPREAD_BUILD_RATE: float = 0.6
const SPREAD_DECAY_RATE: float = 2.5
var current_spread: float = SPREAD_MIN
const SHAKE_MIN: float = 0.04
const SHAKE_MAX: float = 0.14
var fire_held_timer: float = 0.0

var muzzle_flash = null
var fire_sound: AudioStreamPlayer3D = null
var fire_point: Node3D = null
var animator = null

func _ready() -> void:
	weapon_name = "Ashen Repeater"
	damage = 12.0
	fire_rate = 0.1
	magazine_size = 30
	reload_time = 1.8
	super()
	if has_node("FirePoint"): fire_point = $FirePoint
	if has_node("FirePoint/MuzzleFlash"): muzzle_flash = $FirePoint/MuzzleFlash
	if has_node("FireSound"): fire_sound = $FireSound
	if has_node("WeaponAnimator"): animator = $WeaponAnimator
	on_reload_start.connect(func(): if animator: animator.ashen_reload())
	if animator: animator.ashen_equip()

func _process(delta: float) -> void:
	if visible and Input.is_action_pressed("fire"):
		fire_held_timer += delta
		current_spread = clamp(current_spread + SPREAD_BUILD_RATE * delta, SPREAD_MIN, SPREAD_MAX)
		try_fire()
	else:
		fire_held_timer = 0.0
		current_spread = move_toward(current_spread, SPREAD_MIN, SPREAD_DECAY_RATE * delta)

func _fire() -> void:
	current_ammo -= 1
	can_fire = false
	fire_timer.start()
	var shake_amount = lerp(SHAKE_MIN, SHAKE_MAX, fire_held_timer / 2.0)
	do_shake(shake_amount)
	if animator: animator.ashen_fire()
	if fire_sound:
		fire_sound.pitch_scale = randf_range(0.92, 1.08)
		fire_sound.play()
	var cam = get_camera()
	if cam:
		var right = cam.global_transform.basis.x
		var up = cam.global_transform.basis.y
		var forward = -cam.global_transform.basis.z
		var spread_x = randf_range(-current_spread, current_spread)
		var spread_y = randf_range(-current_spread, current_spread)
		var direction = (forward + right * spread_x + up * spread_y).normalized()
		var from = cam.global_position
		var to = from + direction * range
		if bullet_trace_scene and fire_point:
			var trace = bullet_trace_scene.instantiate()
			get_tree().current_scene.add_child(trace)
			trace.setup(fire_point.global_position, direction)
		var space = cam.get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [get_tree().get_first_node_in_group("player")]
		var result = space.intersect_ray(query)
		if result:
			var hit = result["collider"]
			var hit_pos = result["position"]
			if hit.has_method("take_damage"):
				hit.take_damage(calculate_damage())
				do_shake(shake_amount + 0.06)
			_spawn_hit_effect(hit_pos)
	if muzzle_flash:
		muzzle_flash.restart()
		muzzle_flash.emitting = true
	ammo_changed.emit(current_ammo, magazine_size)
	on_fire.emit()
	if current_ammo <= 0:
		on_empty.emit()

func _spawn_hit_effect(pos: Vector3) -> void:
	var particles = GPUParticles3D.new()
	get_tree().current_scene.add_child(particles)
	particles.global_position = pos
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 1.5
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3(0, -9.8, 0)
	mat.scale_min = 0.02
	mat.scale_max = 0.05
	mat.color = Color(0.5, 0.0, 0.0)
	var mesh_ref = SphereMesh.new()
	mesh_ref.radius = 0.03
	mesh_ref.height = 0.06
	particles.process_material = mat
	particles.draw_pass_1 = mesh_ref
	particles.amount = 6
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.emitting = true
	await get_tree().create_timer(0.5).timeout
	particles.queue_free()
