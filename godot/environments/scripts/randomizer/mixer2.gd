extends Randomizer

@onready var objective = $objective
@onready var final_target = $FinalTarget
@onready var area_o1 = $up/CollisionShapeO1  # Objective sopra
@onready var area_t1 = $up/CollisionShapeT1  # Target sopra  
@onready var area_o2 = $down/CollisionShapeO2  # Objective sotto
@onready var area_t2 = $down/CollisionShapeT2  # Target sotto

var current_configuration: int = 0

func _ready():
	var unique_seed = int(global_position.x * 1000) + Time.get_ticks_msec()
	seed(unique_seed)
	randomize_level_configuration()

func set_random():
	randomize_level_configuration()

func randomize_level_configuration():
	var old_config = current_configuration
	current_configuration = randi() % 2
	apply_configuration()

func apply_configuration():	
	match current_configuration:
		0:  # Config 0: SOPRA
			_position_entity_in_area(objective, area_o1)
			_position_entity_in_area(final_target, area_t1)
			
		1:  # Config 1:  SOTTO
			_position_entity_in_area(objective, area_o2)
			_position_entity_in_area(final_target, area_t2)

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
