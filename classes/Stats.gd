class_name Stats 
extends Node

signal  health_changed
signal  energy_changed

@export var max_health: int  = 10
@export var max_energy: float = 100
@export var energy_regen: float = 8

# onready init after export
@onready var health: int = max_health:
	set(v):
		v = clamp(v, 0, max_health)
		if health == v:
			return 
		health = v
		health_changed.emit()

# onready init after export
@onready var energy: float = max_energy:
	set(v):
		v = clampf(v, 0, max_energy)
		if energy == v:
			return 
		energy = v
		energy_changed.emit()

func _process(delta: float) -> void:
	energy += energy_regen * delta


func to_dict() -> Dictionary:
	return {
		max_energy=max_energy,
		max_health=max_health,
		health=health,
	}


func from_dict(dict: Dictionary) -> void:
	max_energy = dict.max_energy
	max_health = dict.max_health
	health = dict.health
