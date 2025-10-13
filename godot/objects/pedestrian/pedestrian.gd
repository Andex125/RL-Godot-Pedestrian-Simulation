extends CharacterBody3D
class_name Pedestrian


var level_manager: LevelManager = null
# ===== VARIABILI DI VELOCITÀ =====
## Velocità minima del pedone
var speed_min: float = Constants.MIN_SPEED
## Velocità massima del pedone (calcolata dinamicamente)
var speed_max: float

# ===== RIFERIMENTI AI NODI FIGLI =====
@onready var raycast_sensor = $RayCastSensor3D          # Sensore per rilevare ostacoli e target
@onready var ai_controller_3d = $AIController3D         # Controller AI per il machine learning
@onready var animation_tree = $AnimationTree            # Albero delle animazioni
@onready var pedestrian_controller = $".."              # Controller principale dei pedoni

# Archi proxemici per visualizzare le zone di comfort del pedone
@onready var proxemic_arc_small = $ProxemicArcSmall     # Zona personale (più vicina)
@onready var proxemic_arc_medium = $ProxemicArcMedium   # Zona sociale (media)
@onready var proxemic_arc_large = $ProxemicArcLarge     # Zona pubblica (più lontana)

# ===== VARIABILI DI STATO =====
var can_move: bool = true                    # Determina se il pedone può muoversi
var final_target_reached: bool = false       # Flag per indicare se ha raggiunto il target finale
var target_reached: bool = false             # Flag per target intermedi raggiunti
var disable: bool = false                    # Flag per disabilitare completamente il pedone
var finished: bool = false                   # Flag per indicare se ha completato l'episodio

# ===== VARIABILI DI MOVIMENTO =====
var rotation_sens: int = Constants.ROTATION_SENS  # Sensibilità di rotazione
var speed: float                                   # Velocità corrente

# ===== VARIABILI PER TRACKING TARGET INTERMEDI =====
var reached_targets := []                    # Array dei target intermedi già raggiunti
var last_target_reached: Area3D = null       # Ultimo target raggiunto

# ===== VARIABILI PER TRACKING OBIETTIVI =====
var reached_objectives := []                 # Array degli obiettivi raccolti
var collected_objective_ids: Array[int] = [] # IDs degli obiettivi raccolti
var objectives_collected: int = 0
var level_objectives_count: int = 0

func get_debug_info() -> Dictionary:
	var info = {}

	# --- Informazioni sul Level Manager ---
	if level_manager:
		info["level_manager_id"] = level_manager.get_instance_id()
		info["level_manager_name"] = level_manager.name
		
		# --- Informazioni sul livello corrente ---
		if level_manager.current_level:
			var current_level = level_manager.current_level
			info["level_id"] = current_level.get_instance_id()
			info["level_name"] = current_level.name
		else:
			info["level_id"] = "N/A"
			info["level_name"] = "N/A"
	else:
		info["level_manager_id"] = "N/A"
		info["level_manager_name"] = "N/A"
		info["level_id"] = "N/A"
		info["level_name"] = "N/A"
	
	# --- Informazioni sul pedone ---
	info["pedestrian_id"] = get_instance_id()
	info["pedestrian_name"] = name

	return info


# NUOVO: Recupera quale lato del target stava vedendo il pedone
func get_last_viewed_side(target: Area3D) -> String:
	if has_meta("viewed_target_sides"):
		var viewed_sides = get_meta("viewed_target_sides")
		if viewed_sides.has(target):
			return viewed_sides[target]
	return "unknown"

# NUOVO: Pulisce i metadata dei lati visti
func clear_viewed_sides():
	if has_meta("viewed_target_sides"):
		var viewed_sides = get_meta("viewed_target_sides")
		viewed_sides.clear()

	
## Inizializzazione del pedone quando entra nella scena
func _ready():
	# Imposta la velocità iniziale alla velocità minima
	speed = speed_min
	
	# Inizializza il controller AI passando il riferimento a questo pedone
	ai_controller_3d.init(self)
	
	# Aggiunge il pedone al gruppo per facilitare la gestione
	add_to_group(Constants.PEDESTRIAN_GROUP)
	
	# Nasconde gli archi proxemici se la visualizzazione è disabilitata
	if not Constants.SHOW_RAYS:
		proxemic_arc_small.hide()
		proxemic_arc_medium.hide()
		proxemic_arc_large.hide()

## Resetta lo stato del pedone per un nuovo episodio
func reset():
	# Ripristina posizione e rotazione iniziali
	rotation = pedestrian_controller.get_spawn_rotation(self)
	global_position = pedestrian_controller.get_spawn_position(self)
	velocity = Vector3.ZERO
	
	# Ricalcola la velocità massima
	set_speed_max()
	
	# Resetta tutte le variabili di stato
	finished = false
	target_reached = false
	final_target_reached = false
	reached_targets = []
	
	reached_objectives.clear()
	collected_objective_ids.clear()
	objectives_collected = 0
	
	# NUOVO: Pulisce i metadata dei lati visti
	clear_viewed_sides()     
	
## Imposta la velocità massima usando una distribuzione gaussiana
func set_speed_max():
	if can_move:
		# Genera un numero casuale con distribuzione normale
		var random = RandomNumberGenerator.new()
		random.randomize()
		# Velocità massima basata su media e deviazione standard
		speed_max = random.randfn(Constants.MAX_SPEED_MEAN, Constants.MAX_SPEED_DEVIATION)
	else:
		# Se non può muoversi, velocità massima è 0
		speed_max = 0.0
	
## Processo fisico chiamato ogni frame
func _physics_process(_delta):
	# Gestisce le animazioni basate sulla velocità
	# Animazione idle quando il pedone è fermo
	animation_tree.set("parameters/conditions/idle", velocity == Vector3.ZERO)
	# Animazione di camminata quando il pedone si muove
	animation_tree.set("parameters/conditions/walk", velocity != Vector3.ZERO)
	
	# Applica il movimento fisico
	move_and_slide()


## Imposta la velocità corrente del pedone basata sull'azione dell'AI
func set_speed(action_0) -> void:
	# Modifica la velocità in base all'azione, mantenendola nei limiti
	speed = clampf(speed + action_0 * speed_max / 2, speed_min, speed_max)
	
	# Calcola il vettore di movimento in direzione forward (z positivo)
	var move_vec = Vector3(0, 0, 1)
	# Ruota il vettore secondo la rotazione corrente del pedone
	move_vec = move_vec.rotated(Vector3(0, 1, 0), rotation.y)
	# Applica la velocità al vettore
	move_vec *= speed
	# Imposta la velocità del CharacterBody3D
	set_velocity(move_vec)

## Imposta la direzione del pedone basata sull'azione dell'AI
func set_direction(action_1) -> void:
	# Modifica la rotazione Y (yaw) in base all'azione e alla sensibilità
	rotation.y += deg_to_rad(action_1 * rotation_sens)

## Calcola i reward per l'AI basati sulle azioni e stato corrente
func compute_rewards() -> void:
	var tot_reward: float = 0
	
	# Penalty per ogni timestep (incoraggia a completare velocemente)
	tot_reward += Constants.TIMESTEP_REW
	
	
	# Calcola reward solo se l'episodio non è finito
	if not finished:
		# ===== REWARD PER TARGET RAGGIUNTI =====
		# ===== REWARD PER TARGET RAGGIUNTI =====
		if target_reached:
			# Controlla se il target ha requisiti di obiettivi
			var has_objective_requirements = (
				last_target_reached.has_method("check_required_objectives") 
				and last_target_reached.has_method("get_reward_for_objectives")
			)
			
			# Verifica se ha raccolto tutti gli obiettivi richiesti
			var all_objectives_collected = false
			if has_objective_requirements:
				all_objectives_collected = last_target_reached.check_required_objectives(collected_objective_ids)
			
			# Recupera il lato che stava vedendo prima di attraversarlo
			var viewed_side = get_last_viewed_side(last_target_reached)
			
			# Reward base per aver raggiunto un target (prima volta o già visitato)
			if last_target_reached in reached_targets:
				tot_reward += Constants.INTERMEDIATE_TARGET_ALREADY_REACHED_REW
			else:
				reached_targets.append(last_target_reached)
				tot_reward += Constants.INTERMEDIATE_TARGET_FIRST_TIME_REW
			
			# NUOVA LOGICA: Reward in base a obiettivi + lato
			if has_objective_requirements:
				var objective_reward = 0.0
				
				if viewed_side == "front":
					# FRONTE
					if all_objectives_collected:
						# Completati + front = +1
						objective_reward = Constants.INTERMEDIATE_TARGET_BONUS_REW
						
					else:
						# Mancanti + front = -1
						objective_reward = Constants.INTERMEDIATE_TARGET_MALUS_REW
				
				elif viewed_side == "back":
					# RETRO
					if all_objectives_collected:
						# Completati + back = -1
						objective_reward = Constants.INTERMEDIATE_TARGET_MALUS_REW
					else:
						# Mancanti + back = +1
						objective_reward = Constants.INTERMEDIATE_TARGET_BONUS_REW
				
				else:
					# LATO o SCONOSCIUTO = neutro (nessun reward)
					objective_reward = 0.0
				
				tot_reward += objective_reward
			
			# Resetta i flag
			target_reached = false
			last_target_reached = null
		# Ottiene le osservazioni dai sensori
		var obs = raycast_sensor.get_observation()
		var walls_and_targets = obs[0]    # Dati su muri e target
		var agents_and_walls = obs[1]     # Dati su altri agenti e muri
		var walls_and_objectives = obs[2] # Dati su muri e obiettivi
		
		# ===== REWARD PER OBIETTIVI =====
		# Conta quanti obiettivi sono visibili
		var objectives_in_sight: int = 0
		for i in range(0, walls_and_objectives.size(), 4):
			if walls_and_objectives[i+1] == 1:  # Nuovo obiettivo visibile
				objectives_in_sight += 1

		# Penalty se non ha raccolti tutti gli obbiettivi
		if objectives_collected < level_objectives_count:
			var remaining_ratio = float(level_objectives_count - objectives_collected) / float(level_objectives_count)
			tot_reward += Constants.NO_ALL_OBJECTIVES_REW * remaining_ratio
		
		# ===== PENALTY PER VICINANZA AI MURI =====
		var wall_near = false
		# Controlla tutti i raggi per rilevamento muri
		for i in range(0, Constants.WALL_COLLISION_RAYS * 4, 4):
			# Se un muro è rilevato e troppo vicino
			if walls_and_targets[i+1] == 1 and walls_and_targets[i] < Constants.WALL_COLLISION_DISTANCE / Constants.RAY_LENGTH_OBS:
				wall_near = true
				break
		
		if wall_near:
			tot_reward += Constants.WALL_COLLISION_REW  # Penalty negativo
			
		# ===== PENALTY PER VICINANZA AD ALTRI AGENTI (PROXEMICA) =====
		var agent_near = false
		
		# Controlla zona personale (più vicina) - penalty maggiore
		for i in range(0, Constants.AGENT_COLLISION_SMALL_RAYS * 4, 4):
			if agents_and_walls[i+1] == 1 and agents_and_walls[i] < Constants.AGENT_COLLISION_SMALL_DISTANCE / Constants.RAY_LENGTH_OBS:
				agent_near = true
				break
		
		if agent_near:
			tot_reward += Constants.AGENT_COLLISION_SMALL_REW  # Penalty alta
			
		# Se non è nella zona personale, controlla zona sociale (media)
		if not agent_near:
			for i in range(0, Constants.AGENT_COLLISION_MEDIUM_RAYS * 4, 4):
				if agents_and_walls[i+1] == 1 and agents_and_walls[i] < Constants.AGENT_COLLISION_MEDIUM_DISTANCE / Constants.RAY_LENGTH_OBS:
					agent_near = true
					break
			if agent_near:
				tot_reward += Constants.AGENT_COLLISION_MEDIUM_REW  # Penalty media
				
		# Se non è nella zona sociale, controlla zona pubblica (lontana)
		if not agent_near:
			for i in range(0, Constants.AGENT_COLLISION_LARGE_RAYS * 4, 4):
				if agents_and_walls[i+1] == 1 and agents_and_walls[i] < Constants.AGENT_COLLISION_LARGE_DISTANCE / Constants.RAY_LENGTH_OBS:
					agent_near = true
					break
			if agent_near:
				tot_reward += Constants.AGENT_COLLISION_LARGE_REW  # Penalty bassa
			
	# Aggiorna il reward cumulativo e invia all'AI
	ai_controller_3d.reward += tot_reward
	# Aggiorna l'interfaccia utente con il reward corrente
	pedestrian_controller.set_reward_label_text(tot_reward)

## Callback quando il pedone entra nel target finale
func _on_final_target_entered(body):
	# Verifica che sia proprio questo pedone
	if body == self:
		# ====== DEBUG: STAMPA CONTROLLO FINALE ======
		#var debug_info = get_debug_info()
		#print("\n🏁 === TARGET FINALE RAGGIUNTO ===")
		#print("📍 Level Manager: %s (ID: %s)" % [debug_info.get("level_manager_name", "N/A"), debug_info.get("level_manager_id", "N/A")])
		#print("📍 Livello: %s (ID: %s)" % [debug_info.get("level_name", "N/A"), debug_info.get("level_id", "N/A")])
		#print("📍 Pedone: %s (ID: %s)" % [debug_info.get("pedestrian_name", "N/A"), debug_info.get("pedestrian_id", "N/A")])
		#print("📍 Obiettivi raccolti: %d/%d" % [objectives_collected, level_objectives_count])
		
		# ===== CONTROLLO OBIETTIVI RACCOLTI =====
		if objectives_collected >= level_objectives_count:
			finished = true
			final_target_reached = true
			ai_controller_3d.reward += Constants.FINAL_TARGET_REW
			pedestrian_controller.set_reward_label_text(Constants.FINAL_TARGET_REW)
		else:
			ai_controller_3d.reward += Constants.FINAL_TARGET_WITHOUT_OBJECTIVES_REW
			pedestrian_controller.set_reward_label_text(Constants.FINAL_TARGET_WITHOUT_OBJECTIVES_REW)

		
func _on_target_entered(area, body):
	# Verifica che sia proprio questo pedone
	if body == self:
		target_reached = true
		last_target_reached = area
		
func _on_objective_entered(area, body):
	# CONTROLLI BASE
	if body != self or not area.active or area in reached_objectives:
		return
		
	if area.has_meta("processing_" + str(get_instance_id())):
		return 
	
	area.set_meta("processing_" + str(get_instance_id()), true)
	
	# Ottieni l'ID dell'obiettivo se disponibile
	var objective_id: int = -1  # NUOVO: variabile locale
	if area.has_method("get_objective_id"):
		objective_id = area.get_objective_id()
	
	# Disabilita l'obiettivo
	area.set_deferred("active", false) 
	area.set_deferred("monitoring", false) 
	area.set_deferred("monitorable", false) 
	area.set_deferred("visible", false)
	
	var collision = area.find_child("CollisionShape3D")
	if collision:
		collision.set_deferred("disabled", true)
	
	# Aggiorna contatori e array
	objectives_collected += 1
	reached_objectives.append(area)
	
	# Aggiungi l'ID alla lista se valido
	if objective_id >= 0:
		collected_objective_ids.append(objective_id)  # NUOVO
	
	ai_controller_3d.reward += Constants.OBJECTIVE_COLLECTED_REW
	pedestrian_controller.set_reward_label_text(Constants.OBJECTIVE_COLLECTED_REW)
		
## Restituisce la velocità normalizzata tra 0 e 1
func get_speed_norm() -> float:
	# Evita divisione per zero
	if speed_max == 0.0:
		return 0.0
	
	# Normalizza la velocità corrente rispetto ai limiti
	return (speed - speed_min) / (speed_max - speed_min)

func get_objectives_direction_vector() -> Array:
	var checklist = []
	
	for i in range(Constants.MAX_OBJECTIVES_IN_CURRICULUM):
		if i < level_objectives_count:
			# Obiettivo ESISTE
			if i in collected_objective_ids:
				checklist.append(1)  # ✅ RACCOLTO
			else:
				checklist.append(0)  # ⬜ DA RACCOGLIERE
		else:
			# Obiettivo NON ESISTE
			checklist.append(-1)  # ❌ PADDING
	
	# Target finale
	if final_target_reached:
		checklist.append(1)
	else:
		checklist.append(0)
	
	return checklist

## Disabilita il pedone quando raggiunge il target finale
func disable_pedestrian():
	disable = true
	speed_max = 0.0              # Ferma il movimento
	rotation_sens = 0            # Ferma la rotazione
	global_position.y = 1000     # Sposta fuori dalla scena

## Riabilita il pedone alla fine dell'episodio
func enable_pedestrian():
	disable = false
	rotation_sens = Constants.ROTATION_SENS  # Ripristina la sensibilità di rotazione
	
func set_objectives_count(count: int):
	level_objectives_count = count
