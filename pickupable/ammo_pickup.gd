extends Area3D

# Set in Inspector — how many shells this pickup gives
@export var shells: int = 6

var collected := false
var bob_time := 0.0
const BOB_SPEED := 2.0
const BOB_AMOUNT := 0.1
const SPIN_SPEED := 2.0
const MAGNET_RANGE := 3.5
const MAGNET_SPEED := 14.0
const LIFETIME := 20.0
var lifetime_timer := 0.0
var base_y := 0.0
var is_magnetized := false
var player = null

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var light: OmniLight3D = $OmniLight3D
@onready var col: CollisionShape3D = $CollisionShape3D
@onready var pickup_sound: AudioStreamPlayer = $PickupSound

var mat: StandardMaterial3D = null


func _ready() -> void:
	add_to_group("pickup")
	body_entered.connect(_on_body_entered)
	player = get_tree().get_first_node_in_group("player")
	base_y = global_position.y
	bob_time = randf_range(0.0, TAU)
	_setup_visuals()


func _setup_visuals() -> void:
	mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.7, 0.1)   # gold/brass shell color
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.7, 0.1)
	mat.emission_energy_multiplier = 2.0
	mat.roughness = 0.3
	mat.metallic = 0.8
	mesh.set_surface_override_material(0, mat)
	if light:
		light.light_color = Color(0.9, 0.7, 0.1)
		light.light_energy = 1.5
		light.omni_range = 2.5


func _physics_process(delta: float) -> void:
	if collected:
		return

	lifetime_timer += delta
	var time_left = LIFETIME - lifetime_timer
	if time_left <= 0.0:
		queue_free()
		return

	# Blink when about to expire
	if time_left <= 4.0:
		mesh.visible = sin(lifetime_timer * 12.0) > 0.0
	else:
		mesh.visible = true

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
	if light:
		light.light_energy = 1.5 + sin(bob_time * 2.0) * 0.4


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and not collected:
		_collect(body)


func _collect(p: Node) -> void:
	collected = true
	# Find shotgun in weapon manager and add ammo
	var wm = p.get("weapon_manager")
	if wm:
		for weapon in wm.weapons:
			if weapon.has_method("add_ammo"):
				weapon.add_ammo(shells)
				break
	mesh.visible = false
	if light:
		light.visible = false
	col.set_deferred("disabled", true)
	if pickup_sound:
		pickup_sound.play()
		await pickup_sound.finished
	else:
		await get_tree().create_timer(0.2).timeout
	queue_free()
