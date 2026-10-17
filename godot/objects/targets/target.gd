extends Area3D

signal custom_body_entered(area: Area3D, body: Node3D)

@export_category("Target Requirements")
@export var required_objectives: Array[int] = []  # IDs degli obiettivi richiesti
@export var check_objectives: bool = true  # Se false, ignora il controllo obiettivi

@export_category("Target Orientation")
## ON: rileva fronte/retro per la reward. OFF: rotazione indifferente (qualsiasi direzione di attraversamento è valida).
@export var check_orientation: bool = true
@export var forward_direction: Vector3 = Vector3(0, 0, 1)  # Direzione "fronte" del target (locale)

func _ready():
	if not is_in_group(Constants.TARGETS_GROUP):
		add_to_group(Constants.TARGETS_GROUP)
	self.body_entered.connect(_custom_body_entered)
	_remove_duplicates()
	
	if check_objectives and not required_objectives.is_empty():
		print("Target '%s' requires objectives: %s" % [name, str(required_objectives)])

func _custom_body_entered(body: Node3D):
	custom_body_entered.emit(self, body)

# Rimuove eventuali duplicati dall'array required_objectives
func _remove_duplicates():
	if required_objectives.is_empty():
		return
	
	var original_size = required_objectives.size()
	var unique_objectives: Array[int] = []
	
	for obj_id in required_objectives:
		if obj_id not in unique_objectives:
			unique_objectives.append(obj_id)
	
	if unique_objectives.size() < original_size:
		var duplicates_count = original_size - unique_objectives.size()
		push_warning("Target '%s': Rimossi %d duplicati dall'array required_objectives. Obiettivi unici: %s" 
			% [name, duplicates_count, str(unique_objectives)])
		required_objectives = unique_objectives

# Metodo per verificare se tutti gli obiettivi richiesti sono stati raccolti
func check_required_objectives(collected_objective_ids: Array[int]) -> bool:
	if not check_objectives or required_objectives.is_empty():
		return true
	
	for required_id in required_objectives:
		if required_id not in collected_objective_ids:
			return false
	
	return true

# Metodo per ottenere il reward appropriato
func get_reward_for_objectives(collected_objective_ids: Array[int]) -> float:
	if not check_objectives or required_objectives.is_empty():
		return 0.0
	
	if check_required_objectives(collected_objective_ids):
		return Constants.INTERMEDIATE_TARGET_BONUS_REW
	else:
		return Constants.INTERMEDIATE_TARGET_MALUS_REW

# Restituisce la normale forward del target in coordinate globali
func get_target_forward_global() -> Vector3:
	return (global_transform.basis * forward_direction).normalized()

# Determina il lato in base al vettore movimento (velocità) del pedone
func get_side_from_vector(dir: Vector3) -> String:
	if not check_orientation:
		return "indifferent"
	if dir.length_squared() < 0.0001:
		return "side"
	var forward_global = get_target_forward_global()
	var dot = dir.normalized().dot(forward_global)
	if dot > 0.2:
		return "front"
	elif dot < -0.2:
		return "back"
	return "side"

# Determina il lato in base alla direzione del raggio
func get_side_from_ray(ray_global_dir: Vector3) -> String:
	return get_side_from_vector(ray_global_dir)

# Metodo di compatibilità: determina lato da normale di collisione
func get_side_from_normal(collision_normal: Vector3) -> String:
	if not check_orientation:
		return "indifferent"
	if collision_normal.length_squared() < 0.0001:
		return "side"
	var forward_global = get_target_forward_global()
	var dot = collision_normal.normalized().dot(forward_global)
	if dot > 0.2:
		return "front"
	elif dot < -0.2:
		return "back"
	return "side"

# Controllo booleano rapido
func is_looking_at_front(dir: Vector3) -> bool:
	if not check_orientation:
		return true
	return get_side_from_vector(dir) == "front"


