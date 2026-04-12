extends Area3D

var direction: Vector3 = Vector3.FORWARD
var speed: float = 45.0
var damage: float = 55.0
var lifetime := 4.0
var hit_enemies: Array = []   # track pierced enemies so we don't double-hit

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var light: OmniLight3D = $OmniLight3D
@onready var hit_sound: AudioStreamPlayer = $HitSound

var mat: StandardMaterial3D = null


func setup(dir: Vector3, spd: float, dmg: float) -> void:
	direction = dir.normalized()
	speed = spd
	damage = dmg


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_setup_visuals()


func _setup_visuals() -> void:
	mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.9, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.9, 1.0)
	mat.emission_energy_multiplier = 4.0
	if mesh:
		mesh.set_surface_override_material(0, mat)
	if light:
		light.light_color = Color(0.6, 0.8, 1.0)
		light.light_energy = 3.0
		light.omni_range = 4.0


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	# Align mesh to travel direction
	look_at(global_position + direction, Vector3.UP)

	# Pulse light
	if light:
		light.light_energy = 3.0 + sin(Time.get_ticks_msec() * 0.02) * 1.0

	lifetime -= delta
	if lifetime <= 0.0:
		_despawn()


func _on_body_entered(body: Node) -> void:
	if hit_sound: hit_sound.play()
	if body.is_in_group("player"):
		return
	if body in hit_enemies:
		return

	if body.has_method("take_damage"):
		hit_enemies.append(body)
		body.take_damage(damage)
		_spawn_pierce_effect()
		# Don't destroy — keep going through (pierce)
	elif not body.is_in_group("enemy"):
		# Hit a wall or static object — stop
		_despawn()


func _on_area_entered(area: Node) -> void:
	# Handle hitboxes
	var parent = area.get_parent()
	if parent and parent.has_method("take_damage") and parent not in hit_enemies:
		hit_enemies.append(parent)
		parent.take_damage(damage)
		_spawn_pierce_effect()


func _spawn_pierce_effect() -> void:
	var particles = GPUParticles3D.new()
	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position

	var pmat = ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 60.0
	pmat.initial_velocity_min = 3.0
	pmat.initial_velocity_max = 8.0
	pmat.gravity = Vector3(0, -4.0, 0)
	pmat.scale_min = 0.05
	pmat.scale_max = 0.15
	pmat.color = Color(0.7, 0.9, 1.0)

	var mesh_ref = SphereMesh.new()
	mesh_ref.radius = 0.04
	mesh_ref.height = 0.08

	particles.process_material = pmat
	particles.draw_pass_1 = mesh_ref
	particles.amount = 16
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.emitting = true

	await get_tree().create_timer(0.5).timeout
	particles.queue_free()


func _despawn() -> void:
	_spawn_pierce_effect()
	queue_free()
