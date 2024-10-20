extends CharacterBody2D


enum Direction {
	LEFT = -1,
	RIGHT = 1,
}

signal died

var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float
var main_ms: LimboHSM

@export var direction := Direction.LEFT:
	set(v):
		direction = v
		# 素材朝左 右才需要翻转
		if not is_node_ready():
			await ready 
		graphics.scale.x = -direction
		
@export var max_speed: float = 180
@export var acceleration: float = 2000

@onready var play_checker: RayCast2D = $Graphics/PlayChecker
@onready var graphics: Node2D = $Graphics
@onready var animation_player: AnimationPlayer = $AnimationPlayer
# todo 敌人和玩家应该有区分
@onready var enemy_stats: Stats = $EnemyStats

func can_see_player() -> bool:
	if not play_checker.is_colliding():
		return false
	return play_checker.get_collider() is Player
	

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
	
func _physics_process(delta: float) -> void:
	move(max_speed/2, delta)

func initate_state_machine():
	main_ms = LimboHSM.new()
	add_child(main_ms)
	
	var idle_state = LimboState.new().named("idle").call_on_enter(idle_start).call_on_update(idle_update)
	var walk_state = LimboState.new().named("walk").call_on_enter(walk_start).call_on_update(walk_update)
	var jump_state = LimboState.new().named("jump").call_on_enter(jump_start).call_on_update(jump_update)
	var attack_state = LimboState.new().named("attack").call_on_enter(attack_start).call_on_update(attack_update)
	
	main_ms.add_child(idle_state)
	main_ms.add_child(walk_state)
	main_ms.add_child(jump_state)
	main_ms.add_child(attack_state)
	
	main_ms.initial_state = idle_state
	
	main_ms.add_transition(idle_state, walk_state, &"to_walk")
	main_ms.add_transition(main_ms.ANYSTATE, idle_state, &"state_ended")
		
	main_ms.initialize(self)
	main_ms.set_active(true)

func idle_start():
	animation_player.play("walk")

func idle_update():
	if velocity.x != 0:
		main_ms.dispatch(&"to_walk")

func walk_start():
	pass

func walk_update():
	pass

func jump_start():
	pass

func jump_update():
	pass
	
func attack_start():
	pass

func attack_update():
	pass
