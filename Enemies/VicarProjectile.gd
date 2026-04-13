extends RigidBody3D

var speed := 10.0
var direction := Vector3.ZERO
var lifetime := 8.0
var damage := 18.0

func _ready() -> void:
	gravity_scale = 0.0
	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_on_body_entered)
	linear_velocity = direction * speed
	
	# Visible glowing red orb — no depth tricks
	var mesh_inst = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.05, 0.05)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.0, 0.0)
	mat.emission_energy_multiplier = 8.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.surface_set_material(0, mat)
	mesh_inst.mesh = sphere
	add_child(mesh_inst)

func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.take_damage(damage)
	queue_free()

func initialize(dir: Vector3, spd: float, dmg: float) -> void:
	direction = dir
	speed = spd
	damage = dmg
	if is_inside_tree():
		linear_velocity = direction * speed
