extends Area3D

signal custom_body_entered(area: Area3D, body: Node3D)

@export_category("Target Requirements")
@export var required_objectives: Array[int] = []  # IDs degli obiettivi richiesti
@export var check_objectives: bool = true  # Se false, ignora il controllo obiettivi

@export_category("Target Orientation")
@export var forward_direction: Vector3 = Vector3(0, 0, 1)  # Direzione "fronte" del target (locale)

func _ready():
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

# NUOVO: Determina se la normale del raycast corrisponde al fronte o retro
func get_side_from_normal(collision_normal: Vector3) -> String:
	# Ottieni la direzione forward del target in coordinate globali
	# transform.basis trasforma il vettore locale in globale considerando la rotazione
	var target_forward_global = transform.basis * forward_direction.normalized()
	
	# La normale del raycast punta VERSO l'origine del raggio (il pedone)
	# Per capire se il pedone guarda il fronte, invertiamo la normale
	var ray_direction = -collision_normal.normalized()
	
	# Calcola il dot product
	var dot = ray_direction.dot(target_forward_global)
	
	# dot > 0.5 = il raggio colpisce il fronte del target
	# dot < -0.5 = il raggio colpisce il retro del target
	# altrimenti = lato
	
	if dot > 0.5:
		return "front"
	elif dot < -0.5:
		return "back"
	else:
		return "side"

# NUOVO: Versione booleana semplice per controlli veloci
func is_looking_at_front(collision_normal: Vector3) -> bool:
	var target_forward_global = transform.basis * forward_direction.normalized()
	var ray_direction = -collision_normal.normalized()
	return ray_direction.dot(target_forward_global) > 0.5


