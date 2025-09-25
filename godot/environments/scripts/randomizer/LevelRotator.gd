extends Randomizer
class_name LevelRotator

@onready var livello = $livello

var rotation_angles = [0, 90, 180, 270]
var current_rotation = 0

func _ready():
	super._ready()
	if livello:
		set_random()

func set_random():
	if livello == null:
		return
	
	var random_index = randi() % rotation_angles.size()
	current_rotation = rotation_angles[random_index]
	
	apply_rotation()

func apply_rotation():
	if livello == null:
		return
		
	livello.rotation_degrees.y = current_rotation

func get_end_episode():
	set_random()
