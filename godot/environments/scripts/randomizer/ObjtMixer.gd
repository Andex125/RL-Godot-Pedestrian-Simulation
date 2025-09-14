extends Randomizer

@onready var obj = $objective
@onready var area_up = $Area/CollisionShape1      # Area sx
@onready var area_down = $Area2/CollisionShape2  # Area dx

var current_configuration: int = 0

func _ready():
	var unique_seed = int(global_position.x * 1000) + Time.get_ticks_msec()
	seed(unique_seed)
	randomize_level_configuration()

func set_random():
	randomize_level_configuration()

func randomize_level_configuration():
	current_configuration = randi() % 2
	apply_configuration()

func apply_configuration():	
	match current_configuration:
		0:  # Config 0: Pedone SOPRA, Target SOTTO (lati opposti)
			_position_entity_in_area(obj, area_up)
			
		1:  # Config 1: Pedone SOTTO, Target SOPRA (lati opposti)
			_position_entity_in_area(obj, area_down)

func _position_entity_in_area(entity_node: Node3D, area_node: Node3D):
	entity = entity_node
	entity.global_position = area_node.global_position
	
	if randomize_position:
		randomize_pos(area_node)
	
	if randomize_rotation:
		randomize_rot()
	
	entity.visible = true

func get_end_episode():
	randomize_level_configuration()
