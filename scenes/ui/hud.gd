extends CanvasLayer

@onready var health_bar: ProgressBar = $HUDRoot/HealthBar
@onready var health_label: Label = $HUDRoot/HealthLabel
@onready var ammo_label: Label = $HUDRoot/AmmoLabel
@onready var damage_vignette: ColorRect = $HUDRoot/DamageVignette
@onready var death_screen: ColorRect = $HUDRoot/DeathScreen
@onready var rage_bar: ProgressBar = $HUDRoot/RageBar
@onready var rage_label: Label = $HUDRoot/RageBar/RageLabel
@onready var rage_vignette: ColorRect = $HUDRoot/RageVignette

var vignette_alpha := 0.0
var heal_alpha := 0.0
var fire_alpha := 0.0

var heal_vignette: ColorRect = null
var fire_vignette: ColorRect = null

# --- DASH CHARGE ICONS ---
const DASH_ICON_SIZE = 14
const DASH_ICON_GAP = 6
const DASH_ICON_MARGIN = 16
var dash_icons: Array = []           # ColorRect nodes
var dash_fill_bars: Array = []       # inner fill bars showing recharge progress


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

	_build_dash_icons(parent)


func _build_dash_icons(parent: Control) -> void:
	# Positioned bottom-center, just above crosshair area
	var total_width = 3 * DASH_ICON_SIZE + 2 * DASH_ICON_GAP
	var start_x = get_viewport().get_visible_rect().size.x / 2.0 - total_width / 2.0
	var y = get_viewport().get_visible_rect().size.y - DASH_ICON_MARGIN - DASH_ICON_SIZE - 40

	for i in range(3):
		# Outer frame
		var frame = ColorRect.new()
		frame.size = Vector2(DASH_ICON_SIZE, DASH_ICON_SIZE)
		frame.position = Vector2(start_x + i * (DASH_ICON_SIZE + DASH_ICON_GAP), y)
		frame.color = Color(0.3, 0.3, 0.3, 0.9)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(frame)

		# Inner fill (recharge progress)
		var fill = ColorRect.new()
		fill.size = Vector2(DASH_ICON_SIZE, DASH_ICON_SIZE)
		fill.position = Vector2(0, 0)
		fill.color = Color(0.9, 0.85, 0.2, 1.0)  # gold when charged
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(fill)

		dash_icons.append(frame)
		dash_fill_bars.append(fill)


func _process(delta: float) -> void:
	vignette_alpha = lerp(vignette_alpha, 0.0, delta * 4.0)
	damage_vignette.color = Color(0.6, 0, 0, vignette_alpha)

	if heal_vignette:
		heal_alpha = lerp(heal_alpha, 0.0, delta * 4.0)
		heal_vignette.color = Color(0.0, 0.6, 0.2, heal_alpha)

	if fire_vignette:
		fire_alpha = lerp(fire_alpha, 0.0, delta * 2.0)
		fire_vignette.color = Color(1.0, 0.75, 0.0, fire_alpha)


func update_dash_charges(charges: int, recharge_timers: Array, recharge_time: float) -> void:
	for i in range(3):
		if i >= dash_fill_bars.size():
			break
		var fill: ColorRect = dash_fill_bars[i]
		if i < charges:
			# Fully charged — gold, full size
			fill.color = Color(0.9, 0.85, 0.2, 1.0)
			fill.size = Vector2(DASH_ICON_SIZE, DASH_ICON_SIZE)
			fill.position = Vector2(0, 0)
		else:
			# Recharging — grey frame, fill grows upward from bottom
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
	death_screen.visible = true


func update_rage(value: float) -> void:
	rage_bar.value = value
	if value >= 100.0:
		rage_label.text = "RAGE - ACTIVE"
		rage_label.add_theme_color_override("font_color", Color(1, 0.2, 0))
	else:
		rage_label.text = "RAGE"
		rage_label.add_theme_color_override("font_color", Color(1, 1, 1))


func set_rage_vignette(alpha: float) -> void:
	rage_vignette.color = Color(0.8, 0, 0, alpha)
