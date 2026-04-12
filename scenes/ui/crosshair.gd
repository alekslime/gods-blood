extends Control

const COLOR = Color(1, 1, 1, 0.9)
const GAP = 5
const LENGTH = 8
const THICKNESS = 2
const DOT = 2

# --- HITMARKER ---
var hit_flash := 0.0       # 0-1, white flash on hit
var kill_flash := 0.0      # 0-1, red flash on kill
var spread := 0.0          # extra gap on hit — lines kick outward

const HIT_FLASH_DURATION := 0.08
const KILL_FLASH_DURATION := 0.18
const HIT_SPREAD := 4.0    # how far lines kick out on hit



func _process(delta: float) -> void:
	var changed = false
	if hit_flash > 0.0:
		hit_flash = move_toward(hit_flash, 0.0, delta / HIT_FLASH_DURATION)
		changed = true
	if kill_flash > 0.0:
		kill_flash = move_toward(kill_flash, 0.0, delta / KILL_FLASH_DURATION)
		changed = true
	spread = lerp(spread, 0.0, delta * 18.0)
	if changed or spread > 0.01:
		queue_redraw()


func on_hit() -> void:
	hit_flash = 1.0
	spread = HIT_SPREAD
	queue_redraw()


func on_kill() -> void:
	kill_flash = 1.0
	hit_flash = 1.0
	spread = HIT_SPREAD * 1.5
	queue_redraw()


func _draw() -> void:
	var center = size / 2
	var current_gap = GAP + spread

	# Color — white normally, flicks to gold on hit, red on kill
	var draw_color = COLOR
	if kill_flash > 0.0:
		draw_color = COLOR.lerp(Color(1.0, 0.15, 0.15, 1.0), kill_flash)
	elif hit_flash > 0.0:
		draw_color = COLOR.lerp(Color(1.0, 0.85, 0.2, 1.0), hit_flash)

	# Left
	draw_line(center + Vector2(-current_gap - LENGTH, 0), center + Vector2(-current_gap, 0), draw_color, THICKNESS)
	# Right
	draw_line(center + Vector2(current_gap, 0), center + Vector2(current_gap + LENGTH, 0), draw_color, THICKNESS)
	# Up
	draw_line(center + Vector2(0, -current_gap - LENGTH), center + Vector2(0, -current_gap), draw_color, THICKNESS)
	# Down
	draw_line(center + Vector2(0, current_gap), center + Vector2(0, current_gap + LENGTH), draw_color, THICKNESS)

	# Center dot — hides on hit, reappears after
	if hit_flash < 0.5 and kill_flash < 0.5:
		draw_rect(Rect2(center - Vector2(DOT * 0.5, DOT * 0.5), Vector2(DOT, DOT)), draw_color)
