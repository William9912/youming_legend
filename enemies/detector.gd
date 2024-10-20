extends Area2D

signal detected(hurtbox)
signal exited(hurtbox)

func _init() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _on_area_entered(hurtbox: Hurtbox1) -> void:
	detected.emit(hurtbox)
	
func _on_area_exited(hurtbox: Hurtbox1) -> void:
	exited.emit(hurtbox)
