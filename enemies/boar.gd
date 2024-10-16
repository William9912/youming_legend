extends Enemy
enum State {
	IDLE,
	WALK,
	RUN,
	HURT,
	DYING,
}

const KNOCKBACK_AMOUNT := 512.0
@export var max_health_boar := 5

var pending_damage:Damage

@onready var wall_checker: RayCast2D = $Graphics/WallChecker
@onready var play_checker: RayCast2D = $Graphics/PlayChecker
@onready var floor_checker: RayCast2D = $Graphics/FloorChecker
@onready var calm_down_timer: Timer = $CalmDownTimer
@onready var stats: Stats = $EnemyStats


func can_see_player() -> bool:
	if not play_checker.is_colliding():
		return false
	return play_checker.get_collider() is Player
	
func tick_physics(state: State, delta: float) -> void:
	match state:
		State.IDLE, State.HURT, State.DYING:
			move(0.0,delta)
		State.WALK:
			move(max_speed / 3, delta)
		State.RUN:
			if wall_checker.is_colliding() or not floor_checker.is_colliding():
				direction *= -1
			move(max_speed, delta)
			if can_see_player():
				calm_down_timer.start()

func get_next_state(state: State) -> int:
	
	if stats.health == 0:
		return StateMachine.KEEP_CURRENT if state == State.DYING else State.DYING
	
	if pending_damage:
		return State.HURT
	
	match state:
		State.IDLE:
			if can_see_player():
				return State.RUN
			if state_machine.state_time > 2:
				return State.WALK
		State.WALK:
			if can_see_player():
				return State.RUN
			if wall_checker.is_colliding() or not floor_checker.is_colliding():
				return State.IDLE
		State.RUN:
			if not can_see_player() and calm_down_timer.is_stopped():
				return State.WALK
		State.HURT:
			if not animation_player.is_playing():
				return State.RUN
	return StateMachine.KEEP_CURRENT

func transition_state(from: State, to: State) -> void:
	# print(Engine.get_physics_frames())
	match to:
		State.IDLE:
			animation_player.play("idle")
			if wall_checker.is_colliding():
				direction *= -1
		
		State.RUN:
			animation_player.play("run")
			
		State.WALK:
			animation_player.play("walk")
			if not floor_checker.is_colliding():
				direction *= -1
				# 每次_physics_process更新之前 會更新cast 并且缓存 之后调用会读取缓存值 所以需要强制更新
				floor_checker.force_raycast_update()

		State.HURT:
			animation_player.play("hit")

			stats.health -= pending_damage.amount

			var dir := pending_damage.source.global_position.direction_to(global_position)
			velocity = dir * KNOCKBACK_AMOUNT
			
			if dir.x > 0:
				direction = Direction.LEFT
			else:
				direction = Direction.RIGHT
			
			pending_damage = null

		State.DYING:
			animation_player.play("die")
	# 子弹时间！
	#if to == State.WALL_JUMP:
		#Engine.time_scale = 0.3
	## 其实我有个疑问 难道不是下一帧Engine.time_scale就变回来了吗 
	## 因为只有当设定current_state值的时候才会走到这 但是在stateMACHINE.gd里 FROM==TO的时候 不会设置
	#if from == State.WALL_JUMP:
		#Engine.time_scale = 1.0
			


func _on_hurtbox_hurt(hitbox: Hitbox1) -> void:
	print("ouch !!!") # Replace with function body.
	pending_damage = Damage.new()
	pending_damage.amount = 1
	pending_damage.source = hitbox.owner
