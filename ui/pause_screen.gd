extends Control

@onready var resume: Button = $VBoxContainer/Actions/HBoxContainer/Resume

func _ready() -> void:
	hide()
	SoundManager.set_up_ui_sounds(self)
	
	visibility_changed.connect(func ():
		get_tree().paused = visible
	)

func show_pause() -> void:
	show()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		hide()
		get_window().set_input_as_handled()

func _on_resume_pressed() -> void:
	hide() # Replace with function body.
	resume.grab_focus()

func _on_quit_pressed() -> void:
	Game.back_to_title() # Replace with function body.
