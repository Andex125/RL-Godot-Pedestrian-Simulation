extends Node3D
class_name LevelManager

## Signal emmitted on episode end
signal notify_end_episode()

var current_level: Node3D

## Resetta tutti gli obiettivi alla fine dell'episodio
func reset_objectives():
	if current_level == null:
		push_error("current_level è null!")
		return
	
	# Trova tutti gli obiettivi nel level corrente
	var objectives = current_level.find_children("objective*")
	for objective in objectives:
		# Riattiva l'obiettivo
		objective.active = true
		objective.monitoring = true
		objective.monitorable = true
		objective.visible = true
		
		# PULISCI TUTTI I FLAG di processing (per tutti i pedestrian)
		var meta_list = objective.get_meta_list()
		for meta_key in meta_list:
			if meta_key.begins_with("processing_"):
				objective.remove_meta(meta_key)
		
		# Riattiva la collisione
		var collision = objective.find_child("CollisionShape3D")
		if collision:
			collision.disabled = false

## Set all the level elements (pedestrians, targets, ai controllers...)
func set_level(level_scene: PackedScene, log_file: FileAccess) -> void:
	# Instantiating level scene
	var level = level_scene.instantiate()
	add_child(level)
	
	current_level = level
	
	# Setup pedestrian
	var pedestrians = level.find_children("Pedestrian*", "Pedestrian")
	for pedestrian in pedestrians:
		pedestrian.can_move = level.can_move
		pedestrian.set_speed_max()
	
	# Setup objective
	var objectives = level.find_children("objective*")
	var objectives_count = objectives.size()

	if objectives != []:
		for objective in objectives:
			objective.collision_layer = 64
			objective.set("active", true)
			objective.add_to_group(Constants.OBJECTIVES_GROUP)
			
			for pedestrian in pedestrians:
				if pedestrian.collision_mask & objective.collision_mask != 0:
					# Usa una lambda unica per evitare connessioni multiple
					var callback = func(body): 
						pedestrian._on_objective_entered(objective, body)
					
					# Disconnetti eventuali connessioni precedenti
					if objective.body_entered.is_connected(callback):
						objective.body_entered.disconnect(callback)
					
					objective.body_entered.connect(callback)
	
	# Trova e configura il nodo Random che contiene l'objective
	var random_node = level.find_child("Random")
	if random_node != null:
		# Verifica che il Random node abbia il metodo get_end_episode
		if random_node.has_method("get_end_episode"):
			# Connetti il segnale per il reset a fine episodio
			if not notify_end_episode.is_connected(random_node.get_end_episode):
				notify_end_episode.connect(random_node.get_end_episode)
	
	# Setup final target
	var level_goals = level.find_children("FinalTarget*")
	for pedestrian in pedestrians:
		for level_goal in level_goals:
			if pedestrian.collision_mask & level_goal.collision_mask != 0:
				level_goal.body_entered.connect(pedestrian._on_final_target_entered)
	
	# Setup intermediate targets
	var targets := []
	targets.append_array(level.find_children("Target*", "Area3D"))
	targets.append_array(level.find_children("ObliqueTarget*", "Area3D"))
	
	for t in targets:
		for pedestrian in pedestrians:
			if pedestrian.collision_mask & t.collision_mask != 0:
				t.custom_body_entered.connect(pedestrian._on_target_entered)
	
	# Setup random target when end episode
	var random_target = level.find_child("RandomTarget")
	if random_target != null: 
		if not notify_end_episode.is_connected(random_target.get_end_episode):
			notify_end_episode.connect(random_target.get_end_episode)
	
	# Setup random spawn when end episode
	var random_spawn = level.find_child("RandomArea")
	
	# Setup random objective when end episode
	var random_objective = level.find_child("RandomObjective")
	if random_objective != null:
		if not notify_end_episode.is_connected(random_objective.get_end_episode):
			notify_end_episode.connect(random_objective.get_end_episode)
	
	# Reset obiettivi quando finisce l'episodio
	if not notify_end_episode.is_connected(reset_objectives):
		notify_end_episode.connect(reset_objectives)
	
	# Setup random passage when end episode
	var random_passage = level.find_child("RandomPassage")
	if random_passage != null:
		if not notify_end_episode.is_connected(random_passage.get_end_episode):
			notify_end_episode.connect(random_passage.get_end_episode)
	
	# Setup ai controller
	for pedestrian in pedestrians:
		var ai_controller = pedestrian.find_child("AIController3D")
		ai_controller.set_reset_after(level.max_steps)
	
	# Setup pedestrians controller
	var pedestrian_controller = level.find_child("PedestrianController")
	pedestrian_controller.log_file = log_file
	pedestrian_controller.random_area = random_spawn
	pedestrian_controller.random_rot = level.agent_rotate
	pedestrian_controller.init(self)
	pedestrian_controller.set_objectives_count(objectives_count) 
	pedestrian_controller.set_pedestrians_initial_state()

## Function called to emit signal for episode ending
func trigger_end_episode() -> void:
	notify_end_episode.emit()
