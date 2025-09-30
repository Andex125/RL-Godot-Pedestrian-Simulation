extends Randomizer

@onready var pedestrian = $PedestrianController/Pedestrian
@onready var final_target = $FinalTarget
@onready var area_up = $up/CollisionShape1      # Area sopra
@onready var area_down = $down/CollisionShape2  # Area sotto

var current_configuration: int = 0

func _ready():
	var unique_seed = int(global_position.x * 1000) + Time.get_ticks_msec()
	seed(unique_seed)
	randomize_level_configuration()

func set_random():
	randomize_level_configuration()

func randomize_level_configuration():
	current_configuration = (current_configuration + 1) % 2
	apply_configuration()

func apply_configuration():	
	match current_configuration:
		0:  # Config 0: Pedone SOPRA, Target SOTTO (lati opposti)
			_position_entity_in_area(pedestrian, area_up)
			_position_entity_in_area(final_target, area_down)
			
		1:  # Config 1: Pedone SOTTO, Target SOPRA (lati opposti)
			_position_entity_in_area(pedestrian, area_down)
			_position_entity_in_area(final_target, area_up)

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
