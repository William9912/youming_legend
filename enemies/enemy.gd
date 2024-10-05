class_name Enemy

extends CharacterBody2D

enum Direction {
	LEFT = -1,
	RIGHT = 1,
}

signal died

var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float

@export var direction := Direction.LEFT:
	set(v):
		direction = v
		# 素材朝左 右才需要翻转
		if not is_node_ready():
			await ready 
		graphics.scale.x = -direction
		
@export var max_speed: float = 180
@export var acceleration: float = 2000

@onready var graphics: Node2D = $Graphics
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var state_machine: StateMachine = $StateMachine
# todo 敌人和玩家应该有区分
@onready var enemy_stats: Stats = $EnemyStats

func _ready() -> void:
	add_to_group("enemies")
	
func move(speed: float, delta: float) -> void:
	velocity.x  = move_toward(velocity.x, speed * direction, acceleration * delta) #direction * RUN_SPEED
	# 这个velocity的单位是像素每秒 所以Y += 的话 其实满足现实的重力加速度	
	velocity.y += default_gravity * delta
	move_and_slide()

func die() -> void:
	died.emit()
	queue_free()
