extends Node

# ================================================================
# LAYERED MUSIC MANAGER
# Attach this to an autoload or a persistent node in your scene.
#
# HOW TO SET UP:
# 1. Add this script to a Node called MusicManager
# 2. Add it as an Autoload in Project > Project Settings > Autoload
# 3. Add AudioStreamPlayer children named:
#    - LayerAmbient   (dark drone / atmosphere)
#    - LayerRhythm    (percussion / heartbeat)
#    - LayerMelody    (main theme / strings)
#    - LayerIntense   (distorted / chaotic layer for rage/combat peak)
# 4. Assign your audio files to each player in the Inspector
# 5. All tracks must be the SAME LENGTH and loop together
# ================================================================

# --- LAYERS ---
@onready var layer_ambient: AudioStreamPlayer = $LayerAmbient
@onready var layer_rhythm: AudioStreamPlayer = $LayerRythm
@onready var layer_melody: AudioStreamPlayer = $LayerMelody
@onready var layer_intense: AudioStreamPlayer = $LayerIntense

# --- TARGET VOLUMES (db) ---
const VOL_OFF := -80.0       # effectively silent
const VOL_FULL := 0.0        # full volume
const VOL_MID := -6.0        # slightly quieter

# --- FADE SPEED ---
const FADE_SPEED := 2.0      # db per second — smooth crossfade
const FADE_SPEED_FAST := 6.0 # faster fade-in for combat spike

# --- COMBAT DETECTION ---
const COMBAT_RANGE := 18.0         # distance to consider "in combat"
const COMBAT_EXIT_DELAY := 4.0     # seconds after last enemy before music calms
var combat_timer := 0.0
var is_in_combat := false
var combat_intensity := 0.0        # 0.0 = calm, 1.0 = full combat

# --- STATE ---
var player: CharacterBody3D = null
var current_targets: Dictionary = {}   # layer -> target volume


func _ready() -> void:
	# Start all layers at same position, only ambient audible
	current_targets = {
		layer_ambient: VOL_FULL,
		layer_rhythm:  VOL_OFF,
		layer_melody:  VOL_OFF,
		layer_intense: VOL_OFF,
	}

	for layer in current_targets:
		if layer:
			layer.volume_db = VOL_OFF
			layer.play()

	# Slight delay before ambient fades in — dramatic opening silence
	await get_tree().create_timer(1.2).timeout
	current_targets[layer_ambient] = VOL_FULL

	player = get_tree().get_first_node_in_group("player")


func _process(delta: float) -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player")
		return

	_update_combat_state(delta)
	_update_layer_targets()
	_fade_layers(delta)


func _update_combat_state(delta: float) -> void:
	var enemies = get_tree().get_nodes_in_group("enemy")
	var nearest_dist := INF

	for enemy in enemies:
		if enemy.has_method("get") and enemy.get("is_dead") == true:
			continue
		var dist = player.global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist

	if nearest_dist <= COMBAT_RANGE:
		is_in_combat = true
		combat_timer = COMBAT_EXIT_DELAY
		# Intensity scales with proximity — closer = more intense
		var t = 1.0 - clamp(nearest_dist / COMBAT_RANGE, 0.0, 1.0)
		combat_intensity = move_toward(combat_intensity, t, delta * 1.5)
	else:
		if combat_timer > 0.0:
			combat_timer -= delta
		else:
			is_in_combat = false
			combat_intensity = move_toward(combat_intensity, 0.0, delta * 0.8)


func _update_layer_targets() -> void:
	var i = combat_intensity   # shorthand

	# Ambient — always on, ducks slightly in heavy combat
	current_targets[layer_ambient] = lerp(VOL_FULL, VOL_MID, i)

	# Rhythm — fades in early in combat
	current_targets[layer_rhythm] = lerp(VOL_OFF, VOL_FULL, smoothstep(0.0, 0.4, i))

	# Melody — fades in mid combat
	current_targets[layer_melody] = lerp(VOL_OFF, VOL_FULL, smoothstep(0.3, 0.7, i))

	# Intense — only at peak combat
	current_targets[layer_intense] = lerp(VOL_OFF, VOL_FULL, smoothstep(0.65, 1.0, i))

	# Rage override — if player is raging, slam everything to full
	if player and player.get("is_raging") == true:
		current_targets[layer_ambient] = VOL_MID
		current_targets[layer_rhythm] = VOL_FULL
		current_targets[layer_melody] = VOL_FULL
		current_targets[layer_intense] = VOL_FULL


func _fade_layers(delta: float) -> void:
	for layer in current_targets:
		if layer == null:
			continue
		var target: float = current_targets[layer]
		var speed = FADE_SPEED_FAST if target > layer.volume_db else FADE_SPEED
		layer.volume_db = move_toward(layer.volume_db, target, speed * delta)


# ================================================================
# CALL THESE FROM OUTSIDE IF NEEDED
# ================================================================

func stop_music() -> void:
	for layer in current_targets:
		if layer:
			current_targets[layer] = VOL_OFF


func resume_music() -> void:
	current_targets[layer_ambient] = VOL_FULL


# Smooth helper (GDScript doesn't have built-in smoothstep for floats)
func smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
