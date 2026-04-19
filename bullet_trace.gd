extends Node3D

@export var speed: float = 80.0
@export var lifetime: float = 0.08  # short — traces are brief
@export var fade: bool = true

var elapsed: float = 0.0
var mesh_instance: MeshInstance3D = null
var material: StandardMaterial3D = null

func _ready() -> void:
	mesh_instance = get_child(0)
	if mesh_instance and mesh_instance.get_surface_override_material_count() > 0:
		material = mesh_instance.get_surface_override_material(0)
	elif mesh_instance:
		material = mesh_instance.mesh.surface_get_material(0)

func setup(from: Vector3, direction: Vector3) -> void:
	global_position = from + direction * 0.5
	look_at(from + direction * 10.0, Vector3.UP)

func _process(delta: float) -> void:
	elapsed += delta
	# Move forward
	global_position += -global_transform.basis.z * speed * delta
	# Fade out
	if fade and material:
		var alpha = 1.0 - (elapsed / lifetime)
		material.albedo_color.a = clamp(alpha, 0.0, 1.0)
	if elapsed >= lifetime:
		queue_free()
