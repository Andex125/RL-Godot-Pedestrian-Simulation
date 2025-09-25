extends Randomizer
class_name LevelRotator

@export_category("Level Rotation Settings")
@export var level_node: Node3D  # Nodo "livello" da ruotare

# Possibili rotazioni: 90°, 180°, 270° (0° non serve, è la posizione originale)
var possible_rotations: Array[float] = [90.0, 180.0, 270.0]

# Rotazione corrente applicata
var current_rotation: float = 0.0

# Riferimenti ai controller che devono essere aggiornati
var pedestrian_controller: PedestrianController
var original_pedestrian_positions: Dictionary = {}
var original_random_area_position: Vector3

# Called when the node enters the scene tree for the first time.
func _ready():
	# Trova automaticamente il nodo "livello" se non specificato
	if level_node == null:
		level_node = find_child("livello", true, false)
		if level_node == null:
			push_error("ERRORE: Nodo 'livello' non trovato in " + str(get_path()))
			return
	
	# Trova il PedestrianController nella scena
	pedestrian_controller = get_tree().get_first_node_in_group("") as PedestrianController
	if pedestrian_controller == null:
		pedestrian_controller = find_child("PedestrianController", true, false) as PedestrianController
	
	# Non chiamiamo super._ready() perché non ci servono le funzionalità di Randomizer
	# ma inizializziamo comunque un seed unico
	var unique_seed = int(global_position.x * 1000) + Time.get_ticks_msec()
	seed(unique_seed)
	
	# Salva le posizioni originali dei pedoni prima di applicare qualsiasi rotazione
	call_deferred("store_original_positions")
	
	# Applica una rotazione randomica iniziale
	call_deferred("set_random")

# Salva le posizioni originali dei pedoni e delle aree di spawn
func store_original_positions():
	if pedestrian_controller == null:
		# Cerca di nuovo il PedestrianController
		pedestrian_controller = get_node("../PedestrianController") as PedestrianController
		if pedestrian_controller == null:
			print("AVVISO: PedestrianController non trovato, le posizioni di spawn potrebbero non aggiornarsi correttamente")
			return
	
	# Salva le posizioni originali dei pedoni
	for pedestrian in pedestrian_controller.pedestrians:
		if pedestrian_controller.initial_pos.has(pedestrian):
			original_pedestrian_positions[pedestrian] = pedestrian_controller.initial_pos[pedestrian]
	
	# Salva la posizione originale della random area se presente
	if pedestrian_controller.random_area != null:
		original_random_area_position = pedestrian_controller.random_area.global_position

# Override del metodo set_random per ruotare il livello
func set_random():
	if level_node == null:
		push_error("ERRORE: level_node è null in set_random")
		return
	
	# Seleziona una rotazione casuale
	var random_rotation = possible_rotations[randi() % possible_rotations.size()]
	
	# Applica la rotazione attorno al punto (0,0) del livello
	rotate_level(random_rotation)
	
	# Aggiorna le posizioni di spawn dei pedoni
	update_pedestrian_positions()

# Ruota il nodo livello della rotazione specificata
func rotate_level(degrees: float):
	if level_node == null:
		return
	
	# Salva la rotazione corrente
	current_rotation = degrees
	
	# Applica la rotazione attorno all'asse Y (verticale)
	# La rotazione avviene attorno al centro del nodo livello (0,0,0 relative)
	level_node.rotation_degrees = Vector3(0.0, degrees, 0.0)
	
	print("Livello ruotato di " + str(degrees) + "° - Posizione: " + str(global_position))

# Aggiorna le posizioni di spawn dei pedoni basandosi sulla rotazione del livello
func update_pedestrian_positions():
	if pedestrian_controller == null or original_pedestrian_positions.is_empty():
		return
	
	# Aggiorna le posizioni iniziali dei pedoni applicando la rotazione
	for pedestrian in pedestrian_controller.pedestrians:
		if original_pedestrian_positions.has(pedestrian):
			var original_pos = original_pedestrian_positions[pedestrian]
			var rotated_pos = rotate_position_around_origin(original_pos, current_rotation)
			pedestrian_controller.initial_pos[pedestrian] = rotated_pos
	
	# Aggiorna la posizione della random area se presente
	if pedestrian_controller.random_area != null:
		var rotated_area_pos = rotate_position_around_origin(original_random_area_position, current_rotation)
		pedestrian_controller.random_area.global_position = rotated_area_pos

# Utility per ruotare una posizione attorno all'origine (0,0)
func rotate_position_around_origin(position: Vector3, degrees: float) -> Vector3:
	var radians = deg_to_rad(degrees)
	var cos_rot = cos(radians)
	var sin_rot = sin(radians)
	
	# Applica la matrice di rotazione 2D (solo X e Z, Y rimane invariato)
	var new_x = position.x * cos_rot - position.z * sin_rot
	var new_z = position.x * sin_rot + position.z * cos_rot
	
	return Vector3(new_x, position.y, new_z)

# Metodo chiamato alla fine dell'episodio per randomizzare di nuovo
func get_end_episode():
	set_random()

# Metodo per ottenere la rotazione corrente
func get_current_rotation() -> float:
	return current_rotation

# Metodo per resetare la rotazione a 0°
func reset_rotation():
	if level_node == null:
		return
	
	level_node.rotation_degrees = Vector3.ZERO
	current_rotation = 0.0
	
	# Ripristina anche le posizioni originali dei pedoni
	if pedestrian_controller != null:
		for pedestrian in pedestrian_controller.pedestrians:
			if original_pedestrian_positions.has(pedestrian):
				pedestrian_controller.initial_pos[pedestrian] = original_pedestrian_positions[pedestrian]
		
		if pedestrian_controller.random_area != null:
			pedestrian_controller.random_area.global_position = original_random_area_position
