extends CharacterBody3D

# --- PHASES ---
enum Phase { SERMON, DOUBT, DISSOLUTION }
var current_phase: Phase = Phase.SERMON
var phase_started := false

# --- HEALTH ---
var max_health := 800.0
var current_health := 800.0
var is_dead := false

# --- PHASE THRESHOLDS ---
const PHASE2_THRESHOLD = 0.60  # 60% HP → Phase 2
const PHASE3_THRESHOLD = 0.30  # 30% HP → Phase 3

# --- NODES ---
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var projectile_spawn: Marker3D = $ProjectileSpawn
@onready var decay_particles: GPUParticles3D = $DecayParticles
@onready var vicar_voice: AudioStreamPlayer = $VicarVoice

# --- PLAYER REF ---
var player: CharacterBody3D = null

# --- ATTACK TIMERS ---
var attack_timer := 0.0
var shockwave_timer := 0.0

# --- PHASE 1 VALUES ---
const P1_MOVE_SPEED := 3.5
const P1_ATTACK_RATE := 2.2      # seconds between projectile volleys
const P1_SHOCKWAVE_RATE := 6.0
const P1_PROJECTILE_COUNT := 6

# --- PHASE 2 VALUES ---
const P2_MOVE_SPEED := 6.5
const P2_ATTACK_RATE := 1.4
const P2_SHOCKWAVE_RATE := 4.0
const P2_PROJECTILE_COUNT := 9
const P2_CHARGE_SPEED := 18.0
var is_charging := false
var charge_timer := 0.0
const CHARGE_DURATION := 0.6
var charge_direction := Vector3.ZERO
var charge_cooldown := 0.0
const CHARGE_COOLDOWN := 5.0
var summon_cooldown := 0.0
const SUMMON_COOLDOWN := 12.0

# --- PHASE 3 VALUES ---
const P3_MOVE_SPEED := 5.0
const P3_ATTACK_RATE := 0.7
const P3_SHOCKWAVE_RATE := 2.5
const P3_PROJECTILE_COUNT := 14

# --- GRAVITY ---
const GRAVITY := 25.0

# --- IFRAMES on phase transition ---
var transition_locked := false


func _ready() -> void:
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	attack_timer = 1.5  # brief delay before first attack
	_start_phase(Phase.SERMON)


func _physics_process(delta: float) -> void:
	if is_dead or transition_locked:
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	_check_phase_transition()
	_handle_phase(delta)
	move_and_slide()


# --- PHASE MANAGEMENT ---

func _start_phase(phase: Phase) -> void:
	current_phase = phase
	match phase:
		Phase.SERMON:
			# Arrogant, slow, deliberate
			decay_particles.emitting = false
		Phase.DOUBT:
			# Cracking — emit particles, speed up
			decay_particles.emitting = true
			decay_particles.amount = 24
			charge_cooldown = 2.0  # short delay before first charge
			summon_cooldown = 4.0
		Phase.DISSOLUTION:
			# Coming apart — particles heavy, desperate
			decay_particles.amount = 64
			decay_particles.lifetime = 1.8


func _check_phase_transition() -> void:
	var hp_ratio = current_health / max_health
	if current_phase == Phase.SERMON and hp_ratio <= PHASE2_THRESHOLD:
		_transition_to(Phase.DOUBT)
	elif current_phase == Phase.DOUBT and hp_ratio <= PHASE3_THRESHOLD:
		_transition_to(Phase.DISSOLUTION)


func _transition_to(phase: Phase) -> void:
	transition_locked = true
	velocity = Vector3.ZERO

	# Brief freeze — weight of the moment
	Engine.time_scale = 0.15
	await get_tree().create_timer(0.3).timeout
	Engine.time_scale = 1.0

	_start_phase(phase)

	# Iframes during transition so player can't cheese the phase
	await get_tree().create_timer(1.2).timeout
	transition_locked = false


func _handle_phase(delta: float) -> void:
	match current_phase:
		Phase.SERMON:
			_phase_sermon(delta)
		Phase.DOUBT:
			_phase_doubt(delta)
		Phase.DISSOLUTION:
			_phase_dissolution(delta)


# --- PHASE 1: THE SERMON ---
# Slow, arrogant. Circles player. Projectile volleys + AOE shockwave.

func _phase_sermon(delta: float) -> void:
	_move_toward_player(P1_MOVE_SPEED, delta)
	_face_player(delta)

	attack_timer -= delta
	if attack_timer <= 0.0:
		attack_timer = P1_ATTACK_RATE
		_fire_projectile_volley(P1_PROJECTILE_COUNT)

	shockwave_timer -= delta
	if shockwave_timer <= 0.0:
		shockwave_timer = P1_SHOCKWAVE_RATE
		_shockwave()


# --- PHASE 2: THE DOUBT ---
# Faster. Summons True Believers. Charges. His form is cracking.

func _phase_doubt(delta: float) -> void:
	if is_charging:
		_handle_charge(delta)
		return

	_move_toward_player(P2_MOVE_SPEED, delta)
	_face_player(delta)

	attack_timer -= delta
	if attack_timer <= 0.0:
		attack_timer = P2_ATTACK_RATE
		_fire_projectile_volley(P2_PROJECTILE_COUNT)

	shockwave_timer -= delta
	if shockwave_timer <= 0.0:
		shockwave_timer = P2_SHOCKWAVE_RATE
		_shockwave()

	# Charge attack
	charge_cooldown -= delta
	if charge_cooldown <= 0.0 and player:
		charge_cooldown = CHARGE_COOLDOWN
		_begin_charge()

	# Summon believers
	summon_cooldown -= delta
	if summon_cooldown <= 0.0:
		summon_cooldown = SUMMON_COOLDOWN
		_summon_believers(3)


# --- PHASE 3: THE DISSOLUTION ---
# Coming apart. Constant barrage. Double shockwave. Desperate.

func _phase_dissolution(delta: float) -> void:
	_move_toward_player(P3_MOVE_SPEED, delta)
	_face_player(delta)

	attack_timer -= delta
	if attack_timer <= 0.0:
		attack_timer = P3_ATTACK_RATE
		_fire_projectile_volley(P3_PROJECTILE_COUNT)

	shockwave_timer -= delta
	if shockwave_timer <= 0.0:
		shockwave_timer = P3_SHOCKWAVE_RATE
		_double_shockwave()  # Phase 3 gets double shockwave


# --- MOVEMENT ---

func _move_toward_player(speed: float, delta: float) -> void:
	if not player or is_charging:
		return
	nav_agent.target_position = player.global_position
	var next = nav_agent.get_next_path_position()
	var dir = (next - global_position).normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed


func _face_player(delta: float) -> void:
	if not player:
		return
	var dir = (player.global_position - global_position)
	dir.y = 0
	if dir.length() > 0.1:
		var target = Transform3D().looking_at(dir.normalized(), Vector3.UP)
		global_transform.basis = global_transform.basis.slerp(
			target.basis, delta * 6.0)


# --- ATTACKS ---

func _fire_projectile_volley(count: int) -> void:
	if not player:
		return
	var spread_angle = PI / 5.0  # spread arc
	var start_angle = -spread_angle / 2.0
	for i in range(count):
		var t = float(i) / float(count - 1) if count > 1 else 0.5
		var angle = start_angle + spread_angle * t
		var base_dir = (player.global_position - projectile_spawn.global_position).normalized()
		var rotated_dir = base_dir.rotated(Vector3.UP, angle)
		_spawn_projectile(rotated_dir)


func _spawn_projectile(direction: Vector3) -> void:
	var proj_scene = load("res://Enemies/vicar_projectile.tscn")
	if proj_scene == null:
		push_error("VicarProjectile.tscn not found!")
		return
	var proj = proj_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = projectile_spawn.global_position
	proj.initialize(direction, 14.0, 18.0)


func _shockwave() -> void:
	# AOE — damages player if within range
	if not player:
		return
	var dist = global_position.distance_to(player.global_position)
	var shockwave_range = 7.0

	# Visual — expanding ring particle burst
	_spawn_shockwave_vfx(shockwave_range, Color(0.8, 0.1, 0.1))

	if dist <= shockwave_range:
		player.take_damage(22.0)
		player.shake(0.12)
		# Knock player back
		var knockback = (player.global_position - global_position).normalized()
		knockback.y = 0.4
		player.velocity += knockback * 12.0


func _double_shockwave() -> void:
	_shockwave()
	# Second wave half a second later, slightly larger
	await get_tree().create_timer(0.5).timeout
	if is_dead:
		return
	var dist = global_position.distance_to(player.global_position)
	var range2 = 10.0
	_spawn_shockwave_vfx(range2, Color(0.6, 0.0, 0.0))
	if dist <= range2:
		player.take_damage(14.0)
		player.shake(0.08)


func _spawn_shockwave_vfx(radius: float, color: Color) -> void:
	var particles = GPUParticles3D.new()
	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position + Vector3(0, 0.3, 0)
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 180.0
	mat.initial_velocity_min = radius * 1.8
	mat.initial_velocity_max = radius * 2.2
	mat.gravity = Vector3(0, -2.0, 0)
	mat.scale_min = 0.08
	mat.scale_max = 0.18
	mat.color = color
	var mesh_ref = SphereMesh.new()
	mesh_ref.radius = 0.06
	mesh_ref.height = 0.12
	particles.process_material = mat
	particles.draw_pass_1 = mesh_ref
	particles.amount = 48
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 0.99
	particles.emitting = true
	await get_tree().create_timer(0.8).timeout
	particles.queue_free()


func _begin_charge() -> void:
	if not player:
		return
	is_charging = true
	charge_timer = CHARGE_DURATION
	charge_direction = (player.global_position - global_position).normalized()
	charge_direction.y = 0


func _handle_charge(delta: float) -> void:
	charge_timer -= delta
	velocity.x = charge_direction.x * P2_CHARGE_SPEED
	velocity.z = charge_direction.z * P2_CHARGE_SPEED

	# Damage player on contact during charge
	if player and global_position.distance_to(player.global_position) < 1.8:
		player.take_damage(30.0)
		player.shake(0.18)
		var knockback = charge_direction
		knockback.y = 0.5
		player.velocity += knockback * 16.0
		is_charging = false

	if charge_timer <= 0.0:
		is_charging = false


func _summon_believers(count: int) -> void:
	# TrueBeliever scene not built yet — skipping summon
	pass

#func _summon_believers(count: int) -> void:
	## Spawn True Believers around the Vicar
	#var believer_scene = load("res://Enemies/TrueBeliever.tscn")
	#if not believer_scene:
		#return
	#for i in range(count):
		#var angle = (TAU / count) * i
		#var offset = Vector3(cos(angle) * 3.0, 0, sin(angle) * 3.0)
		#var believer = believer_scene.instantiate()
		#get_tree().current_scene.add_child(believer)
		#believer.global_position = global_position + offset


# --- TAKING DAMAGE ---

func take_damage(amount: float) -> void:
	if is_dead or transition_locked:
		return
	current_health -= amount
	if current_health <= 0:
		die()

# --- DEATH ---

func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector3.ZERO

	# Slow collapse — decay consumes him from inside
	Engine.time_scale = 0.2
	decay_particles.amount = 128
	decay_particles.emitting = true

	await get_tree().create_timer(0.8).timeout
	Engine.time_scale = 1.0

	# ASEL walks past without stopping — no fanfare, no music sting
	# Just silence and the decay particles eating him
	await get_tree().create_timer(2.5).timeout
	queue_free()
