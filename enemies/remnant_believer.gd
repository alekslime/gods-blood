class_name RemnantBeliever
extends BaseEnemy

# Fast human melee enemy. Occasionally drops health on death.
@export var health_drop_chance: float = 0.25   # 25% chance
@export var health_drop_amount: float = 20.0   # how much HP it restores

func _ready() -> void:
	super()
	max_health = 75.0
	current_health = max_health
	move_speed = 7.5            # fast — closes distance quickly
	attack_damage = 12.0
	attack_range = 1.4
	attack_cooldown = 0.65      # attacks frequently
	rage_on_kill = 25.0

func die() -> void:
	super()  # handles rage, sound, cleanup
	_try_drop_health()

func _try_drop_health() -> void:
	if randf() <= health_drop_chance:
		if player and player.has_method("heal"):
			player.heal(health_drop_amount)
		else:
			# Fallback: call take_damage with negative if heal doesn't exist yet
			if player and player.has_method("take_damage"):
				# We'll add heal() to player later — skip drop silently for now
				pass
