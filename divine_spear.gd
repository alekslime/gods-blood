extends BaseWeapon

@export var spear_scene: PackedScene
@onready var throw_sound: AudioStreamPlayer = $ThrowSound
@onready var windup_sound: AudioStreamPlayer = $WindupSound
@onready var hit_sound: AudioStreamPlayer = $HitSound
@onready var ads_sound: AudioStreamPlayer = $AdsSound

const SPEAR_SPEED := 45.0
const WINDUP_TIME := 0.35

var is_winding_up := false
var windup_timer := 0.0
var charge_light: OmniLight3D = null

var original_pos := Vector3.ZERO
var recoil_offset := Vector3.ZERO
const RECOIL_KICK := Vector3(0, 0.06, 0.18)
const RECOIL_RETURN_SPEED := 6.0


func _ready() -> void:
	weapon_name = "Divine Spear"
	damage = 55.0
	fire_rate = 1.8
	ammo_current = 999
	ammo_max = 999
	is_infinite_ammo = true
	original_pos = position
	super._ready()

	charge_light = OmniLight3D.new()
	charge_light.light_color = Color(0.6, 0.8, 1.0)
	charge_light.light_energy = 0.0
	charge_light.omni_range = 3.0
	add_child(charge_light)


func _process(delta: float) -> void:
	super._process(delta)
	if is_winding_up:
		windup_timer -= delta
		if charge_light:
			charge_light.light_energy = lerp(0.0, 6.0, 1.0 - (windup_timer / WINDUP_TIME))
		if windup_timer <= 0.0:
			is_winding_up = false
			_throw_spear()
	else:
		if charge_light:
			charge_light.light_energy = move_toward(charge_light.light_energy, 0.0, 12.0 * delta)


func _physics_process(delta: float) -> void:
	recoil_offset = recoil_offset.lerp(Vector3.ZERO, RECOIL_RETURN_SPEED * delta)
	position = original_pos + recoil_offset


func fire() -> void:
	is_winding_up = true
	windup_timer = WINDUP_TIME


func _throw_spear() -> void:
	if throw_sound:
		throw_sound.play()

	recoil_offset = RECOIL_KICK

	if spear_scene == null:
		push_warning("Divine Spear: assign SpearProjectile.tscn in Inspector!")
		return

	var cam = get_viewport().get_camera_3d()
	var spear = spear_scene.instantiate()
	get_tree().current_scene.add_child(spear)
	spear.global_position = cam.global_position + cam.global_transform.basis * Vector3(0, 0, -1.5)
	spear.global_transform.basis = cam.global_transform.basis
	spear.setup(-cam.global_transform.basis.z, SPEAR_SPEED, damage)

	var from = cam.global_position + (-cam.global_transform.basis.z) * 2.0
	var to = cam.global_position + (-cam.global_transform.basis.z) * 80.0
	_draw_tracer(from, to, Color(0.4, 0.85, 1.0), 0.07, 1.0)


func _draw_tracer(from: Vector3, to: Vector3, color: Color, thickness: float, duration: float) -> void:
	var length = from.distance_to(to)
	if length < 0.5:
		return
	var tracer = MeshInstance3D.new()
	get_tree().current_scene.add_child(tracer)
	var box = BoxMesh.new()
	box.size = Vector3(thickness, thickness, length)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 1.0)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 6.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	box.surface_set_material(0, mat)
	tracer.mesh = box
	tracer.global_position = (from + to) / 2.0
	var d = (to - from).normalized()
	var up = Vector3.UP if abs(d.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var right = d.cross(up).normalized()
	var nup = right.cross(d).normalized()
	tracer.global_transform.basis = Basis(right, nup, -d)
	var hold := duration * 0.15
	var fade := duration * 0.85
	await get_tree().create_timer(hold).timeout
	if not is_instance_valid(tracer):
		return
	var tween = get_tree().create_tween()
	tween.tween_method(func(a: float):
		if is_instance_valid(mat):
			mat.albedo_color.a = a
			mat.emission_energy_multiplier = a * 6.0
	, 1.0, 0.0, fade)
	await get_tree().create_timer(fade + 0.05).timeout
	if is_instance_valid(tracer):
		tracer.queue_free()
