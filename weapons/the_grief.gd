extends BaseWeapon

@export var range: float = 60.0          # shorter range — shotgun
@export var pellet_count: int = 8        # rays per shot
@export var pellet_spread: float = 0.06  # spread cone per pellet
@export var pierce_count: int = 2        # how many enemies one pellet passes through

var muzzle_flash = null
var fire_sound: AudioStreamPlayer3D = null
var reload_sound: AudioStreamPlayer3D = null
var empty_sound: AudioStreamPlayer3D = null

func _ready() -> void:
	weapon_name = "The Grief"
	damage = 18.0           # per pellet — 8 pellets = 144 max damage on full hit
	fire_rate = 1.1         # slow. every shot is a decision.
	magazine_size = 6
	reload_time = 2.8       # long pump reload
	super()
	if has_node("FirePoint/MuzzleFlash"):
		muzzle_flash = $FirePoint/MuzzleFlash
	if has_node("FireSound"):
		fire_sound = $FireSound
	if has_node("ReloadSound"):
		reload_sound = $ReloadSound
	if has_node("EmptySound"):
		empty_sound = $EmptySound

func _fire() -> void:
	current_ammo -= 1
	can_fire = false
	fire_timer.start()

	# ── Heavy shake — this is the big gun ─────────────────────────────────────
	do_shake(1.46)

	# ── Sound ─────────────────────────────────────────────────────────────────
	if fire_sound:
		fire_sound.pitch_scale = randf_range(0.93, 1.0)
		fire_sound.play()

	# ── Fire all pellets ──────────────────────────────────────────────────────
	var cam = get_camera()
	if cam:
		var space = cam.get_world_3d().direct_space_state
		var forward = -cam.global_transform.basis.z
		var right = cam.global_transform.basis.x
		var up = cam.global_transform.basis.y
		var player_node = get_tree().get_first_node_in_group("player")

		for i in range(pellet_count):
			# Each pellet gets a random spread direction
			var spread_x = randf_range(-pellet_spread, pellet_spread)
			var spread_y = randf_range(-pellet_spread, pellet_spread)
			var direction = (forward + right * spread_x + up * spread_y).normalized()

			# Pierce — collect multiple hits along the ray
			var from = cam.global_position
			var hits_remaining = pierce_count
			var exclude = []
			if player_node:
				exclude.append(player_node)

			while hits_remaining > 0:
				var to = from + direction * range
				var query = PhysicsRayQueryParameters3D.create(from, to)
				query.exclude = exclude
				var result = space.intersect_ray(query)
				if not result:
					break
				var hit = result["collider"]
				var hit_pos = result["position"]
				if hit.has_method("take_damage"):
					hit.take_damage(calculate_damage())
				_spawn_hit_effect(hit_pos)
				# Move origin past this hit to pierce through
				exclude.append(hit)
				from = hit_pos + direction * 0.1
				hits_remaining -= 1

	if muzzle_flash:
		muzzle_flash.restart()
		muzzle_flash.emitting = true

	ammo_changed.emit(current_ammo, magazine_size)
	on_fire.emit()

	if current_ammo <= 0:
		on_empty.emit()
		if empty_sound:
			empty_sound.play()

func _on_reload_start() -> void:
	if reload_sound:
		reload_sound.play()

func _spawn_hit_effect(pos: Vector3) -> void:
	var particles = GPUParticles3D.new()
	get_tree().current_scene.add_child(particles)
	particles.global_position = pos
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 8.0
	mat.gravity = Vector3(0, -9.8, 0)
	mat.scale_min = 0.04
	mat.scale_max = 0.12
	mat.color = Color(0.7, 0.0, 0.0)
	var mesh_ref = SphereMesh.new()
	mesh_ref.radius = 0.05
	mesh_ref.height = 0.1
	particles.process_material = mat
	particles.draw_pass_1 = mesh_ref
	particles.amount = 18
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 0.97
	particles.emitting = true
	await get_tree().create_timer(0.7).timeout
	particles.queue_free()
