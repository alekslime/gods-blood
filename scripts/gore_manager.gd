extends Node

const MAX_DECALS := 50
var decals: Array = []

func spawn_blood(pos: Vector3, normal: Vector3, parent: Node) -> void:
	var decal = Decal.new()
	parent.add_child(decal)
	decal.global_position = pos + normal * 0.01

	# Use a different up vector when normal is pointing up
	var up = Vector3.FORWARD if normal.is_equal_approx(Vector3.UP) or normal.is_equal_approx(Vector3.DOWN) else Vector3.UP
	decal.look_at(pos - normal, up)

func _create_blood_texture() -> ImageTexture:
	var size = 64
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	# Draw a rough splat
	var center = Vector2(size / 2, size / 2)
	for x in range(size):
		for y in range(size):
			var dist = Vector2(x, y).distance_to(center)
			var radius = randf_range(size * 0.25, size * 0.45)
			if dist < radius:
				var alpha = 1.0 - (dist / radius) * 0.5
				var red = randf_range(0.4, 0.7)
				image.set_pixel(x, y, Color(red, 0.0, 0.0, alpha))
	
	return ImageTexture.create_from_image(image)
