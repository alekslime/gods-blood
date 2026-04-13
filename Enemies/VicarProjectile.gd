extends RigidBody3D

var speed := 14.0
var direction := Vector3.ZERO
var lifetime := 6.0
var damage := 18.0

func _ready() -> void:
	gravity_scale = 0.0
	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_on_body_entered)
	linear_velocity = direction * speed

func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.take_damage(damage)
	queue_free()

func initialize(dir: Vector3, spd: float, dmg: float) -> void:
	direction = dir
	speed = spd
	damage = dmg
