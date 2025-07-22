extends ISensor3D

## Max distance at which a raycast can hit
var ray_length := Constants.RAY_LENGTH:
	get:
		return ray_length
	set(value):
		ray_length = value
		_update()

## Max angle of vision (in deg)
var max_vision_degrees := Constants.MAX_VISION_DEGREES:
	get:
		return max_vision_degrees
	set(value):
		max_vision_degrees = value
		_update()

## Interval between rays	
var rays_angle_delta := Constants.RAYS_ANGLE_DELTA:
	get:
		return rays_angle_delta
	set(value):
		rays_angle_delta = value
		_update()

## Position of initial ray
var initial_ray_pos := Constants.INITIAL_RAY_POS:
	get:
		return initial_ray_pos
	set(value):
		initial_ray_pos = value
		_update()

## If true rays will collide with Area3D, if false it wont
var collide_with_areas := true:
	get:
		return collide_with_areas
	set(value):
		collide_with_areas = value
		_update()

## If true rays will collide with bodies, if false it wont
var collide_with_bodies := true:
	get:
		return collide_with_bodies
	set(value):
		collide_with_bodies = value
		_update()

## VARIABILI DI STATO

@onready var pedestrian = $".."  # Riferimento al nodo padre (il pedone)
var lines_walls_targets: Array[MeshInstance3D] = []  # Linee di debug per raggi muri/obiettivi
var lines_agents_walls: Array[MeshInstance3D] = []   # Linee di debug per raggi agenti/muri
var lines_walls_objectives: Array[MeshInstance3D] = []   # Linee di debug per raggi muri/obiettivi

var rays_walls_targets := []  # Array di RayCast3D per rilevare muri e target
var rays_agents_walls := []   # Array di RayCast3D per rilevare agenti e muri
var rays_walls_objectives := []  # Array di RayCast3D per rilevare muri e obiettivi

var mode_rays = {
	1: "walls_targets",
	2: "agents_walls",
	3: "walls_objectives"
}

## FUNZIONI DI AGGIORNAMENTO

func _update() -> void:
	# Funzione chiamata ogni volta che una proprietà cambia
	# Scopo: ricreare tutti i nodi raycast con le nuove impostazioni
	_spawn_nodes()

func _ready() -> void:
	# Funzione chiamata quando il nodo entra nella scena
	# Scopo: inizializzazione iniziale di tutti i raggi
	_spawn_nodes()

func _process(_delta):
	# Funzione chiamata ogni frame
	# Scopo: aggiornare le linee di debug se necessario
	
	# Controlla due condizioni:
	# 1. Il pedone non deve essere disabilitato
	# 2. La costante SHOW_RAYS deve essere true (per il debug)
	if not pedestrian.disable and Constants.SHOW_RAYS:
		_create_debug_lines()

## FUNZIONI DI DEBUG VISIVO

func _create_debug_lines(): 
	# Funzione che crea linee colorate per visualizzare i raggi
	# Scopo: debug visivo per vedere cosa rilevano i raggi
	
	# PARTE 1: Gestione raggi per muri e target
	for i in range(rays_walls_targets.size()):
		if rays_walls_targets[i].is_colliding():
			var point = rays_walls_targets[i].get_collision_point() - global_position
			
			var material = ORMMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			
			# CONTROLLA SOLO TARGET - IGNORA MURI
			if rays_walls_targets[i].get_collider().is_in_group(Constants.TARGETS_GROUP):
				if rays_walls_targets[i].get_collider().name.begins_with("FinalTarget"):
					material.albedo_color = "#43A047"  # Verde per target finali
				else:
					material.albedo_color = "#26C6DA"  # Ciano per target normali
					
				# Crea la mesh SOLO per target (non per muri)
				var immediate_mesh = ImmediateMesh.new()
				immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
				immediate_mesh.surface_add_vertex(position)
				immediate_mesh.surface_add_vertex(point)
				immediate_mesh.surface_end()
					
				lines_walls_targets[i].mesh = immediate_mesh
				lines_walls_targets[i].global_rotation = Vector3.ZERO
			else:
				# Se è un muro, NON disegnare la linea
				lines_walls_targets[i].mesh = null
	
	# PARTE 2: Gestione raggi per agenti e muri
	for i in range(rays_agents_walls.size()):
		if rays_agents_walls[i].is_colliding():
			# Controlla se ha colpito specificatamente un pedone
			if rays_agents_walls[i].get_collider().is_in_group(Constants.PEDESTRIAN_GROUP):
				# Calcola il punto di collisione
				var point = rays_agents_walls[i].get_collision_point() - global_position
				
				# Crea materiale giallo per i pedoni
				var material = ORMMaterial3D.new()
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				material.albedo_color = "#FDD835"  # Giallo
				
				# Crea la mesh della linea (alzata di 1 unità per visibilità)
				var immediate_mesh = ImmediateMesh.new()
				immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
				immediate_mesh.surface_add_vertex(position + Vector3(0, 1, 0))  # Alzata
				immediate_mesh.surface_add_vertex(point + Vector3(0, 1, 0))     # Alzata
				immediate_mesh.surface_end()
				
				# Applica la mesh
				lines_agents_walls[i].mesh = immediate_mesh
				lines_agents_walls[i].global_rotation = Vector3.ZERO
			else:
				# Se non ha colpito un pedone, nasconde la linea
				lines_agents_walls[i].mesh = null
				
	# PARTE 3: Gestione raggi per muri e obiettivi
	for i in range(rays_walls_objectives.size()):
		if rays_walls_objectives[i].is_colliding():
			var point = rays_walls_objectives[i].get_collision_point() - global_position
			
			var material = ORMMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			
			# CONTROLLA SOLO OBJECTIVES - IGNORA MURI
			if rays_walls_objectives[i].get_collider().is_in_group(Constants.OBJECTIVES_GROUP):
				if rays_walls_objectives[i].get_collider() in pedestrian.reached_objectives:
					material.albedo_color = "#808080"  # Grigio per obiettivi raccolti
				else:
					material.albedo_color = "#FF5722"  # Arancione per obiettivi nuovi
					
				# Crea la mesh SOLO per objectives (non per muri)
				var immediate_mesh = ImmediateMesh.new()
				immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
				immediate_mesh.surface_add_vertex(position + Vector3(0, 2, 0))
				immediate_mesh.surface_add_vertex(point + Vector3(0, 2, 0))
				immediate_mesh.surface_end()
					
				lines_walls_objectives[i].mesh = immediate_mesh
				lines_walls_objectives[i].global_rotation = Vector3.ZERO
			else:
				# Se è un muro, NON disegnare la linea
				lines_walls_objectives[i].mesh = null

## FUNZIONI DI CREAZIONE RAGGI

func _spawn_nodes():
	# Funzione principale per creare tutti i nodi raycast
	# Scopo: inizializzare o ricreare completamente il sistema di raggi
	
	# FASE 1: Pulizia
	# Rimuove tutti i raggi esistenti dalla scena
	for ray in get_children():
		ray.queue_free()  # Distrugge il nodo nel prossimo frame
	
	# Resetta gli array
	rays_walls_targets = []
	rays_agents_walls = []
	rays_walls_objectives = []

	# FASE 2: Creazione raggi
	# Crea raggi in pattern semicircolare partendo da initial_ray_pos
	var angle = initial_ray_pos  # Angolo corrente (es. 0°)
	var i = 0  # Indice del raggio
	
	while angle < max_vision_degrees:
		# Crea tre raggi per ogni angolo (tranne per 0°):
		_create_ray(angle, i, mode_rays[1])  # Raggio positivo per muri/target
		_create_ray(angle, i, mode_rays[2])  # Raggio positivo per agenti/muri
		_create_ray(angle, i, mode_rays[3])  # Raggio positivo per muri/obiettivi
		
		if angle != 0:
			# Se non siamo al centro, crea anche i raggi simmetrici
			_create_ray(-angle, -i, mode_rays[1])   # Raggio negativo per muri/target
			_create_ray(-angle, -i, mode_rays[2])  # Raggio negativo per agenti/muri
			_create_ray(-angle, -i, mode_rays[3])  # Raggio negativo per muri/obiettivi
		
		i += 1
		# Aumenta l'angolo con incremento crescente (più denso al centro)
		angle = angle + rays_angle_delta * i
		
	# FASE 3: Raggi agli angoli estremi
	# Crea raggi esattamente agli angoli massimi di visione
	_create_ray(max_vision_degrees, i, mode_rays[1])
	_create_ray(-max_vision_degrees, -i, mode_rays[1])
	_create_ray(max_vision_degrees, i, mode_rays[2])
	_create_ray(-max_vision_degrees, -i, mode_rays[2])
	_create_ray(max_vision_degrees, i, mode_rays[3])
	_create_ray(-max_vision_degrees, -i, mode_rays[3])
	
	# FASE 4: Creazione linee di debug
	# Crea una linea di debug per ogni raggio muri/target
	for r in rays_walls_targets:	
		var line = MeshInstance3D.new()
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # Niente ombre
		lines_walls_targets.append(line)
		add_child(line)
		
	# Crea una linea di debug per ogni raggio agenti/muri
	for r in rays_agents_walls:	
		var line = MeshInstance3D.new()
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lines_agents_walls.append(line)
		add_child(line)
		
	# Crea una linea di debug per ogni raggio muri/obiettivi - CORRETTO
	for r in rays_walls_objectives:	
		var line = MeshInstance3D.new()
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lines_walls_objectives.append(line)  # CORRETTO: era lines_agents_walls
		add_child(line)

func _create_ray(angle: float, idx: int, mode: String):
	# Funzione per creare un singolo raggio
	# Parametri:
	# - angle: angolo in gradi (-45° a +45° tipicamente)
	# - idx: indice del raggio (per naming)
	# - mode: "walls_targets", "agents_walls", "walls_objectives"
	
	# FASE 1: Creazione nodo RayCast3D
	var ray = RayCast3D.new()
	
	# Converte l'angolo in coordinate 3D
	var cast_to = to_spherical_coords(ray_length, angle, 0)
	ray.set_target_position(cast_to)
	
	# FASE 2: Configurazione basata sul modo
	if mode == "walls_targets":
		# Modalità muri/target
		ray.set_name("wall_target_ray_" + str(idx))
		ray.show()  # Visibile nel debug di Godot
		ray.collision_mask = 1585
		
	elif mode == "agents_walls":
		# Modalità agenti/muri
		ray.set_name("agent_wall_ray_" + str(idx))
		ray.hide()  # Nascosto nel debug di Godot
		ray.collision_mask = 399
		
	elif mode == "walls_objectives":
		# Modalità muri/obiettivi
		ray.set_name("wall_objective_ray_" + str(idx))
		ray.show()  # Visibile nel debug di Godot
		ray.collision_mask = 65
			
	# FASE 3: Configurazione comune
	ray.enabled = true
	ray.collide_with_bodies = collide_with_bodies
	ray.collide_with_areas = collide_with_areas
	ray.debug_shape_custom_color = Constants.RAYS_GRAY_COLOR
	ray.exclude_parent = true  # Non colpisce il pedone stesso
	ray.hit_from_inside = false  # Non rileva dall'interno degli oggetti
	
	# FASE 4: Aggiunta alla scena e agli array - CORRETTO
	add_child(ray)
	if mode == "walls_targets":
		rays_walls_targets.append(ray)
	elif mode == "agents_walls":
		rays_agents_walls.append(ray)
	elif mode == "walls_objectives":
		rays_walls_objectives.append(ray)

## FUNZIONI MATEMATICHE

func to_spherical_coords(r, inc, azimuth) -> Vector3:
	# Converte coordinate sferiche in coordinate cartesiane
	# Parametri:
	# - r: raggio (distanza)
	# - inc: inclinazione (angolo verticale)
	# - azimuth: azimut (angolo orizzontale)
	
	# Formula matematica per la conversione:
	# x = r * sin(inclinazione) * cos(azimut)
	# y = r * sin(azimut) 
	# z = r * cos(inclinazione) * cos(azimut)
	
	return Vector3(
		r * sin(deg_to_rad(inc)) * cos(deg_to_rad(azimuth)),
		r * sin(deg_to_rad(azimuth)),
		r * cos(deg_to_rad(inc)) * cos(deg_to_rad(azimuth))
	)

func clamp0360(eulerAngles: int) -> float:
	# Normalizza un angolo nel range 0-360 gradi
	# Esempi:
	# - 450° diventa 90°
	# - -90° diventa 270°
	
	var result = eulerAngles % 360  # Modulo per portare in range
	if result < 0: 
		result += 360  # Se negativo, aggiungi 360
	return result

## FUNZIONI DI OSSERVAZIONE (PER AI/ML)

func get_observation() -> Array:
	# Funzione pubblica per ottenere le osservazioni del sensore
	# Scopo: interfaccia per sistemi di intelligenza artificiale
	return self.calculate_raycasts()

func calculate_raycasts() -> Array:
	# Calcola tutte le osservazioni dei raggi
	# Ritorna un array con tre elementi:
	# [0] = osservazioni muri/target
	# [1] = osservazioni agenti/muri
	# [2] = osservazioni muri/obiettivi
	return [calculate_walls_targets(), calculate_agents_walls(), calculate_walls_objectives()]

func calculate_walls_objectives() -> Array:
	# Calcola osservazioni per raggi muri/obiettivi
	# Per ogni raggio ritorna: [distanza, muro, obiettivo_nuovo, obiettivo_raccolto]
	
	var hit_objects := []
	
	# Walls and objectives observations
	for ray in rays_walls_objectives:
		var norm_distance = _get_raycast_distance(ray)
		hit_objects.append(norm_distance)
		
		# hit object type is a one hot encoding
		# 1,0,0: wall; 0,1,0: new objective; 0,0,1: already collected objective
		var hit_object_type := [0, 0, 0]
		if ray.get_collider():
			if ray.get_collider().is_in_group(Constants.OBJECTIVES_GROUP):
				# Controlla se l'obiettivo è già stato raccolto
				var objective_already_collected = false
				for collected_obj in pedestrian.reached_objectives:
					if collected_obj == ray.get_collider():
						objective_already_collected = true
						break
				
				if objective_already_collected:
					hit_object_type[2] = 1  # Obiettivo già raccolto
				else:
					hit_object_type[1] = 1  # Nuovo obiettivo
				
			elif ray.get_collider().is_in_group(Constants.WALLS_GROUP):
				hit_object_type[0] = 1  # Muro

		hit_objects.append_array(hit_object_type)
	return hit_objects
	
	
func calculate_walls_targets() -> Array:
	# Calcola osservazioni per raggi muri/target
	# Per ogni raggio ritorna: [distanza, muro, target_nuovo, target_visitato]
	
	var hit_objects := []
	
	# Walls and targets observations
	for ray in rays_walls_targets:
		var norm_distance = _get_raycast_distance(ray)
		hit_objects.append(norm_distance)
		
		# hit object type is a one hot encoding
		# 1,0,0: wall; 0,1,0: new target; 0,0,1: already visited target
		var hit_object_type := [0, 0, 0]
		if ray.get_collider():
			if ray.get_collider().is_in_group(Constants.TARGETS_GROUP):
				# Controlla se il target è già stato raggiunto
				var target_already_reached = false
				for reached_target in pedestrian.reached_targets:
					if reached_target == ray.get_collider():
						target_already_reached = true
						break
				
				if target_already_reached:
					hit_object_type[2] = 1  # Target già visitato
				else:
					hit_object_type[1] = 1  # Nuovo target
				
			elif ray.get_collider().is_in_group(Constants.WALLS_GROUP):
				hit_object_type[0] = 1  # Muro

		hit_objects.append_array(hit_object_type)
		
	return hit_objects

func calculate_agents_walls() -> Array:
	# Calcola osservazioni per raggi agenti/muri
	# Per ogni raggio ritorna: [distanza, tipo, direzione, velocità]
	
	var hit_objects := []
	
	for ray in rays_agents_walls:
		# PARTE 1: Distanza normalizzata
		var norm_distance = _get_raycast_distance(ray)
		
		# PARTE 2: Inizializza valori predefiniti
		var type: int = 0        # 0 = niente, 1 = pedone
		var direction: float = 0.0   # -1 a 1 (direzione relativa)
		var speed: float = 0.0       # 0 a 1 (velocità normalizzata)
		
		var collider = ray.get_collider()
		if collider:
			if collider.is_in_group(Constants.PEDESTRIAN_GROUP):
				type = 1  # È un pedone
				
				# Calcola direzione relativa
				var diffAng = clamp0360(
					clamp0360(rad_to_deg(collider.rotation.y)) - 
					clamp0360(rad_to_deg(rotation.y))
				)
				# Converte da 0-360° a -1 +1
				direction = clamp((diffAng / 180) - 1, -1, 1)
				
				# Ottiene velocità normalizzata
				speed = collider.get_speed_norm()
		
		# Aggiunge tutti i valori
		hit_objects.append(norm_distance)	
		hit_objects.append(type)
		hit_objects.append(direction)
		hit_objects.append(speed)
	
	return hit_objects

## FUNZIONI DI UTILITÀ

func _get_raycast_distance(ray: RayCast3D) -> float:
	# Calcola la distanza normalizzata (0-1) per un raggio
	# 0 = nessuna collisione o distanza massima
	# 1 = collisione molto vicina
	
	# Se il raggio non colpisce nulla
	if !ray.is_colliding():
		return 0.0

	# Calcola la distanza reale
	var origin = ray.global_transform.origin
	var collision_point = ray.get_collision_point()
	var distance = origin.distance_to(collision_point)
	
	# Se la distanza supera il limite osservabile
	if distance > Constants.RAY_LENGTH_OBS:
		return 1
	
	# Normalizza la distanza (0-1)
	return distance / Constants.RAY_LENGTH_OBS
