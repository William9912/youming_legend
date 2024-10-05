class_name StateMachine
extends Node

# 加了这个的原因是因为HURT再到一次HURT就不会走transition_state这个函数　无法清空待处理伤害
const KEEP_CURRENT := -1

var current_state: int = -1:
	set(v):
		owner.transition_state(current_state, v)
		current_state = v
		state_time = 0

#计算当前状态时间
var state_time: float 

func _ready() -> void:
	# 子节点先ready 需要等待父节点ready
	await owner.ready
	current_state = 0

func _physics_process(delta: float) -> void:
	while true:
		var next := owner.get_next_state(current_state) as int 
		if next == KEEP_CURRENT:
			break
		current_state = next

	owner.tick_physics(current_state,delta)
	state_time += delta
