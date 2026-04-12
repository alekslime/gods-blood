extends Area3D

# Set this in the Inspector for each medkit you place in the level
@export var heal_amount: float = 25.0

# --- BOB & SPIN ---
var bob_time := 0.0
const BOB_SPEED := 2.0
const BOB_AMOUNT := 0.1
const SPIN_SPEED := 1.5
var base_y := 0.0

# --- MAGNET ---
const MAGNET_RANGE := 3.5
const MAGNET_SPEED := 14.0
var is_magnetized := false

# --- COLLECTED ---
var collected := false

# --- NODES ---
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var light: OmniLight3D = $OmniLight3D
@onready var col: CollisionShape3D = $CollisionShape3D
@onready var pickup_sound: AudioStreamPlayer = $PickupSound

var player: CharacterBody3D = null


func _ready() -> void:
	add_to_group("pickup")
	body_entered.connect(_on_body_entered)
	player = get_tree().get_first_node_in_group("player")
	base_y = global_position.y
	bob_time = randf_range(0.0, TAU)


func _physics_process(delta: float) -> void:
	if collected or player == null:
		return

	# Magnet
	var dist = global_position.distance_to(player.global_position)
	if dist <= MAGNET_RANGE:
		is_magnetized = true
	if is_magnetized:
		var dir = (player.global_position - global_position).normalized()
		global_position += dir * MAGNET_SPEED * delta
		return

	# Bob
	bob_time += delta * BOB_SPEED
	global_position.y = base_y + sin(bob_time) * BOB_AMOUNT

	# Spin
	rotate_y(SPIN_SPEED * delta)

	# Light pulse
	if light:
		light.light_energy = 1.5 + sin(bob_time * 2.0) * 0.4


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and not collected:
		_collect(body)


func _collect(p: Node) -> void:
	collected = true
	if p.has_method("heal"):
		p.heal(heal_amount)
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
