extends Node3D

var weapons: Array = []
var current_index: int = 0
var current_weapon: BaseWeapon = null


func _ready() -> void:
	for child in get_children():
		if child is BaseWeapon:
			weapons.append(child)
			child.unequip()
	if weapons.size() > 0:
		_equip(0)


func handle_input(delta: float) -> void:
	if current_weapon == null:
		return

	if Input.is_action_pressed("attack"):
		current_weapon.try_fire()
	else:
		# Stop flame when not pressing attack
		if current_weapon.has_method("stop_fire"):
			current_weapon.stop_fire()

	if Input.is_action_just_pressed("weapon_next"):
		_cycle(1)
	if Input.is_action_just_pressed("weapon_prev"):
		_cycle(-1)

	# Update ammo HUD
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.update_ammo(current_weapon.ammo_current, current_weapon.ammo_max, current_weapon.is_infinite_ammo)


func _cycle(direction: int) -> void:
	if weapons.size() <= 1:
		return
	if current_weapon.has_method("stop_fire"):
		current_weapon.stop_fire()
	current_weapon.unequip()
	current_index = (current_index + direction) % weapons.size()
	if current_index < 0:
		current_index = weapons.size() - 1
	_equip(current_index)


func _equip(index: int) -> void:
	current_index = index
	current_weapon = weapons[index]
	current_weapon.equip()
