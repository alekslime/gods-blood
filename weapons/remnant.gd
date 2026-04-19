extends BaseWeapon

@export var range: float = 200.0

var muzzle_flash = null
var animation_player = null

func _ready() -> void:
	weapon_name = "The Remnant"
	damage = 45.0
	fire_rate = 0.8
	magazine_size = 6
	reload_time = 2.2
	super()
	if has_node("FirePoint/MuzzleFlash"):
		muzzle_flash = $FirePoint/MuzzleFlash
	if has_node("AnimationPlayer"):
		animation_player = $AnimationPlayer

func _fire() -> void:
	current_ammo -= 1
	can_fire = false
	fire_timer.start()

	# ── Screen shake ──────────────────────────────────────────────────────────
	do_shake(0.18)

	# ── Hitscan from camera ───────────────────────────────────────────────────
	var cam = get_camera()
	if cam:
		var space = cam.get_world_3d().direct_space_state
		var from = cam.global_position
		var to = from + (-cam.global_transform.basis.z * range)
		var query = PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [get_tree().get_first_node_in_group("player")]
		var result = space.intersect_ray(query)
		if result:
			var hit = result["collider"]
			var hit_pos = result["position"]
			if hit.has_method("take_damage"):
				hit.take_damage(calculate_damage())
				do_shake(0.28)  # extra shake on hit — feels impactful
			_spawn_hit_effect(hit_pos)

	if muzzle_flash:
		muzzle_flash.restart()
		muzzle_flash.emitting = true

	if animation_player and animation_player.has_animation("fire"):
		animation_player.stop()
		animation_player.play("fire")

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
