extends Node
class_name LevelBatch

@export var level: PackedScene
var batch_size: int = Constants.TRAINING_BATCH_SIZE

var level_manager_scene: PackedScene = preload("res://environments/level_manager.tscn")
var level_managers: Array = []
const level_position_offset: int = Constants.LEVELS_BATCH_OFFSET

# NUOVO: Variabili per il salvataggio dei log
var pedpy_log_file: FileAccess = null
var log_file_path: String = ""

## Called when the node enters the scene tree for the first time
func _ready():
	# NUOVO: Inizializza il file di log se abilitato
	if Constants.SAVE_TRAINING_TRAJECTORIES:
		initialize_log_file()
	
	spawn_level_managers()

## NUOVO: Inizializza il file di log con timestamp
func initialize_log_file():
	# Ottieni o crea la session ID
	var session_id = get_or_create_session_id()
	
	# Costruisci il path: output/runs/training/session_TIMESTAMP/LIVELLO/
	var base_path = "res://../output/runs/training/" + session_id + "/"
	var level_path = base_path + name + "/"
	
	# Crea le directory
	create_directories(level_path)
	
	# Costruisci il nome del file
	var file_name = "trajectories.txt"
	log_file_path = level_path + file_name
	
	# Apri il file in modalità scrittura
	pedpy_log_file = FileAccess.open(log_file_path, FileAccess.WRITE)
	
	if pedpy_log_file:
		# Scrivi l'header del file
		pedpy_log_file.store_line("# framerate: %s fps" %
			(Constants.PHYSICS_TICKS_PER_SECONDS / Constants.TICKS_BETWEEN_LOG))
		pedpy_log_file.store_line("# id frame x/m y/m z/m")
		print("✅ Training trajectories will be saved to: ", log_file_path)
	else:
		push_error("❌ Failed to open training log file: " + log_file_path)

## NUOVO: Ottieni o crea un session ID condiviso per tutta la sessione di training
func get_or_create_session_id() -> String:
	var session_file_path = "res://../output/runs/training/current_session.txt"
	
	# Prova a leggere una session esistente
	var session_file = FileAccess.open(session_file_path, FileAccess.READ)
	if session_file:
		var existing_session = session_file.get_line().strip_edges()
		session_file.close()
		print("📂 Reusing session from previous level: ", existing_session)
		return existing_session
	
	# Crea una nuova session con timestamp
	var datetime = Time.get_datetime_dict_from_system()
	var session_id = "session_%04d-%02d-%02d_%02d-%02d-%02d" % [
		datetime.year,
		datetime.month,
		datetime.day,
		datetime.hour,
		datetime.minute,
		datetime.second
	]
	
	# Crea la directory se non esiste
	create_directories("res://../output/runs/training/")
	
	# Salva la nuova session
	session_file = FileAccess.open(session_file_path, FileAccess.WRITE)
	if session_file:
		session_file.store_line(session_id)
		session_file.close()
	
	print("🆕 Created new training session: ", session_id)
	return session_id

## NUOVO: Crea ricorsivamente le directory necessarie
func create_directories(path: String):
	# Rimuovi il prefisso "res://../"
	var relative_path = path.replace("res://../", "")
	
	# Usa DirAccess per creare directory ricorsivamente
	var dir = DirAccess.open("user://")
	if not dir:
		# Se fallisce con user://, prova con res://
		dir = DirAccess.open("res://")
	
	if not dir:
		push_error("Cannot access filesystem")
		return
	
	# Naviga alla directory di output
	var output_path = ProjectSettings.globalize_path("res://../" + relative_path)
	
	# Usa make_dir_recursive che crea tutte le directory intermedie
	var error = DirAccess.make_dir_recursive_absolute(output_path)
	if error != OK:
		push_error("Failed to create directory: " + output_path + " Error: " + str(error))
	else:
		print("📁 Created directory: ", relative_path)

## Spawns the level managers according to batch size
func spawn_level_managers() -> void:
	# Generating batch of level managers
	for i in range(batch_size):
		var level_manager_instance := level_manager_scene.instantiate()
		level_manager_instance.set_name("LevelManager" + str(i))
		level_manager_instance.position.x = i * level_position_offset
		
		level_managers.append(level_manager_instance)
		add_child(level_manager_instance)
		
		# MODIFICA: Passa il file di log E l'instance_id se abilitato
		if Constants.SAVE_TRAINING_TRAJECTORIES and pedpy_log_file:
			level_manager_instance.set_level(level, pedpy_log_file)
			level_manager_instance.set_instance_id(i)
		else:
			level_manager_instance.set_level(level, null)

## End the level
func finish():
	# NUOVO: Chiudi il file di log prima di terminare
	if pedpy_log_file:
		pedpy_log_file.close()
		print("💾 Training trajectories saved to: ", log_file_path)
	
	var all_agents = get_tree().get_nodes_in_group(Constants.AGENT_GROUP)
	for agent in all_agents:
		agent.remove_from_group(Constants.AGENT_GROUP)
	get_parent().set_current_level()

## NUOVO: Chiudi il file quando il nodo viene rimosso dalla scena
func _exit_tree():
	if pedpy_log_file:
		pedpy_log_file.close()
