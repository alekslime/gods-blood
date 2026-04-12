extends BaseWeapon

const FLAME_TICK_RATE = 0.05

@export var fuel_max: float = 100.0
var fuel_current: float = 100.0
const FUEL_DRAIN_ON_REGEN := 35.0
var is_empty: bool = false

var sputter_timer: float = 0.0
const SPUTTER_INTERVAL_MIN := 0.3
const SPUTTER_INTERVAL_MAX := 0.9
var next_sputter: float = 0.5

@onready var raycast: RayCast3D = $RayCast
@onready var flame_particles: GPUParticles3D = $FlameParticles
@onready var flame_sound: AudioStreamPlayer = $FlameSound
@onready var ignite_sound: AudioStreamPlayer = $IgniteSound
@onready var focus_sound: AudioStreamPlayer = $FocusSound
@onready var hit_sound: AudioStreamPlayer = $HitSound
@onready var release_sound: AudioStreamPlayer = $AirReleaseSound

var ember_particles: GPUParticles3D = null

# --- FIREBALL ---
const FIREBALL_INTERVAL := 0.45   # slower spawn so they don't pile up
var fireball_timer: float = 0.0
const FIREBALL_SPEED := 22.0      # faster travel so they actually go somewhere
const FIREBALL_DAMAGE := 22.0

# --- HEAT DISTORTION ---
var heat_quad: MeshInstance3D = null
var heat_mat: ShaderMaterial = null
var heat_intensity: float = 0.0

const HEAT_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float time_offset = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float noise = sin(uv.y * 40.0 + TIME * 6.0 + time_offset) * 0.5
				+ sin(uv.x * 30.0 + TIME * 4.0) * 0.5;
	uv += noise * intensity * 0.012;
	ALBEDO = texture(SCREEN_TEXTURE, uv).rgb;
	ALPHA = intensity * 0.85;
}
"""


var flame_light: OmniLight3D = null


func _ready() -> void:
	weapon_name = "The Flame"
	damage = 8.0
	fire_rate = FLAME_TICK_RATE
	is_infinite_ammo = true
	_setup_flame_particles()
	_setup_ember_particles()
	_setup_heat_distortion()
	_setup_flame_light()
	super._ready()
	if raycast:
		raycast.target_position = Vector3(0, 0, -28.0)


func _setup_flame_light() -> void:
	flame_light = OmniLight3D.new()
	flame_light.light_color = Color(1.0, 0.45, 0.05)
	flame_light.light_energy = 0.0
	flame_light.omni_range = 12.0
	flame_light.shadow_enabled = false
	add_child(flame_light)


func _setup_flame_particles() -> void:
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, -1)
	material.spread = 14.0
	material.initial_velocity_min = 26.0
	material.initial_velocity_max = 40.0
	material.gravity = Vector3(0, 2.5, 0)
	material.scale_min = 0.9
	material.scale_max = 2.4
	material.turbulence_enabled = true
	material.turbulence_noise_strength = 1.4
	material.turbulence_noise_scale = 3.0
	# Fade out at end of lifetime
	var grad = Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = grad
	material.color_ramp = grad_tex
	# Flipbook — 5 columns, 5 rows, 25 frames
	material.anim_speed_min = 15.0
	material.anim_speed_max = 20.0
	material.anim_offset_min = 0.0
	material.anim_offset_max = 1.0  # random start frame per particle

	# Billboard quad with the spritesheet
	var mesh_ref = QuadMesh.new()
	mesh_ref.size = Vector2(0.7, 0.7)

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = load("res://spritesheet.png")
	mat.particles_anim_h_frames = 5
	mat.particles_anim_v_frames = 5
	mat.particles_anim_loop = true
	mat.particles_animation = true  # critical — enables flipbook mode
	mesh_ref.surface_set_material(0, mat)

	flame_particles.process_material = material
	flame_particles.draw_pass_1 = mesh_ref
	flame_particles.amount = 60
	flame_particles.lifetime = 0.55
	flame_particles.explosiveness = 0.0
	flame_particles.emitting = false


func _setup_ember_particles() -> void:
	ember_particles = GPUParticles3D.new()
	add_child(ember_particles)
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, -1)
	mat.spread = 35.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 8.0
	mat.gravity = Vector3(0, -2.0, 0)
	mat.scale_min = 0.05
	mat.scale_max = 0.18
	mat.color = Color(0.8, 0.3, 0.0, 0.8)
	var mesh_ref = SphereMesh.new()
	mesh_ref.radius = 0.04
	mesh_ref.height = 0.08
	ember_particles.process_material = mat
	ember_particles.draw_pass_1 = mesh_ref
	ember_particles.amount = 12
	ember_particles.lifetime = 0.6
	ember_particles.explosiveness = 0.8
	ember_particles.one_shot = true
	ember_particles.emitting = false


func _setup_heat_distortion() -> void:
	pass # Disabled — caused grey square artifact on some setups


func _process(delta: float) -> void:
	super._process(delta)
	is_empty = fuel_current <= 0.0

	# Heat distortion disabled

	# Persistent flame light — ramps up while firing, flickers naturally
	if is_firing and not is_empty:
		var target = 4.0 + randf_range(-0.5, 0.5)
		flame_light.light_energy = lerp(flame_light.light_energy, target, delta * 12.0)
	else:
		flame_light.light_energy = move_toward(flame_light.light_energy, 0.0, delta * 6.0)

	# Sputter when empty
	if is_empty and is_firing:
		sputter_timer += delta
		if sputter_timer >= next_sputter:
			sputter_timer = 0.0
			next_sputter = randf_range(SPUTTER_INTERVAL_MIN, SPUTTER_INTERVAL_MAX)
			_do_sputter()

	# Fireball spawning
	if is_firing and not is_empty:
		fireball_timer -= delta
		if fireball_timer <= 0.0:
			fireball_timer = FIREBALL_INTERVAL
			_spawn_fireball()


var is_firing: bool = false


func fire() -> void:
	is_firing = true
	if is_empty:
		if not flame_sound.playing:
			flame_sound.play()
		flame_particles.emitting = false
		_do_sputter()
		return

	if not flame_particles.emitting:
		if ignite_sound:
			ignite_sound.pitch_scale = randf_range(0.95, 1.05)
			ignite_sound.play()

	flame_particles.emitting = true
	if not flame_sound.playing:
		flame_sound.play()

	raycast.force_raycast_update()
	if raycast.is_colliding():
		var hit = raycast.get_collider()
		var hit_pos = raycast.get_collision_point()
		var hit_normal = raycast.get_collision_normal()
		deal_damage(hit)
		GoreManager.spawn_blood(hit_pos, hit_normal, get_tree().current_scene)
		if hit_sound and not hit_sound.playing:
			hit_sound.pitch_scale = randf_range(0.85, 1.15)
			hit_sound.play()


func stop_fire() -> void:
	if is_firing and release_sound:
		release_sound.pitch_scale = randf_range(0.95, 1.05)
		release_sound.play()
	is_firing = false
	flame_particles.emitting = false
	flame_sound.stop()
	sputter_timer = 0.0
	fireball_timer = 0.0


func _spawn_fireball() -> void:
	var cam = get_viewport().get_camera_3d()
	if not cam:
		return

	# Build fireball mesh
	var fb = MeshInstance3D.new()
	get_tree().current_scene.add_child(fb)

	# No visible mesh — flame particles already look good
	# Fireball is invisible but still does damage and carries a light
	fb.mesh = null

	var spread_x = randf_range(-0.04, 0.04)
	var spread_y = randf_range(-0.01, 0.03)
	var dir = (cam.global_transform.basis * Vector3(spread_x, spread_y, -1)).normalized()
	fb.global_position = cam.global_position + dir * 2.0  # start further out

	var lifetime := 0.7   # longer lifetime so they travel further
	var elapsed := 0.0

	while elapsed < lifetime and is_instance_valid(fb):
		var d = get_process_delta_time()
		elapsed += d
		fb.global_position += dir * FIREBALL_SPEED * d

		var t = 1.0 - (elapsed / lifetime)
		# No mesh to fade — just travels and damages

		# Shape cast for enemy overlap
		var space = get_world_3d().direct_space_state
		var shape = SphereShape3D.new()
		shape.radius = 0.5
		var params = PhysicsShapeQueryParameters3D.new()
		params.shape = shape
		params.transform = Transform3D(Basis(), fb.global_position)
		params.collision_mask = 0b11
		var hits = space.intersect_shape(params, 4)
		for h in hits:
			var col = h.collider
			if col.is_in_group("enemy") and col.has_method("take_damage"):
				col.take_damage(FIREBALL_DAMAGE * d * 8.0)
			elif col.get_parent() and col.get_parent().is_in_group("enemy"):
				col.get_parent().take_damage(FIREBALL_DAMAGE * d * 8.0)

		await get_tree().process_frame

	if is_instance_valid(fb):
		_spawn_fireball_pop(fb.global_position)
		fb.queue_free()


func _spawn_fireball_pop(pos: Vector3) -> void:
	var particles = GPUParticles3D.new()
	get_tree().current_scene.add_child(particles)
	particles.global_position = pos
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 80.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0, 1.0, 0)
	mat.scale_min = 0.1
	mat.scale_max = 0.4
	mat.color = Color(1.0, 0.4, 0.0)
	var mesh_ref = SphereMesh.new()
	mesh_ref.radius = 0.1
	mesh_ref.height = 0.2
	particles.process_material = mat
	particles.draw_pass_1 = mesh_ref
	particles.amount = 14
	particles.lifetime = 0.35
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.emitting = true
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(particles):
		particles.queue_free()


func _do_sputter() -> void:
	if ember_particles:
		ember_particles.emitting = true
	if flame_sound.playing:
		flame_sound.stop()
	await get_tree().create_timer(randf_range(0.05, 0.15)).timeout


var is_focused: bool = false  # right click — tighter spread, longer range


func set_focused(value: bool) -> void:
	is_focused = value
	if not flame_particles or not flame_particles.process_material:
		return
	var mat = flame_particles.process_material as ParticleProcessMaterial
	if is_focused:
		mat.spread = 4.0                      # tight beam
		mat.initial_velocity_min = 35.0       # faster = longer reach
		mat.initial_velocity_max = 50.0
		mat.scale_min = 0.5
		mat.scale_max = 1.2
	else:
		mat.spread = 14.0                     # back to normal
		mat.initial_velocity_min = 26.0
		mat.initial_velocity_max = 40.0
		mat.scale_min = 0.9
		mat.scale_max = 2.4


func drain_fuel(amount: float) -> void:
	fuel_current = max(fuel_current - amount, 0.0)
	is_empty = fuel_current <= 0.0


func refuel(amount: float) -> void:
	fuel_current = min(fuel_current + amount, fuel_max)
	is_empty = fuel_current <= 0.0
