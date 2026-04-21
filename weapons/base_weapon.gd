class_name BaseWeapon
extends Node3D

# ── Identity ──────────────────────────────────────────────────────────────────
@export var weapon_name: String = ""

# ── Stats (override per weapon) ──────────────────────────────────────────────
@export var damage: float = 10.0
@export var fire_rate: float = 1.0
@export var magazine_size: int = 6
@export var reload_time: float = 1.5

# ── ADS ───────────────────────────────────────────────────────────────────────
@export var ads_fov_multiplier: float = 0.65
var is_ads: bool = false

# ── Crit ──────────────────────────────────────────────────────────────────────
const CRIT_CHANCE: float = 0.15
const CRIT_MULTIPLIER: float = 3.0

# ── State ─────────────────────────────────────────────────────────────────────
var current_ammo: int
var can_fire: bool = true
var is_reloading: bool = false

# ── Signals ───────────────────────────────────────────────────────────────────
signal ammo_changed(current: int, maximum: int)
signal on_fire
signal on_reload_start
signal on_reload_end
signal on_empty

# ── References ────────────────────────────────────────────────────────────────
@onready var fire_timer: Timer = $FireTimer
@onready var reload_timer: Timer = $ReloadTimer

# ── Audio (assigned in child _ready()) ────────────────────────────────────────
var fire_sound: AudioStreamPlayer3D = null
var reload_sound: AudioStreamPlayer3D = null
var empty_sound: AudioStreamPlayer3D = null

# ── Player reference for screen shake ─────────────────────────────────────────
var player = null

func _ready() -> void:
	current_ammo = magazine_size
	fire_timer.wait_time = fire_rate
	fire_timer.one_shot = true
	reload_timer.wait_time = reload_time
	reload_timer.one_shot = true
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	reload_timer.timeout.connect(_on_reload_timer_timeout)
	# Grab player reference for screen shake
	player = get_tree().get_first_node_in_group("player")

func _on_fire_timer_timeout() -> void:
	can_fire = true

func _on_reload_timer_timeout() -> void:
	current_ammo = magazine_size
	is_reloading = false
	can_fire = true
	ammo_changed.emit(current_ammo, magazine_size)
	on_reload_end.emit()

# ── Public API ────────────────────────────────────────────────────────────────
func try_fire() -> void:
	if is_reloading:
		return
	if not can_fire:
		return
	if current_ammo <= 0:
		start_reload()
		return
	_fire()

func start_reload() -> void:
	if is_reloading or current_ammo == magazine_size:
		return
	is_reloading = true
	can_fire = false
	on_reload_start.emit()
	reload_timer.start()

func start_ads() -> void:
	is_ads = true

func stop_ads() -> void:
	is_ads = false

func drain_fuel(_amount: float) -> void:
	pass

func get_camera() -> Camera3D:
	return get_viewport().get_camera_3d()

# ── Screen shake helper ───────────────────────────────────────────────────────
func do_shake(intensity: float) -> void:
	if player and player.has_method("shake"):
		player.shake(intensity)

# ── Damage calc ───────────────────────────────────────────────────────────────
func calculate_damage() -> float:
	if randf() < CRIT_CHANCE:
		return damage * CRIT_MULTIPLIER
	return damage

# ── Override in child weapons ─────────────────────────────────────────────────
func _fire() -> void:
	pass
