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
	
	if Engine != null and "physics_ticks_per_second" in Engine:
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
	Ritorna le osservazioni per la rete neurale (414 float totali - Opzione B):
	  - 8 valori: cinematica & propriocezione (velocità, rotazione yaw, azioni t-1, tempo residuo, obiettivi)
	  - 6 valori: bussola spaziale polare (prossimo obiettivo [dist, cos, sin], target finale [dist, cos, sin])
	  - 9 valori: checklist obiettivi (-1 padding, 0 da fare, 1 fatto) + 1 final target
	  - 184 valori: raggi muri+target (23 × 8: dist, 5 one-hot, direction_alignment, n_attr)
	  - 115 valori: raggi muri+agenti (23 × 5: dist, type, cos_heading, sin_heading, speed)
	  - 92 valori: raggi muri+obiettivi (23 × 4: dist, 3 one-hot)
	  Totale: 8 + 6 + 9 + 184 + 115 + 92 = 414 float.
	"""
	var obs := []
	
	if _player.disable == true:
		obs.resize(Constants.TOTAL_OBS_SIZE)
		obs.fill(0.0)
	else:
		# 1. Cinematica & Propriocezione (8 float)
		obs.append_array(_player.get_intrinsic_state(self))
		
		# 2. Bussola Spaziale Globale (6 float)
		obs.append_array(_player.get_nearest_active_objective_polar())
		obs.append_array(_player.get_final_target_polar())
		
		# 3. Checklist Obiettivi (9 float)
		obs.append_array(_player.get_objectives_direction_vector())
		
		# 4. Raggi Sensori (391 float = 184 + 115 + 92)
		var raycast_obs = _player.raycast_sensor.get_observation()
		obs.append_array(raycast_obs[0])
		obs.append_array(raycast_obs[1])
		obs.append_array(raycast_obs[2])
		
		# DEBUG
		if n_steps % 100 == 0:
			print("🎯 Agent %s - Speed: %.2f | Collected: %d/%d | Steps: %d/%d" % [
				_player.name,
				_player.get_speed_norm(),
				_player.objectives_collected,
				_player.level_objectives_count,
				n_steps,
				reset_after
			])
	
	assert(obs.size() == Constants.TOTAL_OBS_SIZE, "Errore dimensione obs: attesi %d, calcolati %d" % [Constants.TOTAL_OBS_SIZE, obs.size()])
	var res = {'obs': obs}
	# print("GET_OBS CALLED on ", get_path(), " returning keys: ", res.keys(), " size: ", obs.size())
	return res

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
	var rot: float = action["rotate"][0] if action.has("rotate") and action["rotate"].size() > 0 else 0.0
	var mov: float = action["move"][0] if action.has("move") and action["move"].size() > 0 else 0.0
	_player.set_direction(clampf(rot, -1.0, 1.0))
	_player.set_speed(clampf(mov, -1.0, 1.0))

## Reset ai controller state
func reset():
	n_steps = 0
	needs_reset = false
