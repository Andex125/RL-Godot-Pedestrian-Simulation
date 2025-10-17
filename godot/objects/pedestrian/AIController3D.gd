extends AIController3D

## Ticks for each step
@export var ticks_per_step: int = Constants.TICKS_PER_STEP
var tick_counter: int = 0

## Add all agents to Agent group
func _ready():
	add_to_group(Constants.AGENT_GROUP)

## Compute rewards according to ticks per step 
func _physics_process(_delta):
	# Guard: non fare nulla se il pedone è disabilitato
	if _player.disable:
		return
	
	tick_counter += 1
	tick_counter %= Engine.physics_ticks_per_second
	
	# Esegui logica solo ogni ticks_per_step
	if tick_counter % ticks_per_step == 0:
		n_steps += 1
		
		# ========== DEBUG LOGGING  ==========
		if n_steps % 10 == 0:
			print("[%s] Step %d/%d | Finished: %s | Disable: %s | FinalTarget: %s" % 
				[_player.name, n_steps, reset_after, _player.finished, 
				 _player.disable, _player.final_target_reached])
		# ===============================================
		
		# Controlla timeout SOLO se non è già finished
		if n_steps >= reset_after and not _player.finished:
			print("[TIMEOUT] %s ha raggiunto step %d/%d" % [_player.name, n_steps, reset_after])
			_player.finished = true
			needs_reset = true
		
		# Calcola reward SOLO se non finished (evita accumulo post-episode)
		if not _player.finished:
			_player.compute_rewards()
		
		# Gestisci fine episodio UNA SOLA VOLTA
		# Guard: controlla che non sia già stato chiamato set_end_episode
		if (needs_reset or _player.final_target_reached) and not _player.disable:
			print("[END_EPISODE] %s | Timeout: %s | Target: %s | Steps: %d" % 
				[_player.name, needs_reset, _player.final_target_reached, n_steps])
			
			# Disabilita il pedone (imposta disable = true, impedisce ulteriori chiamate)
			_player.disable_pedestrian()
			
			# Notifica il controller (trigger reset)
			_player.pedestrian_controller.set_end_episode(_player)
			
			# Resetta needs_reset per prevenire loop
			needs_reset = false
			
## Reset after parameter setter
func set_reset_after(steps: int):
	reset_after = steps

## Returns dictionary containing the observations made
func get_obs() -> Dictionary:
	"""
	Ritorna le osservazioni per la rete neurale.
	
	Struttura osservazioni (359 valori totali):
	  - 2 valori: obiettivi raccolti/rimanenti (normalizzati)
	  - 1 valore: velocità corrente (normalizzata)
	  - 161 valori: raggi muri+target (23 × 7)
		  • distanza [0,1]
		  • tipo one-hot [5 valori]
		  • direction_alignment [-1,+1]  ← NUOVO!
	  - 92 valori: raggi muri+agenti (23 × 4)
	  - 92 valori: raggi muri+obiettivi (23 × 4)
	  - 11 valori: vettore stato obiettivi
	"""
	var obs := []
	
	if _player.disable == true:
		# IMPORTANTE: Dimensione FISSA ora!
		var temp_raycast = _player.raycast_sensor.get_observation()
		var total_size = 2  # objectives_collected_norm + objectives_remaining_norm
		total_size += 1  # speed_norm
		total_size += temp_raycast[0].size()  # walls_target
		total_size += temp_raycast[1].size()  # agents_walls
		total_size += temp_raycast[2].size()  # walls_objectives
		total_size += Constants.MAX_OBJECTIVES_IN_CURRICULUM + 1  # FISSA!
		
		for i in range(total_size):
			obs.append(0)
	else:	
		var raycast_obs = _player.raycast_sensor.get_observation()
		
		# 1-2. Obiettivi
		var objectives_collected_norm = 0.0
		if _player.level_objectives_count > 0:
			objectives_collected_norm = float(_player.objectives_collected) / float(_player.level_objectives_count)
		obs.append(objectives_collected_norm)
		
		var objectives_remaining_norm = 0.0
		if _player.level_objectives_count > 0:
			var remaining = _player.level_objectives_count - _player.objectives_collected
			objectives_remaining_norm = float(remaining) / float(_player.level_objectives_count)
		obs.append(objectives_remaining_norm)
		
		# 3. Velocità
		var speed_norm = (_player.speed - _player.speed_min) / (_player.speed_max - _player.speed_min) if _player.speed_max != 0 else 0
		obs.append(speed_norm)
		
		# 4. Raycast
		obs.append_array(raycast_obs[0])
		obs.append_array(raycast_obs[1])
		obs.append_array(raycast_obs[2])
		
		# 5. Direction vector (DIMENSIONE FISSA!)
		var direction_vector = _player.get_objectives_direction_vector()
		
			
			# Visualizzazione leggibile
		
		obs.append_array(direction_vector)
		
		
		# DEBUG
		if n_steps % 100 == 0:
			print("🎯 Agent %s - Speed: %.2f | Collected: %d/%d (%.2f) | Remaining: %.2f" % [
				_player.name,
				speed_norm,
				_player.objectives_collected,
				_player.level_objectives_count,
				objectives_collected_norm,
				objectives_remaining_norm
			])
	
	return {'obs': obs}

## Returns current reward
func get_reward() -> float:	
	var current_reward = reward
	reward = 0
	return current_reward

## Returns dictionary representing the action space
func get_action_space() -> Dictionary:
	return {
			"rotate" : {"size": 1, "action_type": "continuous" },
			"move" : {"size": 1, "action_type": "continuous" },
	}

## Set player's actions
func set_action(action) -> void:	
	_player.set_direction(clampf(action["rotate"][0], -1.0, 1.0))
	_player.set_speed(clampf(action["move"][0], -1.0, 1.0))

## Reset ai controller state
func reset():
	n_steps = 0
	needs_reset = false
