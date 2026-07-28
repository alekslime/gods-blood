extends MeshInstance3D
## Attach to each eye-bulge MeshInstance3D. Rotates the whole eyeball so its
## iris/pupil patch always faces the player -- this gives true 360-degree
## tracking. The old approach nudged the pupil within a small UV-space patch
## baked onto the sphere's front, which only ever worked in roughly a
## forward-facing cone -- no script value can move where the iris texture
## *is* on the model, so it could never see past ~90 degrees to the side.
## Rotating the geometry itself has no such limit.

@export var player: Node3D                  # drag the player node here (or auto-find below)
@export var track_speed: float = 4.0        # how fast the eye reorients toward the player (higher = snappier, more instant)

var _mat: ShaderMaterial


func _ready() -> void:
	_mat = get_active_material(0) as ShaderMaterial
	if _mat == null:
		push_warning("EyeController (%s): surface 0 has no ShaderMaterial using eye_wall.gdshader" % name)
	if player == null:
		# Same lookup convention as door_controller.gd's _get_audio()
		player = get_tree().get_root().find_child("Player", true, false)
	if player == null:
		push_warning("EyeController (%s): could not find a 'Player' node. Drag your player node into the exported 'player' field in the Inspector." % name)

	# Always fully open, no eyelid animation -- pupil_offset stays at zero
	# since the geometry rotating IS the "looking" now, not a texture offset.
	if _mat:
		_mat.set_shader_parameter("open_amount", 1.0)
		_mat.set_shader_parameter("pupil_offset", Vector2.ZERO)


func _process(delta: float) -> void:
	if player == null:
		return

	var to_player_dir := player.global_transform.origin - global_transform.origin
	if to_player_dir.length_squared() < 0.0001:
		return # player is essentially on top of the eye's origin, direction is undefined

	# Preserve the eye's current scale (these vary per-eye per your design notes)
	# -- Basis.looking_at() builds a pure rotation basis, so without this the
	# eye would snap back to scale 1 the moment it starts rotating.
	var current_scale := global_transform.basis.get_scale()
	var current_basis := global_transform.basis.orthonormalized()
	var target_basis := Basis.looking_at(to_player_dir, Vector3.UP)

	var new_basis := current_basis.slerp(target_basis, clampf(delta * track_speed, 0.0, 1.0))
	global_transform.basis = new_basis.scaled(current_scale)


## Kept for compatibility with any trigger areas already calling these --
## both are now no-ops since the eye is always open. Safe to leave in place.
func force_open() -> void:
	pass


func force_closed() -> void:
	pass


## Kept for compatibility -- no-op, since there's no eyelid animation anymore.
func set_stress(value: float) -> void:
	pass
