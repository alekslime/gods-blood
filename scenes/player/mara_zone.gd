extends Area3D

@export var mara_line : String = "Zone 1 — They came in the night."
var has_played := false

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if has_played:
		return
	if body.is_in_group("player"):
		has_played = true
		var audio = $Audio
		if audio.stream != null:
			audio.play()
		# Debug — remove later
		print("MARA: ", mara_line)
