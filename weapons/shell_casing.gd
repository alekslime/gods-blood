extends RigidBody3D

@onready var life_timer: Timer = $LifeTimer
@onready var clink_sound: AudioStreamPlayer = $ClinkSound

const LIFETIME := 1.5
const MIN_IMPACT_VELOCITY := 0.8  # don't play sound on tiny bumps
var has_clinked := false           # only play on first impact

func _ready() -> void:
	life_timer.wait_time = LIFETIME
	life_timer.one_shot = true
	life_timer.timeout.connect(_on_expire)
	life_timer.start()
	body_entered.connect(_on_body_entered)
	contact_monitor = true
	max_contacts_reported = 1
	angular_velocity = Vector3(
		randf_range(-20.0, 20.0),
		randf_range(-20.0, 20.0),
		randf_range(-20.0, 20.0)
	)


func _on_body_entered(body: Node) -> void:
	if has_clinked:
		return
	if linear_velocity.length() < MIN_IMPACT_VELOCITY:
		return
	has_clinked = true
	if clink_sound:
		clink_sound.pitch_scale = randf_range(0.85, 1.15)
		clink_sound.play()


func _on_expire() -> void:
	var mesh = get_node_or_null("MeshInstance3D")
	if not mesh:
		queue_free()
		return
	var mat = mesh.get_active_material(0)
	if mat:
		mat = mat.duplicate()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.set_surface_override_material(0, mat)
		var tween = get_tree().create_tween()
		tween.tween_method(func(a: float):
			if is_instance_valid(mat):
				mat.albedo_color.a = a
		, 1.0, 0.0, 0.4)
	await get_tree().create_timer(0.45).timeout
	if is_instance_valid(self):
		queue_free()
