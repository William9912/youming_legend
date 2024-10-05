extends Control

const LINES := [
	"TNS被打败了！",
	"字节跳动又恢复了往日的宁静",
	"谢谢你 字节侠",
]

var current_line := -1

var tween: Tween
@onready var label: Label = $Label

func _ready() -> void:
	show_line(0)

func show_line(line: int) -> void:
	current_line = line 
	
	tween = create_tween()
	
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	
	if  line > 0 :
		tween.tween_property(label,"modulate:a", 0,1)
	else:
		label.modulate.a = 0
	
	#试试另一种写法 tween_callback 需要一个方法参数
	tween.tween_callback(label.set_text.bind(LINES[line])) 
	
	tween.tween_property(label,"modulate:a", 1,1)

func _input(event: InputEvent) -> void:
	get_window().set_input_as_handled()
	if tween.is_running():
		return
	if (
		event is InputEventKey or  
		event is InputEventJoypadButton or  
		event is InputEventMouseMotion or 
		event is InputEventScreenTouch
	):
		if event.is_pressed() and not event.is_echo():
			if current_line + 1 < LINES.size():
				show_line(current_line + 1)
			else:
				Game.back_to_title()
