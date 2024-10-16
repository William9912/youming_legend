extends Area2D

@export var speed = 200
@export var damage = 1

var direction:Vector2

func set_direction(bulletDirection):
	direction = bulletDirection
	rotation_degrees = rad_to_deg(global_position.angle_to_point(global_position + direction))

func _physics_process(delta):
	global_position += direction * delta * speed

func _ready() -> void:
	await  get_tree().create_timer(3).timeout
	queue_free()
	

func _on_area_entered(area: Area2D) -> void:
	print(area.get_parent().get_parent())
	if area.get_parent().get_parent().is_in_group("enemy"):
		queue_free() # Replace with function body.
