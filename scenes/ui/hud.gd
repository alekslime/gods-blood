extends CanvasLayer

@onready var health_bar: ProgressBar = $HUDRoot/HealthBar
@onready var health_label: Label = $HUDRoot/HealthLabel
@onready var ammo_label: Label = $HUDRoot/AmmoLabel
@onready var damage_vignette: ColorRect = $HUDRoot/DamageVignette
@onready var death_screen: ColorRect = $HUDRoot/DeathScreen
@onready var rage_bar_root: Control = $HUDRoot/RageBarRoot
@onready var rage_fill: TextureRect = $HUDRoot/RageBarRoot/RageFill
@onready var rage_frame: TextureRect = $HUDRoot/RageBarRoot/RageFrame
@onready var rage_label: Label = $HUDRoot/RageBarRoot/RageLabel
@onready var rage_vignette: ColorRect = $HUDRoot/RageVignette

var vignette_alpha := 0.0
var heal_alpha := 0.0
var fire_alpha := 0.0
var desat_overlay: ColorRect = null

var heal_vignette: ColorRect = null
var fire_vignette: ColorRect = null
var crit_flash_rect: ColorRect = null

# --- DASH CHARGE ICONS ---
const DASH_ICON_SIZE = 14
const DASH_ICON_GAP = 6
const DASH_ICON_MARGIN = 16
var dash_icons: Array = []
var dash_fill_bars: Array = []

# --- RAGE BAR EFFECTS ---
var rage_pulse_time := 0.0
var rage_full_timer := 0.0
var rage_is_full := false

func _ready() -> void:
	var parent = damage_vignette.get_parent()

	heal_vignette = ColorRect.new()
	heal_vignette.color = Color(0.0, 0.6, 0.2, 0.0)
	heal_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heal_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(heal_vignette)

	fire_vignette = ColorRect.new()
	fire_vignette.color = Color(1.0, 0.75, 0.0, 0.0)
	fire_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fire_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(fire_vignette)

	crit_flash_rect = ColorRect.new()
	crit_flash_rect.name = "CritFlash"
	crit_flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	crit_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crit_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(crit_flash_rect)

	desat_overlay = ColorRect.new()
	desat_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	desat_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desat_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	parent.add_child(desat_overlay)

	_build_dash_icons(parent)

func _build_dash_icons(parent: Control) -> void:
	var total_width = 3 * DASH_ICON_SIZE + 2 * DASH_ICON_GAP
	var start_x = get_viewport().get_visible_rect().size.x / 2.0 - total_width / 2.0
	var y = get_viewport().get_visible_rect().size.y - DASH_ICON_MARGIN - DASH_ICON_SIZE - 40

	for i in range(3):
		var frame = ColorRect.new()
		frame.size = Vector2(DASH_ICON_SIZE, DASH_ICON_SIZE)
		frame.position = Vector2(start_x + i * (DASH_ICON_SIZE + DASH_ICON_GAP), y)
		frame.color = Color(0.3, 0.3, 0.3, 0.9)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(frame)

		var fill = ColorRect.new()
		fill.size = Vector2(DASH_ICON_SIZE, DASH_ICON_SIZE)
		fill.position = Vector2(0, 0)
		fill.color = Color(0.9, 0.85, 0.2, 1.0)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(fill)

		dash_icons.append(frame)
		dash_fill_bars.append(fill)

func _process(delta: float) -> void:
	# Low health desaturation
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node and desat_overlay:
		var hp_ratio = player_node.current_health / player_node.max_health
		var desat_alpha = clamp(1.0 - (hp_ratio / 0.35), 0.0, 0.55)
		desat_overlay.color = Color(0.05, 0.0, 0.0, desat_alpha * (1.0 - hp_ratio))

	vignette_alpha = lerp(vignette_alpha, 0.0, delta * 4.0)
	damage_vignette.color = Color(0.6, 0, 0, vignette_alpha)

	if heal_vignette:
		heal_alpha = lerp(heal_alpha, 0.0, delta * 4.0)
		heal_vignette.color = Color(0.0, 0.6, 0.2, heal_alpha)

	if fire_vignette:
		fire_alpha = lerp(fire_alpha, 0.0, delta * 2.0)
		fire_vignette.color = Color(1.0, 0.75, 0.0, fire_alpha)

	# Rage pulse + flicker when full
	if rage_is_full:
		rage_full_timer += delta
		rage_pulse_time += delta
		var pulse = (sin(rage_pulse_time * 8.0) + 1.0) / 2.0
		var pulse_strength = lerp(0.7, 1.0, pulse)
		var flicker = 1.0
		if rage_full_timer > 2.0:
			flicker = randf_range(0.55, 1.0)
		rage_fill.modulate.a = pulse_strength * flicker
		var shake_amount = 0.8 if rage_full_timer < 2.0 else 1.5
		rage_bar_root.position.x = rage_bar_root.position.x + randf_range(-shake_amount, shake_amount)
		rage_bar_root.position.y = rage_bar_root.position.y + randf_range(-shake_amount, shake_amount)
	else:
		rage_bar_root.position = Vector2(rage_bar_root.position.x, rage_bar_root.position.y).lerp(
			Vector2(31, 575), 0.25)

func update_dash_charges(charges: int, recharge_timers: Array, recharge_time: float) -> void:
	for i in range(3):
		if i >= dash_fill_bars.size():
			break
		var fill: ColorRect = dash_fill_bars[i]
		if i < charges:
			fill.color = Color(0.9, 0.85, 0.2, 1.0)
			fill.size = Vector2(DASH_ICON_SIZE, DASH_ICON_SIZE)
			fill.position = Vector2(0, 0)
		else:
			var t = 1.0 - clamp(recharge_timers[i] / recharge_time, 0.0, 1.0)
			var fill_height = DASH_ICON_SIZE * t
			fill.color = Color(0.5, 0.5, 0.5, 0.6)
			fill.size = Vector2(DASH_ICON_SIZE, fill_height)
			fill.position = Vector2(0, DASH_ICON_SIZE - fill_height)

func flash_damage() -> void:
	vignette_alpha = 0.7

func flash_heal() -> void:
	heal_alpha = 0.45

func flash_fire_regen() -> void:
	fire_alpha = 0.85

func flash_crit() -> void:
	if not crit_flash_rect:
		return
	crit_flash_rect.color = Color(1.0, 1.0, 1.0, 0.18)
	var tween = create_tween()
	tween.tween_method(
		func(v): crit_flash_rect.color = Color(1.0, 1.0, 1.0, v),
		0.18, 0.0, 0.12
	)

func pulse_health_bar(amount: float) -> void:
	health_bar.modulate = Color(1.0, lerp(1.0, 0.85, amount), lerp(1.0, 0.0, amount))

func update_health(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current

func update_ammo(current: int, maximum: int, infinite: bool) -> void:
	if infinite:
		ammo_label.text = "∞"
	else:
		ammo_label.text = str(current) + " / " + str(maximum)

func show_death_screen() -> void:
	death_screen.visible = false
	var overlay = get_tree().get_first_node_in_group("death_overlay")
	if overlay:
		overlay.show_death()

func update_rage(value: float) -> void:
	var t = clamp(value / 100.0, 0.0, 1.0)
	rage_fill.size.x = 400.0 * t
	var fill_color = Color(0.55, 0.05, 0.05).lerp(Color(0.94, 0.75, 0.03), t)
	rage_fill.modulate = fill_color
	if value >= 100.0:
		if not rage_is_full:
			rage_is_full = true
			rage_full_timer = 0.0
	else:
		rage_is_full = false
		rage_full_timer = 0.0
	if value >= 100.0:
		rage_label.text = "RAGE - PRESS G"
		rage_label.add_theme_color_override("font_color", Color(0.94, 0.75, 0.03))
	else:
		rage_label.text = "RAGE"
		rage_label.add_theme_color_override("font_color", Color(1, 1, 1))

func set_rage_vignette(alpha: float) -> void:
	rage_vignette.color = Color(0.8, 0, 0, alpha)
