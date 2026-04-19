extends Node3D

var speed: float = 25.0
var damage: float = 65.0
var implosion_radius: float = 12.0
var pull_force: float = 40.0
var lifetime: float = 6.0
var elapsed: float = 0.0
var direction: Vector3 = Vector3.ZERO
var embedded: bool = false
var embed_timer: float = 1.5
var player_node = null

@onready var mesh: MeshInstance3D = $MeshInstance3D

func setup(dir: Vector3, dmg: float, p_node) -> void:
	direction = dir.normalized()
	damage = dmg
	player_node = p_node

func _process(delta: float) -> void:
	if embedded:
		embed_timer -= delta
		elapsed += delta
		if mesh:
			var pulse = (sin(elapsed * 20.0) + 1.0) / 2.0
			mesh.scale = Vector3.ONE * lerp(0.8, 1.4, pulse)
		if embed_timer <= 0.0:
			_implode()
		return

	elapsed += delta
	if elapsed >= lifetime:
		queue_free()
		return

	global_position += direction * speed * delta

func _physics_process(_delta: float) -> void:
	if embedded:
		return
	var space = get_world_3d().direct_space_state
	var query = PhysicsPointQueryParameters3D.new()
	query.position = global_position
	query.exclude = [player_node] if player_node else []
	query.collision_mask = 0xFFFFFFFF
	var results = space.intersect_point(query, 1)
	if results.size() > 0:
		_embed()

func _embed() -> void:
	embedded = true
	direction = Vector3.ZERO

func _implode() -> void:
	# Screen shake — enormous
	if player_node and player_node.has_method("shake"):
		player_node.shake(1.2)

	# Pull and damage everything in radius
	var space = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var shape = SphereShape3D.new()
	shape.radius = implosion_radius
	query.shape = shape
	query.transform = global_transform
	var results = space.intersect_shape(query)
	for r in results:
		var body = r["collider"]
		if body == player_node:
			continue
		if body is CharacterBody3D:
			var pull_dir = (global_position - body.global_position).normalized()
			body.velocity += pull_dir * pull_force
		if body.has_method("take_damage"):
			body.take_damage(damage)

	_spawn_implosion_effect()
	queue_free()

func _spawn_implosion_effect() -> void:
	var pos = global_position

	# ── Wave 1 — massive inward suck (dark void particles) ───────────────────
	var suck = GPUParticles3D.new()
	get_tree().current_scene.add_child(suck)
	suck.global_position = pos
	var mat1 = ParticleProcessMaterial.new()
	mat1.spread = 180.0
	mat1.initial_velocity_min = 30.0
	mat1.initial_velocity_max = 60.0
	mat1.radial_accel_min = -80.0
	mat1.radial_accel_max = -50.0
	mat1.gravity = Vector3.ZERO
	mat1.scale_min = 0.1
	mat1.scale_max = 0.5
	mat1.color = Color(0.05, 0.0, 0.15)
	var m1 = SphereMesh.new()
	m1.radius = 0.1
	m1.height = 0.2
	suck.process_material = mat1
	suck.draw_pass_1 = m1
	suck.amount = 120
	suck.lifetime = 0.4
	suck.one_shot = true
	suck.explosiveness = 0.99
	suck.emitting = true

	# ── Wave 2 — enormous outward explosion (red/black) ──────────────────────
	await get_tree().create_timer(0.15).timeout
	var blast = GPUParticles3D.new()
	get_tree().current_scene.add_child(blast)
	blast.global_position = pos
	var mat2 = ParticleProcessMaterial.new()
	mat2.spread = 180.0
	mat2.initial_velocity_min = 20.0
	mat2.initial_velocity_max = 55.0
	mat2.radial_accel_min = 30.0
	mat2.radial_accel_max = 60.0
	mat2.gravity = Vector3(0, -4.0, 0)
	mat2.scale_min = 0.2
	mat2.scale_max = 1.2
	mat2.color = Color(0.8, 0.0, 0.0)
	var m2 = SphereMesh.new()
	m2.radius = 0.15
	m2.height = 0.3
	blast.process_material = mat2
	blast.draw_pass_1 = m2
	blast.amount = 180
	blast.lifetime = 1.2
	blast.one_shot = true
	blast.explosiveness = 0.99
	blast.emitting = true

	# ── Wave 3 — dark debris chunks ──────────────────────────────────────────
	var debris = GPUParticles3D.new()
	get_tree().current_scene.add_child(debris)
	debris.global_position = pos
	var mat3 = ParticleProcessMaterial.new()
	mat3.spread = 180.0
	mat3.initial_velocity_min = 8.0
	mat3.initial_velocity_max = 25.0
	mat3.radial_accel_min = 5.0
	mat3.radial_accel_max = 15.0
	mat3.gravity = Vector3(0, -12.0, 0)
	mat3.scale_min = 0.15
	mat3.scale_max = 0.6
	mat3.color = Color(0.1, 0.0, 0.0)
	var m3 = BoxMesh.new()
	m3.size = Vector3(0.2, 0.2, 0.2)
	debris.process_material = mat3
	debris.draw_pass_1 = m3
	debris.amount = 60
	debris.lifetime = 2.0
	debris.one_shot = true
	debris.explosiveness = 0.95
	debris.emitting = true

	# ── Cleanup ───────────────────────────────────────────────────────────────
	await get_tree().create_timer(2.5).timeout
	suck.queue_free()
	blast.queue_free()
	debris.queue_free()
