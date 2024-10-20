extends Area2D

signal detected(hurtbox)

func _init() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(hurtbox: Hurtbox1) -> void:
	print("[detect] %s - %s" % [owner.name, hurtbox.owner.name])
	detected.emit(hurtbox)
