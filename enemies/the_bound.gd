class_name TheBound
extends BaseEnemy

# Heavy tank. Only STUNNED by Hollow Round (not extra damage).
# Slow, relentless, takes reduced damage from everything else.

@export var damage_reduction: float = 0.35     # takes 35% of all non-Hollow damage
@export var stun_duration: float = 2.5         # how long Hollow Round stuns it
@export var stun_speed_mult: float = 0.0       # 0 = fully frozen during stun

var is_stunned: bool = false

func _ready() -> void:
	super()
	max_health = 280.0
	current_health = max_health
	move_speed = 3.0            # slow and heavy
	attack_damage = 30.0        # hits very hard
	attack_range = 2.0
	attack_cooldown = 1.8
	rage_on_kill = 25.0

func _update_navigation() -> void:
	if is_stunned:
		velocity.x = 0
		velocity.z = 0
		return
	super()

func take_damage(amount: float, source: String = "") -> void:
	if is_dead:
		return
	if source == "hollow_round":
		# Full damage + stun — no reduction
		current_health -= amount
		_apply_stun()
	else:
		# All other weapons — reduced damage, no stun
		current_health -= amount * damage_reduction
	if hit_sound and not hit_sound.playing:
		hit_sound.pitch_scale = randf_range(0.85, 1.0)  # lower pitch — heavier
		hit_sound.play()
	if current_health <= 0:
		die()

func _apply_stun() -> void:
	if is_stunned:
		return  # don't stack stuns
	is_stunned = true
	# Visual feedback — flash white or tint blue (placeholder)
	await get_tree().create_timer(stun_duration).timeout
	if not is_dead:
		is_stunned = false
