extends Node3D
# ================================================================
# MELEE SYSTEM
# Attach to a Node3D called "MeleeSystem" as child of Camera3D
# Add an input action "melee" mapped to F in Project Settings
# ================================================================

const MELEE_RANGE := 2.2
const MELEE_DAMAGE_FIRST := 35.0     # first hit
const MELEE_DAMAGE_SECOND := 60.0    # second hit / finisher
const EXECUTE_THRESHOLD := 0.30      # below 30% HP = one hit kill
const COMBO_WINDOW := 0.55           # seconds to land second hit after first
const MELEE_COOLDOWN := 0.6          # cooldown after full combo

var combo_step := 0                  # 0 = ready, 1 = first hit landed, waiting for second
var combo_timer := 0.0
var cooldown_timer := 0.0
var is_attacking := false
var attack_timer := 0.0
const ATTACK_DURATION := 0.18        # how long the lunge/animation takes

var player: CharacterBody3D = null
var camera: Camera3D = null

# Hand punch offset — drives the hand forward on attack
var punch_offset := 0.0
const PUNCH_AMOUNT := 0.12
const PUNCH_SPEED := 22.0


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	camera = get_parent()  # this node is child of Camera3D


func _process(delta: float) -> void:
	# Tick timers
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			# Missed the combo window — reset
			combo_step = 0

	if is_attacking:
		attack_timer -= delta
		punch_offset = move_toward(punch_offset, 0.0, delta * PUNCH_SPEED)
		if attack_timer <= 0.0:
			is_attacking = false
	else:
		punch_offset = move_toward(punch_offset, 0.0, delta * PUNCH_SPEED * 0.5)

	# Drive hand forward — find Hand sibling and push it
	var hand = camera.get_node_or_null("Hand")
	if hand:
		hand.position.z -= punch_offset * delta * 60.0

	# Input
	if Input.is_action_just_pressed("melee") and cooldown_timer <= 0.0:
		_do_melee()


func _do_melee() -> void:
	if is_attacking:
		return

	is_attacking = true
	attack_timer = ATTACK_DURATION
	punch_offset = PUNCH_AMOUNT

	# Camera shake
	if player and player.has_method("shake"):
		player.shake(0.04)

	# Find target in front of player
	var target = _get_melee_target()

	if target == null:
		# Whiff — still plays the animation, nothing happens
		_play_whiff()
		if combo_step == 1:
			combo_step = 0
		else:
			combo_timer = COMBO_WINDOW
			combo_step = 1
		return

	var target_health = target.get("current_health")
	var target_max = target.get("max_health")

	if target_health == null or target_max == null:
		return

	var health_percent = target_health / target_max

	if health_percent <= EXECUTE_THRESHOLD:
		# EXECUTE — one hit kill regardless of combo step
		_execute(target)
		combo_step = 0
		cooldown_timer = MELEE_COOLDOWN
	elif combo_step == 0:
		# First hit
		_first_hit(target)
		combo_step = 1
		combo_timer = COMBO_WINDOW
	elif combo_step == 1:
		# Second hit — finisher
		_second_hit(target)
		combo_step = 0
		cooldown_timer = MELEE_COOLDOWN


func _first_hit(target: Node) -> void:
	target.take_damage(MELEE_DAMAGE_FIRST)
	_hit_effects(target, false)


func _second_hit(target: Node) -> void:
	target.take_damage(MELEE_DAMAGE_SECOND)
	_hit_effects(target, true)


func _execute(target: Node) -> void:
	# Instant kill — deal massive damage
	target.take_damage(9999.0)
	_hit_effects(target, true)

	# Extra dramatic effects on execute
	if player and player.has_method("shake"):
		player.shake(0.12)

	# Hitstop — longer for execute
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.09).timeout
	Engine.time_scale = 1.0

	# Gold flash — same as fire regen, divine power
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("flash_fire_regen"):
		hud.flash_fire_regen()

	# Rage on execute
	if player and player.has_method("add_rage"):
		player.add_rage(20.0)


func _hit_effects(target: Node, is_kill: bool) -> void:
	# Hitstop
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.05 if not is_kill else 0.07).timeout
	Engine.time_scale = 1.0

	# Hitmarker
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		var crosshair = _get_crosshair()
		if crosshair:
			if is_kill:
				crosshair.on_kill()
			else:
				crosshair.on_hit()

	# Rage on hit
	if player and player.has_method("add_rage"):
		player.add_rage(5.0)


func _play_whiff() -> void:
	# Whoosh sound placeholder — add AudioStreamPlayer named WhiffSound as child
	var whiff = get_node_or_null("WhiffSound")
	if whiff:
		whiff.play()


func _get_melee_target() -> Node:
	if camera == null:
		return null

	# Raycast from camera center
	var space = player.get_world_3d().direct_space_state
	var origin = camera.global_position
	var direction = -camera.global_transform.basis.z
	var end = origin + direction * MELEE_RANGE

	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [player.get_rid()]
	query.collision_mask = 0xFFFFFFFF

	var result = space.intersect_ray(query)
	if result.is_empty():
		return null

	var collider = result.collider
	if collider and collider.has_method("take_damage"):
		return collider

	# Check parent too — hitbox might be child of enemy
	if collider and collider.get_parent() and collider.get_parent().has_method("take_damage"):
		return collider.get_parent()

	return null


func _get_crosshair() -> Node:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		for child in hud.get_children():
			if child.has_method("on_hit"):
				return child
	return null
