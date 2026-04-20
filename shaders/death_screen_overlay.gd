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

var video_player: VideoStreamPlayer
var black_bg: ColorRect
var lore_label: Label
var restart_label: Label
var is_active: bool = false
var can_restart: bool = false

func _ready() -> void:
	layer = 10
	visible = false
	_build_ui()

func _build_ui() -> void:
	# Pure black background behind everything
	black_bg = ColorRect.new()
	black_bg.color = Color(0, 0, 0, 1)
	black_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black_bg)

	# Video player — fills screen behind text
	video_player = VideoStreamPlayer.new()
	video_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	video_player.expand = true
	video_player.loop = true
	video_player.autoplay = false
	video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Load your video — put it at res://assets/video/death_screen.webm
	var stream = load("res://assets/video/death_screen.webm")
	if stream:
		video_player.stream = stream
	else:
		push_warning("Death screen video not found at res://assets/video/death_screen.webm")
	add_child(video_player)

	# Lore line
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

	# Pick random lore line
	lore_label.text = LORE_LINES[randi() % LORE_LINES.size()]
	# Reset label alphas
	lore_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 0.0))
	restart_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 0.0))

	# Start video
	if video_player.stream:
		video_player.play()

	# Fade in lore text after 1.2s
	await get_tree().create_timer(1.2).timeout
	var t1 = create_tween()
	t1.tween_method(
		func(v): lore_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, v)),
		0.0, 1.0, 0.8
	)

	# Show restart prompt after 2s
	await get_tree().create_timer(0.8).timeout
	can_restart = true
	var t2 = create_tween()
	t2.tween_method(
		func(v): restart_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, v)),
		0.0, 1.0, 0.5
	)

func _process(_delta: float) -> void:
	if not is_active:
		return
	if can_restart and Input.is_action_just_pressed("restart"):
		_do_restart()

func _do_restart() -> void:
	is_active = false
	can_restart = false
	if video_player:
		video_player.stop()
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

func hide_death() -> void:
	visible = false
	is_active = false
	can_restart = false
	if video_player:
		video_player.stop()
