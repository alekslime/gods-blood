extends Area3D

enum Size { SMALL, MEDIUM, LARGE }
@export var size: Size = Size.SMALL

const HEAL_AMOUNTS = {
	Size.SMALL: 10.0,
	Size.MEDIUM: 25.0,
	Size.LARGE: 50.0,
}

const COLORS = {
	Size.SMALL:  Color(0.9, 0.2, 0.2),
	Size.MEDIUM: Color(0.9, 0.5, 0.1),
	Size.LARGE:  Color(1.0, 0.85, 0.1),
}

const SCALES = {
	Size.SMALL:  Vector3(0.18, 0.06, 0.18),
	Size.MEDIUM: Vector3(0.28, 0.08, 0.28),
	Size.LARGE:  Vector3(0.42, 0.10, 0.42),
}

const LIGHT_ENERGY = {
	Size.SMALL:  1.2,
	Size.MEDIUM: 2.0,
	Size.LARGE:  3.5,
}

var bob_time := 0.0
const BOB_SPEED := 2.2
const BOB_AMOUNT := 0.12
var base_y := 0.0
const SPIN_SPEED := 1.8

var collected := false

var drop_velocity := Vector3.ZERO
var is_dropping := false
const DROP_GRAVITY := 18.0

const MAGNET_RANGE := 3.5
const MAGNET_SPEED := 14.0
var player: CharacterBody3D = null
var is_magnetized := false

@export var lifetime := 18.0
var lifetime_timer := 0.0
const FADE_START := 4.0

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var light: OmniLight3D = $OmniLight3D
@onready var pickup_sound: AudioStreamPlayer = $PickupSound
@onready var col: CollisionShape3D = $CollisionShape3D

var mat: StandardMaterial3D = null

# Called by enemy BEFORE adding to scene tree
# This replaces direct size assignment from outside
var _pending_size: int = 0
var _pending_origin: Vector3 = Vector3.ZERO
var _should_drop: bool = false


func setup(p_size: int, origin: Vector3) -> void:
	_pending_size = p_size
	_pending_origin = origin
	_should_drop = true


func _ready() -> void:
	# Apply pending size set before _ready via setup()
	size = _pending_size as Size

	body_entered.connect(_on_body_entered)
	player = get_tree().get_first_node_in_group("player")
	bob_time = randf_range(0.0, TAU)
	_setup_visuals()

	if _should_drop:
		drop_from(_pending_origin)


func _setup_visuals() -> void:
	var color = COLORS[size]
	mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	mat.roughness = 0.2
	mat.metallic = 0.6
	mesh.set_surface_override_material(0, mat)
	mesh.scale = SCALES[size]
	light.light_color = color
	light.light_energy = LIGHT_ENERGY[size]
	light.omni_range = SCALES[size].x * 12.0


func _physics_process(delta: float) -> void:
	if collected:
		return

	if is_dropping:
		drop_velocity.y -= DROP_GRAVITY * delta
		global_position += drop_velocity * delta
		if global_position.y <= base_y:
			global_position.y = base_y
			is_dropping = false
			drop_velocity = Vector3.ZERO
		return

	lifetime_timer += delta
	var time_left = lifetime - lifetime_timer
	if time_left <= 0.0:
		queue_free()
		return

	if time_left <= FADE_START:
		var blink = sin(lifetime_timer * 12.0) > 0.0
		mesh.visible = blink
		light.visible = blink
	else:
		mesh.visible = true
		light.visible = true

	if player:
		var dist = global_position.distance_to(player.global_position)
		if dist <= MAGNET_RANGE:
			is_magnetized = true
		if is_magnetized:
			var dir = (player.global_position - global_position).normalized()
			global_position += dir * MAGNET_SPEED * delta
			return

	bob_time += delta * BOB_SPEED
	global_position.y = base_y + sin(bob_time) * BOB_AMOUNT
	rotate_y(SPIN_SPEED * delta)

	var pulse = 1.0 + sin(bob_time * 2.0) * 0.3
	mat.emission_energy_multiplier = 2.5 * pulse
	light.light_energy = LIGHT_ENERGY[size] * pulse


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and not collected:
		_collect(body)


func _collect(p: Node) -> void:
	collected = true
	p.heal(HEAL_AMOUNTS[size])
	pickup_sound.play()
	_spawn_collect_particles()
	mesh.visible = false
	light.visible = false
	col.disabled = true
	await pickup_sound.finished
	queue_free()


func drop_from(origin: Vector3) -> void:
	global_position = origin + Vector3(0, 0.6, 0)
	base_y = origin.y + 0.3
	is_dropping = true
	var angle = randf_range(0.0, TAU)
	var strength = randf_range(2.0, 5.0)
	drop_velocity = Vector3(cos(angle) * strength, 5.0, sin(angle) * strength)


func _spawn_collect_particles() -> void:
	var particles = GPUParticles3D.new()
	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position

	var pmat = ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 60.0
	pmat.initial_velocity_min = 2.0
	pmat.initial_velocity_max = 5.0
	pmat.gravity = Vector3(0, -6.0, 0)
	pmat.scale_min = 0.04
	pmat.scale_max = 0.12
	pmat.color = COLORS[size]

	var mesh_ref = SphereMesh.new()
	mesh_ref.radius = 0.04
	mesh_ref.height = 0.08

	particles.process_material = pmat
	particles.draw_pass_1 = mesh_ref
	particles.amount = 20
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.emitting = true

	await get_tree().create_timer(0.6).timeout
	particles.queue_free()
