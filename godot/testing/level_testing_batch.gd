extends LevelBatch

var end_episode_count: int = 0
const number_of_episode:= Constants.DEFAULT_NUMBER_OF_EPISODE

@onready var sync = $Sync

## Called when the node enters the scene tree for the first time
func _ready():
	batch_size = Constants.TESTING_BATCH_SIZE

	# Usa Constants.PATH_PEDPY_LOGS invece di 'path'
	var log_path = Constants.PATH_PEDPY_LOGS + name + ".txt"
	pedpy_log_file = FileAccess.open(log_path, FileAccess.WRITE)
	
	if pedpy_log_file:
		init_sample_file()
	else:
		push_error("Errore: impossibile aprire il file di log: " + log_path)
	
	spawn_level_managers()
	sync.onnx_model_path = get_parent().onnx_model_path


## Spawns the level managers according to batch size
func spawn_level_managers() -> void:
	# Generating batch of level managers
	for i in range(batch_size):
		var level_manager_instance := level_manager_scene.instantiate()
		level_manager_instance.set_name("LevelManager" + str(i))
		level_manager_instance.position.x = i * level_position_offset
		level_manager_instance.notify_end_episode.connect(_on_notify_end_episode)

		level_managers.append(level_manager_instance)
		add_child(level_manager_instance)
		level_manager_instance.set_level(level, pedpy_log_file)
		
		var level_node = level_manager_instance.current_level
		if level_node:
			level_node.max_steps = Constants.TESTING_MAX_TIMESTEPS
			# Aggiorna anche l'AI controller
			var pedestrians = level_node.find_children("Pedestrian*", "Pedestrian")
			for pedestrian in pedestrians:
				var ai_controller = pedestrian.find_child("AIController3D")
				if ai_controller:
					ai_controller.set_reset_after(Constants.TESTING_MAX_TIMESTEPS)

## Initialize the sample file
func init_sample_file():
	pedpy_log_file.store_line("# framerate: %s fps" %
		(Constants.PHYSICS_TICKS_PER_SECONDS / Constants.TICKS_BETWEEN_LOG))
	pedpy_log_file.store_line("# id frame x/m y/m z/m")

## Episode counter
func _on_notify_end_episode():
	end_episode_count += 1
	check_end_level()

## Check if episode count reached the number of episode
func check_end_level():
	if end_episode_count >= number_of_episode:
		finish()

## Close file when the node is removed from the scene
func _exit_tree():
	if pedpy_log_file:
		pedpy_log_file.close()
