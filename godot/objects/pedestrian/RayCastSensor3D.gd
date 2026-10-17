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
	if DisplayServer.get_name() == "headless":
		return
	if is_instance_valid(pedestrian) and not pedestrian.disable and Constants.SHOW_RAYS:
		_create_debug_lines()

## FUNZIONI DI DEBUG VISIVO

func _create_debug_lines(): 
	if DisplayServer.get_name() == "headless" or not is_inside_tree() or not is_instance_valid(pedestrian):
		return
	# Funzione che crea linee colorate per visualizzare i raggi
	# Scopo: debug visivo per vedere cosa rilevano i raggi
	
	# PARTE 1: Gestione raggi per muri e target - CON COLORI REWARD
	for i in range(rays_walls_targets.size()):
		if rays_walls_targets[i].is_colliding():
			var point = rays_walls_targets[i].get_collision_point() - global_position
			var collider = rays_walls_targets[i].get_collider()
			
			var material = ORMMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			
			# CONTROLLA SOLO TARGET - IGNORA MURI
			if collider.is_in_group(Constants.TARGETS_GROUP):
				# Determina il colore in base al reward previsto
				var ray_color = _get_target_ray_color(collider, rays_walls_targets[i])
				material.albedo_color = ray_color
					
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
	
	# PARTE 2: Gestione raggi per agenti e muri (lascia come prima)
	for i in range(rays_agents_walls.size()):
		if rays_agents_walls[i].is_colliding():
			if rays_agents_walls[i].get_collider().is_in_group(Constants.PEDESTRIAN_GROUP):
				var point = rays_agents_walls[i].get_collision_point() - global_position
				
				var material = ORMMaterial3D.new()
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				material.albedo_color = "#FDD835"  # Giallo
				
				var immediate_mesh = ImmediateMesh.new()
				immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
				immediate_mesh.surface_add_vertex(position + Vector3(0, 1, 0))
				immediate_mesh.surface_add_vertex(point + Vector3(0, 1, 0))
				immediate_mesh.surface_end()
				
				lines_agents_walls[i].mesh = immediate_mesh
				lines_agents_walls[i].global_rotation = Vector3.ZERO
			else:
				lines_agents_walls[i].mesh = null
				
	# PARTE 3: Gestione raggi per muri e obiettivi (lascia come prima)
	for i in range(rays_walls_objectives.size()):
		if rays_walls_objectives[i].is_colliding():
			var point = rays_walls_objectives[i].get_collision_point() - global_position
			
			var material = ORMMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			
			if rays_walls_objectives[i].get_collider().is_in_group(Constants.OBJECTIVES_GROUP):
				if rays_walls_objectives[i].get_collider() in pedestrian.reached_objectives:
					material.albedo_color = "#808080"  # Grigio per obiettivi raccolti
				else:
					material.albedo_color = "#FF5722"  # Arancione per obiettivi nuovi
					
				var immediate_mesh = ImmediateMesh.new()
				immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
				immediate_mesh.surface_add_vertex(position + Vector3(0, 2, 0))
				immediate_mesh.surface_add_vertex(point + Vector3(0, 2, 0))
				immediate_mesh.surface_end()
					
				lines_walls_objectives[i].mesh = immediate_mesh
				lines_walls_objectives[i].global_rotation = Vector3.ZERO
			else:
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
	"""
	Calcola osservazioni per raggi muri/target.
	
	Per ogni raggio ritorna 8 valori:
	  [0]: distanza normalizzata [0,1] (1.0 = libero)
	  [1-5]: one-hot encoding tipo target
	  [6]: direction_alignment [-1,+1]
	  [7]: n_attr_norm [-1,+1] (Grassi Cap. 4: contatore attraversamenti varco normalizzato, -1 se muro/assente)
	  
	One-hot encoding:
	  [1,0,0,0,0]: muro
	  [0,1,0,0,0]: target intermedio valido
	  [0,0,1,0,0]: target intermedio non valido
	  [0,0,0,1,0]: target finale valido
	  [0,0,0,0,1]: target finale non valido
	"""
	var hit_objects := []
	
	# Itera su tutti i raggi walls_targets (23 raggi)
	for ray in rays_walls_targets:
		# 1. DISTANZA NORMALIZZATA (1.0 se non collide)
		var norm_distance = _get_raycast_distance(ray)
		hit_objects.append(norm_distance)
		
		# 2. ONE-HOT ENCODING (5 valori)
		var hit_object_type := [0.0, 0.0, 0.0, 0.0, 0.0]
		
		# 3. DIRECTION ALIGNMENT (1 valore in [-1, 1])
		var direction_alignment = 0.0
		
		# 4. N_ATTR_NORM (1 valore: contatore varchi Grassi Cap. 4, -1 se non target)
		var n_attr_norm = -1.0
		
		# 5. ANALISI COLLISIONE
		var collider = ray.get_collider()
		if collider:
			if collider.is_in_group(Constants.TARGETS_GROUP):
				var is_final_target = collider.name.begins_with("FinalTarget")
				
				# Calcola direzione raggio in coordinate globali
				var ray_global_dir = (ray.get_collision_point() - ray.global_transform.origin).normalized()
				if ray_global_dir.length_squared() < 0.001:
					ray_global_dir = (ray.global_transform.basis * ray.target_position).normalized()
				
				var target_forward: Vector3 = Vector3.FORWARD
				if "check_orientation" in collider and not collider.check_orientation:
					direction_alignment = 0.0
					_store_target_view_side(collider, "indifferent")
				else:
					if collider.has_method("get_target_forward_global"):
						target_forward = collider.get_target_forward_global()
					elif "forward_direction" in collider:
						target_forward = (collider.global_transform.basis * collider.forward_direction).normalized()
					else:
						target_forward = -collider.global_transform.basis.z.normalized()
					direction_alignment = clampf(ray_global_dir.dot(target_forward), -1.0, 1.0)
					
					var side = "side"
					if direction_alignment > 0.2:
						side = "front"
					elif direction_alignment < -0.2:
						side = "back"
					_store_target_view_side(collider, side)
				
				if is_final_target:
					# TARGET FINALE
					var all_objectives_collected = (pedestrian.objectives_collected >= pedestrian.level_objectives_count)
					if all_objectives_collected:
						hit_object_type[3] = 1.0  # Target finale valido
					else:
						hit_object_type[4] = 1.0  # Target finale non valido
					n_attr_norm = 0.0
				else:
					# TARGET INTERMEDIO
					var has_requirements = (
						collider.has_method("check_required_objectives") and
						collider.has_method("get_reward_for_objectives")
					)
					
					if has_requirements:
						var requirements_met = collider.check_required_objectives(pedestrian.collected_objective_ids)
						if requirements_met:
							hit_object_type[1] = 1.0  # Target intermedio valido
						else:
							hit_object_type[2] = 1.0  # Target intermedio non valido
					else:
						hit_object_type[1] = 1.0
					
					# Contatore attraversamenti n_attr (Grassi Cap. 4)
					if pedestrian.has_method("get_target_crossings"):
						var crossings = pedestrian.get_target_crossings(collider)
						n_attr_norm = clampf(float(crossings) / 5.0, 0.0, 1.0)
					else:
						n_attr_norm = 0.0
				
			elif collider.is_in_group(Constants.WALLS_GROUP):
				hit_object_type[0] = 1.0
				direction_alignment = 0.0
				n_attr_norm = -1.0

		# 6. AGGIUNGI AI RISULTATI (totale 8 valori per raggio)
		hit_objects.append_array(hit_object_type)
		hit_objects.append(direction_alignment)
		hit_objects.append(n_attr_norm)
		
	return hit_objects

# NUOVO: Memorizza quale lato del target il pedone sta vedendo
func _store_target_view_side(target: Area3D, side: String):
	# Usa i metadata del pedone per salvare temporaneamente quale lato sta vedendo
	if not pedestrian.has_meta("viewed_target_sides"):
		pedestrian.set_meta("viewed_target_sides", {})
	
	var viewed_sides = pedestrian.get_meta("viewed_target_sides")
	
	# Aggiorna solo se è un nuovo target o se il lato è cambiato
	if not viewed_sides.has(target) or viewed_sides[target] != side:
		viewed_sides[target] = side
		pedestrian.set_meta("viewed_target_sides", viewed_sides)
		
		# Debug (opzionale - commenta se non serve)
		# print("👁️ Pedone %s vede target '%s' dal lato: %s" % [pedestrian.name, target.name, side])

func calculate_agents_walls() -> Array:
	# Calcola osservazioni per raggi agenti/muri (23 raggi)
	# Per ogni raggio ritorna 5 valori: [distanza, tipo, cos_heading, sin_heading, velocità]
	var hit_objects := []
	
	for ray in rays_agents_walls:
		# 1. Distanza normalizzata (1.0 = libero)
		var norm_distance = _get_raycast_distance(ray)
		
		# 2. Inizializza valori predefiniti
		var type: float = 0.0          # 0 = niente/muro, 1 = pedone
		var cos_heading: float = 0.0   # Coseno angolo relativo
		var sin_heading: float = 0.0   # Seno angolo relativo
		var speed: float = 0.0         # 0 a 1 (velocità normalizzata)
		
		var collider = ray.get_collider()
		if collider:
			if collider.is_in_group(Constants.PEDESTRIAN_GROUP):
				type = 1.0  # È un pedone
				
				# Calcola differenza di rotazione globale continua
				var diff_rot = collider.global_rotation.y - pedestrian.global_rotation.y
				cos_heading = cos(diff_rot)
				sin_heading = sin(diff_rot)
				
				# Velocità normalizzata dell'altro pedone
				if collider.has_method("get_speed_norm"):
					speed = collider.get_speed_norm()
		
		# Aggiunge tutti i 5 valori
		hit_objects.append(norm_distance)	
		hit_objects.append(type)
		hit_objects.append(cos_heading)
		hit_objects.append(sin_heading)
		hit_objects.append(speed)
	
	return hit_objects

## FUNZIONI DI UTILITÀ

func _get_raycast_distance(ray: RayCast3D) -> float:
	# Calcola la distanza normalizzata (0-1) per un raggio
	# Se il raggio non tocca alcun ostacolo, ritorna 1.0 (spazio libero fino a RAY_LENGTH_OBS)
	# Se c'è collisione, ritorna dist / RAY_LENGTH_OBS compreso in [0, 1]
	if not ray.is_colliding():
		return 1.0

	var origin = ray.global_transform.origin
	var collision_point = ray.get_collision_point()
	var distance = origin.distance_to(collision_point)
	return clampf(distance / Constants.RAY_LENGTH_OBS, 0.0, 1.0)
	
	
## Determina il colore del raggio in base al reward previsto
func _get_target_ray_color(target: Area3D, ray: RayCast3D) -> Color:
	"""
	Determina il colore del raggio in base al reward previsto.
	Usa il direction_alignment per determinare fronte/retro.
	"""
	var COLOR_POSITIVE_REWARD = Color("#00FF00")  # Verde
	var COLOR_NEGATIVE_REWARD = Color("#FF0000")  # Rosso
	var COLOR_NEUTRAL = Color("#FFFF00")          # Giallo
	var COLOR_FINAL = Color("#43A047")            # Verde scuro
	
	# FinalTarget sempre verde scuro
	if target.name.begins_with("FinalTarget"):
		return COLOR_FINAL
	
	# Verifica requisiti
	if not target.has_method("check_required_objectives"):
		return COLOR_NEUTRAL
	
	if not ray.is_colliding():
		return COLOR_NEUTRAL
	
	# Usa direzione raggio calcolata rispetto al target
	var ray_direction = (ray.get_collision_point() - ray.global_transform.origin).normalized()
	if ray_direction.length_squared() < 0.001:
		ray_direction = (ray.global_transform.basis * ray.target_position).normalized()
	
	var viewed_side = target.get_side_from_vector(ray_direction) if target.has_method("get_side_from_vector") else "side"
	
	# Verifica obiettivi
	var all_objectives_collected = target.check_required_objectives(pedestrian.collected_objective_ids)
	
	# Calcola reward prevista
	var predicted_reward = 0.0
	
	if ("check_orientation" in target and not target.check_orientation) or viewed_side == "indifferent":
		if not target.check_objectives or target.required_objectives.is_empty():
			predicted_reward = 0.0
		else:
			predicted_reward = 0.0 if all_objectives_collected else -1.5
	elif viewed_side == "front":
		predicted_reward = 0.0 if all_objectives_collected else -1.5
	elif viewed_side == "back":
		predicted_reward = -1.5 if all_objectives_collected else 0.0
	else:
		return COLOR_NEUTRAL  # Lato
	
	# Ritorna colore
	return COLOR_POSITIVE_REWARD if predicted_reward >= 0 else COLOR_NEGATIVE_REWARD
