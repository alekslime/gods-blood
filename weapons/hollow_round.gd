extends BaseWeapon

@export var projectile_scene: PackedScene
@export var projectile_speed: float = 25.0

var fire_point: Node3D = null
var animator = null

func _ready() -> void:
	weapon_name = "The Hollow Round"
	damage = 65.0
	fire_rate = 1.4
	magazine_size = 4
	reload_time = 3.0
	super()
	# Nodes first
	if has_node("FirePoint"): fire_point = $FirePoint
	if has_node("FireSound"): fire_sound = $FireSound
	if has_node("ReloadSound"): reload_sound = $ReloadSound
	if has_node("EmptySound"): empty_sound = $EmptySound
	if has_node("WeaponAnimator"): animator = $WeaponAnimator
	# Streams after
	if fire_sound:
		fire_sound.stream = load("res://assets/audio/weapons/grenade_launcher_pop.mp3")
	if reload_sound:
		reload_sound.stream = load("res://assets/audio/weapons/reload.mp3")
	if empty_sound:
		empty_sound.stream = load("res://assets/audio/weapons/gun_empty_click.mp3")
	on_reload_start.connect(func(): if animator: animator.hollow_reload())
	if animator: animator.hollow_equip()

func _fire() -> void:
	current_ammo -= 1
	can_fire = false
	fire_timer.start()
	do_shake(0.22)
	if animator: animator.hollow_fire()
	if fire_sound:
		fire_sound.pitch_scale = randf_range(0.95, 1.05)
		fire_sound.play()
	if projectile_scene:
		var cam = get_camera()
		if cam:
			var forward = -cam.global_transform.basis.z
			var spawn_pos = fire_point.global_position if fire_point else cam.global_position
			var projectile = projectile_scene.instantiate()
			get_tree().current_scene.add_child(projectile)
			projectile.global_position = spawn_pos
			projectile.look_at(spawn_pos + forward, Vector3.UP)
			var player_node = get_tree().get_first_node_in_group("player")
			projectile.setup(forward, calculate_damage(), player_node)
	else:
		push_warning("Hollow Round: No projectile scene assigned!")
	ammo_changed.emit(current_ammo, magazine_size)
	on_fire.emit()
	if current_ammo <= 0:
		on_empty.emit()
		if empty_sound: empty_sound.play()

func _on_reload_start() -> void:
	if reload_sound: reload_sound.play()
