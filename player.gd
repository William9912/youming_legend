class_name Player

extends CharacterBody2D

var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float
var is_first_tick := false
var is_commbo_requested := false
var pending_damage: Damage
var fall_from_y: float
var interacting_with : Array[Interactable]
var bullteDirection = Vector2(1, 0)

enum  Direction {
	LEFT = -1,
	RIGHT = +1,
}
enum State {
	IDLE,
	RUNNING,
	JUMP,
	FALL,
	LANDING,
	WALL_SLIDING,
	WALL_JUMP, 
	ATTACK_1,
	ATTACK_2,
	ATTACK_3,
	HURT,
	DYING,
	SLIDING_START,
	SLIDING_LOOP,
	SLIDING_END,
}

@export var direction := Direction.RIGHT:
	set(v):
		direction = v
		if not is_node_ready():
			await ready
		graphics.scale.x = direction

@export var can_combo := false
const KNOCKBACK_AMOUNT := 512.0
const WALL_JUMP_VELOCITY := Vector2(380, -280)
const GROUND_STATES := [State.IDLE, State.RUNNING, State.LANDING,State.ATTACK_1,State.ATTACK_2,
State.ATTACK_3,State.HURT, State.DYING]
const RUN_SPEED := 160.0
const JUMP_VELOCITY := -320.0 # 这是一个速度单位 像素每秒
const FLOOR_ACCELERATION := RUN_SPEED / 0.2 # 这是一个加速度单位
# 这个是空中转身加速度
const AIR_ACCELERATION := RUN_SPEED / 0.1 # 这是一个加速度单位 除数越小 加速度越大
const SLIDING_DURATION := 0.3
const SLIDING_SPEED := 300.0
const LANDING_HIGHT := 100.0
const SLIDING_ENERGT := 40.0
const BULLTE = preload("res://objects/bullet.tscn")

@onready var graphics: Node2D = $Graphics
@onready var animation_player: AnimationPlayer = $AnimationPlayer
# 这个是走下山崖的时候0.1秒能跳
@onready var coyote_timer: Timer = $CoyoteTimer
# 这个是落地前0.1秒按跳能落地瞬间跳起来
@onready var jump_request_timer: Timer = $JumpRequestTimer
@onready var stats:Node = Game.player_stats
@onready var foot_checker: RayCast2D = $Graphics/FootChecker
@onready var hand_checker: RayCast2D = $Graphics/HandChecker
@onready var state_machine: StateMachine = $StateMachine
@onready var invincible_timer: Timer = $InvincibleTimer
@onready var slide_request_timer: Timer = $SlideRequestTimer
@onready var interaction_icon: AnimatedSprite2D = $InteractionIcon
@onready var game_over_screen: Control = $CanvasLayer/GameOverScreen
@onready var attack: AudioStreamPlayer = $Attack
@onready var jump: AudioStreamPlayer = $Jump
@onready var pause_screen: Control = $CanvasLayer/PauseScreen
@onready var buttle_mark: Marker2D = $Graphics/ButtleMark

# 这个地方不应该和敌人公用 先这么写吧
func _ready() -> void:
	stand(default_gravity, 0.01)

# 平地第一次起跳 jump_request_timer 启动
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_request_timer.start()
		
	# d短按 没加速到一半就送开了
	if event.is_action_released("jump"):
		jump_request_timer.stop()
		if velocity.y < JUMP_VELOCITY / 2:
			velocity.y = JUMP_VELOCITY / 2
	if event.is_action_pressed("attack") and can_combo:
		is_commbo_requested = true
	if event.is_action_pressed("slide"):
		slide_request_timer.start()
	if event.is_action_pressed("interact") and len(interacting_with) != 0:
		interacting_with.back().interact()
	if event.is_action_pressed("pause"):
		pause_screen.show_pause()

func sparkle_sprite()-> void:
	# Time.get_ticks_msec() 相對於游戏开始经过了多少毫秒
	graphics.modulate.a = sin(Time.get_ticks_msec() / 25) * 0.5 + 0.5	


func tick_physics(state: State, delta: float) -> void:
	interaction_icon.visible = len(interacting_with) != 0
	if invincible_timer.time_left >0.0:
		sparkle_sprite()
	else:
		graphics.modulate.a = 1.0
	match state:
		State.IDLE:
			move(default_gravity, delta)
		State.RUNNING:
			move(default_gravity, delta)
		State.JUMP:
			move(0.0 if is_first_tick else default_gravity, delta)
		State.FALL:
			move(default_gravity, delta)
		State.LANDING:
			stand(default_gravity,delta)
		State.WALL_SLIDING:
			move(default_gravity/3, delta)
			direction = Direction.LEFT if get_wall_normal().x < 0 else Direction.RIGHT
		State.WALL_JUMP:
			# 这个时间内 不受横向键影响
			if state_machine.state_time < 0.1:
				stand(0.0 if is_first_tick else default_gravity,delta)
				# 强制转身
				direction = Direction.LEFT if get_wall_normal().x < 0 else Direction.RIGHT
			else:
				# 第一帧肯定走上面
				move(default_gravity, delta)
		State.ATTACK_1, State.ATTACK_2, State.ATTACK_3:
			stand(default_gravity, delta)
		
		# 这里和教程不一样 我想死亡的时候被击退 像死亡细胞
		State.HURT:
			velocity = Vector2(0, 0)
			stand(default_gravity, delta)
		State.DYING:
			move_dying(default_gravity, delta)
		State.SLIDING_END:
			stand(default_gravity, delta)
		State.SLIDING_START, State.SLIDING_LOOP:
			slide(delta)
	is_first_tick = false

func move_dying(gravity:float, delta: float) -> void:
	# delta是一个时间单位 两帧之间多少秒 60帧的话 DELTA = 1/60
	# 这个velocity的单位是像素每秒 所以Y += 的话 其实满足现实的重力加速度	
	velocity.y += gravity * delta
		
	move_and_slide()	
func move(gravity:float, delta: float) -> void:
	# delta是一个时间单位 两帧之间多少秒 60帧的话 DELTA = 1/60
	var movement := Input.get_axis("move_left","move_right")
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	# 这个的意思是想达到direction * RUN_SPEED 这个速度 每帧的增加的速度是ACCELERATION * delta  ACCELERATION是加速度 DELTA是时间单位
	velocity.x  = move_toward(velocity.x, movement * RUN_SPEED, acceleration * delta) #movement * RUN_SPEED
	# 这个velocity的单位是像素每秒 所以Y += 的话 其实满足现实的重力加速度	
	velocity.y += gravity * delta

		
	if not is_zero_approx(movement):
		direction = Direction.LEFT if movement < 0 else Direction.RIGHT
		
	move_and_slide()
	
func stand(gravity:float, delta: float) -> void:
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	# 无法在着陆动画的时候改变X
	velocity.x  = move_toward(velocity.x, 0.0, acceleration * delta) #movement * RUN_SPEED
	# 这个velocity的单位是像素每秒 所以Y += 的话 其实满足现实的重力加速度	
	velocity.y += gravity * delta
	move_and_slide()

func slide(delta: float) -> void:
	velocity.x = graphics.scale.x * SLIDING_SPEED
	velocity.y += default_gravity * delta

	move_and_slide()

func die() -> void:
	#get_tree().reload_current_scene()
	game_over_screen.show_game_over()
	Game.player_stats.health = Game.player_stats.max_health

func can_wall_slide() -> bool:
	return is_on_wall() and hand_checker.is_colliding() and foot_checker.is_colliding()


func register_interactable(v: Interactable) -> void:
	if state_machine.current_state == State.DYING:
		return
	if v in interacting_with:
		return
	interacting_with.append(v)
	
	
func unregister_interactable(v: Interactable) -> void:
	interacting_with.erase(v)
	
	
func should_slide() -> bool:
	if slide_request_timer.is_stopped():
		return false
	# 这个地方我想抄法环的逻辑
	#if stats.energy < SLIDING_ENERGT:
		#return false
	# 每帧都回复 限制1.5秒不能滑铲
	if stats.energy <= 12:
		return false
	return not foot_checker.is_colliding()
	
func get_next_state(state: State) -> int:
	if stats.health == 0:
		return StateMachine.KEEP_CURRENT if state == State.DYING else State.DYING
	
	if pending_damage:
		return State.HURT
	
	var can_jump := is_on_floor() or coyote_timer.time_left > 0
	# 这里不影响平地第一次起跳 因为jump_request_timer 的时间是0.1 下一帧是0.016 所以下一帧来的时候一定能跳起来
	var should_jump := can_jump and jump_request_timer.time_left > 0
	if should_jump:
		return State.JUMP
	
	if state in GROUND_STATES and not is_on_floor():
		return State.FALL
	
	var movement := Input.get_axis("move_left","move_right")
	var is_still :=  is_zero_approx(movement) and is_zero_approx(velocity.x)
	match state:
		State.IDLE:
			if Input.is_action_just_pressed("attack"):
				return State.ATTACK_1
			if should_slide():
				return State.SLIDING_START
			if not is_still:
				return State.RUNNING
		State.RUNNING:
			if Input.is_action_just_pressed("attack"):
				return State.ATTACK_1
			if should_slide():
				return State.SLIDING_START
			if is_still:
				return State.IDLE
		State.JUMP:
			if velocity.y >= 0:
				return State.FALL
		State.FALL:
			if is_on_floor():
				var height := global_position.y - fall_from_y
				return State.LANDING if height >= LANDING_HIGHT else State.RUNNING
			if can_wall_slide():
				return State.WALL_SLIDING
		State.LANDING:
			if not animation_player.is_playing():
				return State.IDLE
		State.WALL_SLIDING:
			if jump_request_timer.time_left > 0:
				return State.WALL_JUMP
			if is_on_floor():
				return State.IDLE
			if not is_on_wall():
				return State.FALL
		State.WALL_JUMP:
			# 跳到了对面墙 至少一帧之后 不然又回去了 就不能时间放慢了
			if can_wall_slide() and not is_first_tick:
				return State.WALL_SLIDING
			if velocity.y >= 0:
				return State.FALL
		State.ATTACK_1:
			if not animation_player.is_playing():
				return State.ATTACK_2 if is_commbo_requested else State.IDLE
		State.ATTACK_2:
			if not animation_player.is_playing():
				return State.ATTACK_3 if is_commbo_requested else State.IDLE
		State.ATTACK_3:
			if not animation_player.is_playing():
				return State.IDLE
		State.HURT:
			if not animation_player.is_playing():
				return State.IDLE
		State.SLIDING_START:
			if not animation_player.is_playing():
				return State.SLIDING_LOOP
		State.SLIDING_END:
			if not animation_player.is_playing():
				return State.IDLE
		State.SLIDING_LOOP:
			if state_machine.state_time > SLIDING_DURATION or is_on_wall():
				return State.SLIDING_END
	return StateMachine.KEEP_CURRENT	

func transition_state(from: State, to: State) -> void:
	if from not in GROUND_STATES and to in GROUND_STATES:
		coyote_timer.stop()
	# 打印帧数
	# print(Engine.get_physics_frames())
	match to:
		State.IDLE:
			animation_player.play("idle")
		
		State.RUNNING:
			animation_player.play("running")
			
		State.JUMP:
			SoundManager.play_sfx("Jump")
			animation_player.play("jump")
			velocity.y = JUMP_VELOCITY
			coyote_timer.stop()
			jump_request_timer.stop()
			
		State.FALL:
			animation_player.play("fall")
			if from in GROUND_STATES:
				coyote_timer.start()
			fall_from_y = global_position.y
		
		State.LANDING:
			animation_player.play("landing")
			
		State.WALL_SLIDING:
			animation_player.play("wall_sliding")
		
		State.WALL_JUMP:
			animation_player.play("jump")
			velocity = WALL_JUMP_VELOCITY
			velocity.x *= get_wall_normal().x
			coyote_timer.stop()
			jump_request_timer.stop()
		State.ATTACK_1:
			animation_player.play("attack_1")
			SoundManager.play_sfx("Attack")
			
			var bullteNode = BULLTE.instantiate()
			bullteDirection.x = direction
			bullteNode.set_direction(bullteDirection)
			get_tree().root.add_child(bullteNode)
			bullteNode.global_position = buttle_mark.global_position
			
			is_commbo_requested = false
		State.ATTACK_2:
			animation_player.play("attack_2")
			is_commbo_requested = false
		State.ATTACK_3:
			animation_player.play("attack_3")
			is_commbo_requested = false
		State.HURT:
			animation_player.play("hurt")

			stats.health -= pending_damage.amount

			var dir := pending_damage.source.global_position.direction_to(global_position)
			velocity = dir * KNOCKBACK_AMOUNT
			
			pending_damage = null
			invincible_timer.start()

		State.DYING:
			invincible_timer.stop()
			animation_player.play("die")
			SoundManager.play_sfx("Dead")
			interacting_with.clear()
		State.SLIDING_START:
			animation_player.play("sliding_start")
			slide_request_timer.stop()
			# 模仿法环的逻辑
			if stats.energy < SLIDING_ENERGT:
				stats.energy = 0
			else:
				stats.energy -= SLIDING_ENERGT
		State.SLIDING_LOOP:
			animation_player.play("sliding_loop")
		State.SLIDING_END:
			animation_player.play("sliding_end")
	# 子弹时间！
	#if to == State.WALL_JUMP:
		#Engine.time_scale = 0.3
	## 其实我有个疑问 难道不是下一帧Engine.time_scale就变回来了吗 
	## 因为只有当设定current_state值的时候才会走到这 但是在stateMACHINE.gd里 FROM==TO的时候 不会设置
	#if from == State.WALL_JUMP:
		#Engine.time_scale = 1.0
			
	is_first_tick = true


func _on_hurtbox_hurt(hitbox: Variant) -> void:
	if invincible_timer.time_left > 0:
		return
	print("player ouch !!!") # Replace with function body.
	pending_damage = Damage.new()
	pending_damage.amount = 1
	pending_damage.source = hitbox.owner
 # Replace with function body.
