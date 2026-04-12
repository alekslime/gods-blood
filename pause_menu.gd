extends CanvasLayer

# --- STATE ---
var is_paused := false

# --- NODES ---
@onready var root: Control = $Control
@onready var overlay: ColorRect = $Control/Overlay
@onready var panel: Control = $Control/Panel
@onready var title: Label = $Control/Panel/Title
@onready var btn_resume: Button = $Control/Panel/VBoxContainer/Resume
@onready var btn_restart: Button = $Control/Panel/VBoxContainer/Restart
@onready var btn_settings: Button = $Control/Panel/VBoxContainer/Settings
@onready var btn_quit: Button = $Control/Panel/VBoxContainer/Quit

# Settings panel
@onready var settings_panel: Control = $Control/Panel/SettingsPanel
@onready var btn_settings_back: Button = $Control/Panel/SettingsPanel/Back
@onready var sensitivity_slider: HSlider = $Control/Panel/SettingsPanel/SensitivitySlider
@onready var sensitivity_label: Label = $Control/Panel/SettingsPanel/SensitivityLabel

# Tween for smooth open/close
var tween: Tween = null


func _ready() -> void:
	print("root: ", root)
	print("overlay: ", overlay)
	print("panel: ", panel)
	print("settings_panel: ", settings_panel)
	print("btn_resume: ", btn_resume)
	print("btn_restart: ", btn_restart)
	print("btn_settings: ", btn_settings)
	print("btn_quit: ", btn_quit)
	print("btn_settings_back: ", btn_settings_back)
	print("sensitivity_slider: ", sensitivity_slider)
	print("sensitivity_label: ", sensitivity_label)
	root.visible = false
	_connect_buttons()
	_apply_style()
	process_mode = Node.PROCESS_MODE_ALWAYS


func _apply_style() -> void:
	if overlay:
		overlay.color = Color(0.0, 0.0, 0.0, 0.0)

	if panel:
		panel.custom_minimum_size = Vector2(420, 0)

	if title:
		title.add_theme_font_size_override("font_size", 36)
		title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.text = "PAUSED"

	# Force button labels and style
	var button_labels = ["RESUME", "RESTART", "SETTINGS", "QUIT"]
	var buttons = [btn_resume, btn_restart, btn_settings, btn_quit]
	for i in range(buttons.size()):
		if buttons[i]:
			buttons[i].text = button_labels[i]
			_style_button(buttons[i])

	if btn_quit:
		btn_quit.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

	if btn_settings_back:
		btn_settings_back.text = "BACK"
		_style_button(btn_settings_back)


func _style_button(btn: Button) -> void:
	btn.custom_minimum_size = Vector2(320, 48)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.2, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.85, 0.2, 1))
	btn.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))

	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	normal.corner_radius_top_left = 3
	normal.corner_radius_top_right = 3
	normal.corner_radius_bottom_left = 3
	normal.corner_radius_bottom_right = 3
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.25, 0.20, 0.05, 0.95)
	hover.border_width_bottom = 2
	hover.border_color = Color(1.0, 0.85, 0.2, 1.0)
	hover.corner_radius_top_left = 3
	hover.corner_radius_top_right = 3
	hover.corner_radius_bottom_left = 3
	hover.corner_radius_bottom_right = 3
	hover.content_margin_left = 12
	hover.content_margin_right = 12
	hover.content_margin_top = 8
	hover.content_margin_bottom = 8

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = Color(0.08, 0.08, 0.08, 0.95)
	pressed.corner_radius_top_left = 3
	pressed.corner_radius_top_right = 3
	pressed.corner_radius_bottom_left = 3
	pressed.corner_radius_bottom_right = 3
	pressed.content_margin_left = 12
	pressed.content_margin_right = 12
	pressed.content_margin_top = 8
	pressed.content_margin_bottom = 8

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", normal)


func _connect_buttons() -> void:
	if btn_resume:
		btn_resume.pressed.connect(_on_resume)
	else:
		push_warning("PauseMenu: btn_resume not found")
	if btn_restart:
		btn_restart.pressed.connect(_on_restart)
	else:
		push_warning("PauseMenu: btn_restart not found")
	if btn_settings:
		btn_settings.pressed.connect(_on_settings)
	else:
		push_warning("PauseMenu: btn_settings not found")
	if btn_quit:
		btn_quit.pressed.connect(_on_quit)
	else:
		push_warning("PauseMenu: btn_quit not found")
	if btn_settings_back:
		btn_settings_back.pressed.connect(_on_settings_back)
	else:
		push_warning("PauseMenu: btn_settings_back not found")
	if sensitivity_slider:
		sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	else:
		push_warning("PauseMenu: sensitivity_slider not found")


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if settings_panel and settings_panel.visible:
			_on_settings_back()
		else:
			toggle_pause()


func toggle_pause() -> void:
	is_paused = !is_paused
	if is_paused:
		_open()
	else:
		_close()


func _open() -> void:
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	root.visible = true
	settings_panel.visible = false

	# Animate panel sliding in
	panel.modulate.a = 0.0
	panel.position.y += 20.0
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	tween.tween_property(panel, "position:y", panel.position.y - 20.0, 0.18).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(overlay, "color:a", 0.72, 0.2)


func _close() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 0.0, 0.12)
	tween.tween_property(overlay, "color:a", 0.0, 0.12)
	await tween.finished
	root.visible = false


func _on_resume() -> void:
	is_paused = false
	_close()


func _on_restart() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().reload_current_scene()


func _on_settings() -> void:
	panel.visible = false
	settings_panel.visible = true


func _on_settings_back() -> void:
	settings_panel.visible = false
	panel.visible = true


func _on_quit() -> void:
	get_tree().quit()


func _on_sensitivity_changed(value: float) -> void:
	sensitivity_label.text = "SENSITIVITY: " + str(snappedf(value, 0.001))
	# Wire to player mouse sensitivity
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set("MOUSE_SENSITIVITY", value)
