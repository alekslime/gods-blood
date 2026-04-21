class_name BaseEnemy
extends CharacterBody3D

# --- Stats (override in child scripts) ---
@export var max_health: float = 100.0
@export var move_speed: float = 5.0
@export var attack_damage: float = 10.0
@export var attack_range: float = 1.5
@export var attack_cooldown: float = 1.0
@export var gives_rage: bool = true
@export var rage_on_kill: float = 25.0

# --- Nodes (assigned in _ready) ---
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var hit_sound: AudioStreamPlayer3D = $HitSound
@onready var death_sound: AudioStreamPlayer3D = $DeathSound
@onready var attack_area: Area3D = $AttackArea

# --- State ---
var current_health: float
var is_dead: bool = false
var player: Node3D = null
var attack_timer: float = 0.0

const GRAVITY: float = 25.0

func _ready() -> void:
	current_health = max_health
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	attack_timer -= delta
	_update_navigation()
	_try_attack()
	move_and_slide()

func _update_navigation() -> void:
	if not player:
		return
	var dir = (player.global_position - global_position).normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed

func _try_attack() -> void:
	if not player or attack_timer > 0.0:
		return
	if global_position.distance_to(player.global_position) <= attack_range:
		attack_timer = attack_cooldown
		_do_attack()

func _do_attack() -> void:
	if player.has_method("take_damage"):
		player.take_damage(attack_damage)

func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_health -= amount
	if hit_sound and not hit_sound.playing:
		hit_sound.pitch_scale = randf_range(0.9, 1.1)
		hit_sound.play()
	if current_health <= 0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	# ULTRAKILL kill freeze
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.06 * 0.05).timeout
	Engine.time_scale = 1.0
	if gives_rage and player and player.has_method("add_rage"):
		player.add_rage(rage_on_kill)
	if death_sound:
		death_sound.play()
	$CollisionShape3D.set_deferred("disabled", true)
	await get_tree().create_timer(0.6).timeout
	queue_free()
