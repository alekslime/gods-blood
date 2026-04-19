class_name TheEcho
extends BaseEnemy

# The Echo — ASEL's dead wife. Ghost. Contact damage only.
# Gives NO rage on kill. Pre-Vicar levels only.

@export var phase_alpha: float = 0.4  # how transparent she looks

func _ready() -> void:
	super()
	gives_rage = false         # confirmed in handoff — NO rage on kill
	max_health = 60.0
	current_health = max_health
	move_speed = 6.5           # faster than a normal human — unsettling
	attack_damage = 18.0       # hurts when she touches you
	attack_range = 1.0         # true contact only
	attack_cooldown = 0.8
	# Make her semi-transparent
	var mesh = $MeshInstance3D
	if mesh:
		var mat = mesh.get_active_material(0)
		if mat:
			mat = mat.duplicate()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = phase_alpha
			mat.albedo_color = Color(0.6, 0.7, 1.0, phase_alpha)  # cold blue tint
			mat.emission_enabled = true
			mat.emission = Color(0.3, 0.4, 1.0)  # faint cold blue glow
			mat.emission_energy_multiplier = 0.6
			mesh.set_surface_override_material(0, mat)

func die() -> void:
	# No rage, no loud death — she just fades
	is_dead = true
	$CollisionShape3D.set_deferred("disabled", true)
	if death_sound:
		death_sound.play()
	# Fade out instead of popping
	var mesh = $MeshInstance3D
	if mesh:
		var tween = create_tween()
		tween.tween_property(mesh, "transparency", 1.0, 0.8)
	await get_tree().create_timer(0.9).timeout
	queue_free()
