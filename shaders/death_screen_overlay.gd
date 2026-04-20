extends CanvasLayer

const LORE_LINES = [
	"IT NOTICED YOU",
	"THE PRESENCE FELT YOU FALL",
	"DID ANY OF IT MEAN ANYTHING?",
	"YOU ARE LOUD",
	"THE DECAY REMEMBERS",
	"IT WAS ALREADY WATCHING",
	"SOMETHING OLDER THAN DEATH SAW THIS",
]

var shader_rect: ColorRect
var lore_label: Label
var restart_label: Label
var shader_mat: ShaderMaterial
var tween: Tween
var time_val: float = 0.0
var is_active: bool = false
var can_restart: bool = false

func _ready() -> void:
	layer = 10  # on top of everything
	visible = false
	_build_ui()

func _build_ui() -> void:
	# Full screen shader rect
	shader_rect = ColorRect.new()
	shader_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shader_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/death_screen.gdshader")
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("time_val", 0.0)
	shader_rect.material = mat
	shader_mat = mat
	add_child(shader_rect)

	# Lore line — center screen, slightly above middle
	lore_label = Label.new()
	lore_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	lore_label.position.y -= 40
	lore_label.add_theme_font_size_override("font_size", 28)
	lore_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 0.0))
	lore_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lore_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lore_label)

	# Restart prompt
	restart_label = Label.new()
	restart_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	restart_label.position.y += 20
	restart_label.add_theme_font_size_override("font_size", 14)
	restart_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 0.0))
	restart_label.text = "PRESS [R] TO CONTINUE"
	restart_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(restart_label)

func show_death() -> void:
	visible = true
	is_active = true
	can_restart = false
	time_val = 0.0

	# Pick random lore line
	lore_label.text = LORE_LINES[randi() % LORE_LINES.size()]

	# Animate shader progress 0 → 1 over 2.5s
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_method(
		func(v): shader_mat.set_shader_parameter("progress", v),
		0.0, 1.0, 2.5
	)

	# Fade in lore text after 1.2s
	await get_tree().create_timer(1.2).timeout
	var t2 = create_tween()
	t2.tween_method(
		func(v): lore_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, v)),
		0.0, 1.0, 0.8
	)

	# Show restart prompt after 2.2s
	await get_tree().create_timer(1.0).timeout
	can_restart = true
	var t3 = create_tween()
	t3.tween_method(
		func(v): restart_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, v)),
		0.0, 1.0, 0.5
	)

func _process(delta: float) -> void:
	if not is_active:
		return
	time_val += delta
	if shader_mat:
		shader_mat.set_shader_parameter("time_val", time_val)
	if can_restart and Input.is_action_just_pressed("restart"):
		_do_restart()

func _do_restart() -> void:
	is_active = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

func hide_death() -> void:
	visible = false
	is_active = false
	can_restart = false
	if shader_mat:
		shader_mat.set_shader_parameter("progress", 0.0)
