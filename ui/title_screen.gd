extends Control
@onready var new_game: Button = $V/NewGame
@onready var v: VBoxContainer = $V
@onready var load_game: Button = $V/LoadGame

func _ready() -> void:
	load_game.disabled = not Game.has_saved()
	new_game.grab_focus()
	
	SoundManager.set_up_ui_sounds(self)
	# 关闭
	SoundManager.play_bgm(preload("res://assets/sound/StreetsandFaces.mp3"))

func _on_new_game_pressed() -> void:
	Game.new_game() # Replace with function body.


func _on_load_game_pressed() -> void:
	Game.load_game()# Replace with function body.


func _on_exit_game_pressed() -> void:
	get_tree().quit()# Replace with function body.
