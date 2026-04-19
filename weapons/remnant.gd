extends BaseWeapon

@export var range: float = 200.0
@export var bullet_trace_scene: PackedScene

var muzzle_flash = null
var fire_sound: AudioStreamPlayer3D = null
var fire_point: Node3D = null
var animator = null

func _ready() -> void:
	weapon_name = "The Remnant"
	damage = 45.0
	fire_rate = 0.8
	magazine_size = 6
	reload_time = 2.2
	super()
	if has_node("FirePoint"): fire_point = $FirePoint
	if has_node("FirePoint/MuzzleFlash"): muzzle_flash = $FirePoint/MuzzleFlash
	if has_node("FireSound"): fire_sound = $FireSound
	if has_node("WeaponAnimator"): animator = $WeaponAnimator
	# Connect reload signal to animator
	on_reload_start.connect(func(): if animator: animator.remnant_reload())
	# Equip animation on ready
	if animator: animator.remnant_equip()

func _fire() -> void:
	current_ammo -= 1
	can_fire = false
	fire_timer.start()
	do_shake(0.18)
	if animator: animator.remnant_fire()
	if fire_sound:
		fire_sound.pitch_scale = randf_range(0.95, 1.05)
		fire_sound.play()
	var cam = get_camera()
	if cam:
		var forward = -cam.global_transform.basis.z
		var from = cam.global_position
		var to = from + forward * range
		if bullet_trace_scene and fire_point:
			var trace = bullet_trace_scene.instantiate()
			get_tree().current_scene.add_child(trace)
			trace.setup(fire_point.global_position, forward)
		var space = cam.get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [get_tree().get_first_node_in_group("player")]
		var result = space.intersect_ray(query)
		if result:
			var hit = result["collider"]
			var hit_pos = result["position"]
			if hit.has_method("take_damage"):
				hit.take_damage(calculate_damage())
				do_shake(0.28)
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
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0, -9.8, 0)
	mat.scale_min = 0.03
	mat.scale_max = 0.08
	mat.color = Color(0.6, 0.0, 0.0)
	var mesh_ref = SphereMesh.new()
	mesh_ref.radius = 0.04
	mesh_ref.height = 0.08
	particles.process_material = mat
	particles.draw_pass_1 = mesh_ref
	particles.amount = 12
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.emitting = true
	await get_tree().create_timer(0.6).timeout
	particles.queue_free()

# ── Called from player when taking damage ─────────────────────────────────────
func on_player_damaged() -> void:
	if animator: animator.trigger_damage()

# ── Called from player on landing ─────────────────────────────────────────────
func on_player_land(intensity: float = 1.0) -> void:
	if animator: animator.trigger_land(intensity)

# ── Called when ammo hits zero ────────────────────────────────────────────────
func on_ammo_empty() -> void:
	if animator: animator.set_empty(true)

func on_reload_complete() -> void:
	if animator: animator.set_empty(false)
