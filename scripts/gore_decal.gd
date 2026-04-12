extends Decal

const LIFETIME := 30.0
var timer := 0.0


func _process(delta: float) -> void:
	timer += delta
	if timer >= LIFETIME:
		queue_free()
