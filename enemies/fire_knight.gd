extends CharacterBody2D


enum Direction {
	LEFT = -1,
	RIGHT = 1,
}

signal died

var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float
var main_ms: LimboHSM
var targets : Array[Player]

@export var teleport_distance = 40  # 瞬移到玩家身后的距离

@export var direction := Direction.LEFT:
	set(v):
		direction = v
		# 素材朝左 右才需要翻转
		if not is_node_ready():
			await ready 
		graphics.scale.x = direction
		
@export var max_speed: float = 70
@export var acceleration: float = 2000

@onready var play_checker: RayCast2D = $Graphics/PlayChecker
@onready var graphics: Node2D = $Graphics
@onready var animation_player: AnimationPlayer = $AnimationPlayer
# todo 敌人和玩家应该有区分
@onready var enemy_stats: Stats = $EnemyStats
@onready var detector: Area2D = $Graphics/detector
@onready var flash_checker: RayCast2D = $Graphics/FlashChecker


func can_see_player() -> bool:
	if not play_checker.is_colliding():
		return false
	return play_checker.get_collider() is Player
	

func _ready() -> void:
	add_to_group("enemies")
	initate_state_machine()
	detector.detected.connect(_on_detected_player)
	detector.area_exited.connect(_on_detected_player_exit)
	
func move(speed: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, speed * direction, acceleration * delta) #direction * RUN_SPEED
	# 这个velocity的单位是像素每秒 所以Y += 的话 其实满足现实的重力加速度	
	velocity.y += default_gravity * delta
	move_and_slide()

func die() -> void:
	died.emit()
	queue_free()
	
func _physics_process(delta: float) -> void:
	move(max_speed, delta)

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
	main_ms.add_transition(main_ms.ANYSTATE, attack_state, &"to_attack")
		
	main_ms.initialize(self)
	main_ms.set_active(true)

func idle_start():
	animation_player.play("idle")

func idle_update(delta: float):
	if len(targets) != 0:
		main_ms.dispatch(&"to_walk")

func walk_start():
	animation_player.play("run")

func walk_update(delta: float):
	if len(targets) == 0:
		main_ms.dispatch(&"state_ended")
		return 
	var dir = targets.back().global_position - global_position
	var dirx = dir.x
	var distance = dir.length()
	
	if not could_achieve_player(targets.back()):
		teleport_behind_player(targets.back())
	
	if abs(distance) < 30:
		main_ms.dispatch(&"to_attack")
	if dirx < 0:
		direction = Direction.LEFT
	else:
		direction = Direction.RIGHT

func could_achieve_player(player: Player) -> bool:
	if not player:
		return false
	var to_player = player.global_position - global_position
	var distance_to_player = to_player.length()
	flash_checker.target_position = to_player
	flash_checker.force_raycast_update()
	var wall_between = flash_checker.is_colliding()
	return not wall_between
	
func teleport_behind_player(player: Player):
	if player:
		# 计算从玩家到敌人的方向
		var player_to_enemy = global_position - player.global_position
		
		# 标准化这个方向并乘以瞬移距离
		var teleport_position = player.global_position + player_to_enemy.normalized() * teleport_distance
		
		# 瞬移敌人
		global_position = teleport_position
		
		print("敌人已瞬移到玩家身后 ", teleport_distance, " 像素处")

func jump_start():
	pass

func jump_update(delta: float):
	pass
	
func attack_start():
	animation_player.play("attack1")

func attack_update(delta: float):
	if not animation_player.is_playing():
		main_ms.dispatch(&"state_ended")

func _on_detected_player(hurtbox: Hurtbox1) -> void:
	print("_on_detected_player") # Replace with function body.
	targets.append(hurtbox.owner)

func _on_detected_player_exit(hurtbox: Hurtbox1) -> void:
	targets.erase(hurtbox.owner)
