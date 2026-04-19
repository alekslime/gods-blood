extends Node3D

# ── Weapon slots ──────────────────────────────────────────────────────────────
var weapons: Array[BaseWeapon] = []
var current_index: int = 0
var current_weapon: BaseWeapon

# ── Signals ───────────────────────────────────────────────────────────────────
signal weapon_switched(weapon: BaseWeapon, index: int)

func _ready() -> void:
	# Collect all weapon children
	for child in get_children():
		if child is BaseWeapon:
			weapons.append(child)
			child.visible = false

	if weapons.size() > 0:
		_equip(0)

func _input(event: InputEvent) -> void:
	# Number keys 1–4
	if event.is_action_pressed("weapon_1"): _equip(0)
	if event.is_action_pressed("weapon_2"): _equip(1)
	if event.is_action_pressed("weapon_3"): _equip(2)
	if event.is_action_pressed("weapon_4"): _equip(3)

	# Scroll wheel
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_equip(wrapi(current_index - 1, 0, weapons.size()))
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_equip(wrapi(current_index + 1, 0, weapons.size()))

	# Fire
	if event.is_action_pressed("fire") and current_weapon:
		current_weapon.try_fire()

	# Reload
	if event.is_action_pressed("reload") and current_weapon:
		current_weapon.start_reload()

func handle_input(_delta: float) -> void:
	pass  # Input is handled in _input() — this exists so player.gd doesn't error

func _equip(index: int) -> void:
	if index >= weapons.size():
		return
	if current_weapon:
		current_weapon.visible = false
	current_index = index
	current_weapon = weapons[index]
	current_weapon.visible = true
	weapon_switched.emit(current_weapon, current_index)
