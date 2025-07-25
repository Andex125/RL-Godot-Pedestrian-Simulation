extends Node3D
class_name PedestrianController

@onready var reward_label = $"../Reward"

var level_manager: LevelManager

var pedestrians: Array = []  
var pedestrian_done: Dictionary = {}
var initial_pos: Dictionary = {}
var initial_rot: Dictionary = {}
var ped_cycle_counter: Dictionary = {}

var random_area: Area3D
var random_rot: bool 

var tot_reward: float = 0.0

var log_file: FileAccess
var sample_frame_count: int = 0
var ticks_between_log: int = Constants.TICKS_BETWEEN_LOG
var tick_counter: int = 0

var current_level_objectives_count: int = 0

func set_objectives_count(count: int):
	current_level_objectives_count = count
	update_pedestrians_objectives_count()

func update_pedestrians_objectives_count():
	for p in pedestrians:
		p.set_objectives_count(current_level_objectives_count)

## Initialize the pedestrian controller with a level manager
func init(lm: LevelManager):
	level_manager = lm

## Called when the node is added to the scene
func _ready():
	get_pedestrians()

## Get all pedestrians
func get_pedestrians():
	pedestrians = find_children('Pedestrian*')
	for p in pedestrians:
		pedestrian_done[p] = false

## Set initial pos and rot for each pedestrian
func set_pedestrians_initial_state():
	for p in pedestrians:
		initial_pos[p] = p.global_position
		initial_rot[p] = p.rotation if not random_rot else get_randomized_rotation 
		ped_cycle_counter[p] = 0

## perform randomization of pedestrian position
func randomize_pos():
	var collision_shape = random_area.find_child("CollisionShapeSpawn") as CollisionShape3D
	var box_shape = collision_shape.shape as BoxShape3D
	var extents = box_shape.extents
	var random_pos = Vector3(
		randf_range(-extents.x, extents.x),
		0.0,  
		randf_range(-extents.z, extents.z)
		)
	return random_pos
	
## perform randomization of pedestrian rotation 
func get_randomized_rotation():
	# ✅ Usa variabile locale con nome diverso
	var rotation_value = randi_range(0, Constants.ROTATION_STEPS - 1) * (360.0 / float(Constants.ROTATION_STEPS)) 
	return Vector3(0.0, deg_to_rad(rotation_value), 0.0) 

## Returns spawn current position
func get_spawn_position(pedestrian: Pedestrian) -> Vector3:
	if random_area != null:
		return initial_pos[pedestrian] + randomize_pos()
	return initial_pos[pedestrian]

## Returns spawn current rotation
func get_spawn_rotation(pedestrian: Pedestrian) -> Vector3:
	if initial_rot[pedestrian] is Vector3:
		return initial_rot[pedestrian]
	return initial_rot[pedestrian].call()
	
## Set current reward in reward label
func set_reward_label_text(reward: float) -> void:
	tot_reward += reward
	var formatted_str = 'Score: %4.4f' % tot_reward
	reward_label.set_text(formatted_str)
	
## Check if all pedestrians have finished
func check_end_episode():
	if not all_pedestrians_done():
		return
	
	var final_target_reached = all_pedestrians_reached_target()
	pedestrians[0].ai_controller_3d.reward += Constants.FINAL_TARGET_REW if final_target_reached else Constants.END_OF_TIMESTEPS_REW
	
	reset_pedestrians()
	tot_reward = 0
	level_manager.trigger_end_episode()
	
## Check if all pedestrians are done
func all_pedestrians_done() -> bool:
	for done in pedestrian_done.values():
		if not done:
			return false
	return true
	
## Check if all pedestrians have reached their final target
func all_pedestrians_reached_target() -> bool:
	for p in pedestrians:
		if not p.final_target_reached:
			return false
	return true

## Reset all pedestrians for the next episode
func reset_pedestrians():
	for p in pedestrians:
		p.ai_controller_3d.reset()
		p.reset()
		pedestrian_done[p] = false
		p.enable_pedestrian()
		p.set_objectives_count(current_level_objectives_count)
		ped_cycle_counter[p] += 1
	# ai controller done for only the first pedestrian to end the episode only one time
	pedestrians[0].ai_controller_3d.done = true
			
## Set a single pedestrian as finished
func set_end_episode(pedestrian):
	pedestrian_done[pedestrian] = true
	check_end_episode()
	
## Process function to handle timestep counting and data sampling
func _process(_delta):
	if log_file != null:
		tick_counter += 1
		tick_counter %= Engine.physics_ticks_per_second
		
		if tick_counter % ticks_between_log == 0:
			sample_data()

## Sample data from all pedestrians
func sample_data():
	for p in pedestrians:
		var id = str(p.get_instance_id()) + str(ped_cycle_counter[p])
		var x = p.global_position.x - level_manager.global_position.x
		var y = p.global_position.y - level_manager.global_position.y
		var z = p.global_position.z - level_manager.global_position.z
		var group = p.collision_layer - 2
		var data_line = str(id) + " " + str(sample_frame_count) + " " + str(x) + " " + str(-z) + " " + str(y) + " " + str(group)
		log_file.store_line(data_line)
	sample_frame_count += 1
