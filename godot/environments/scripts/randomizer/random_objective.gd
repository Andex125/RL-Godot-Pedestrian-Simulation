extends Randomizer

@onready var area_shape: CollisionShape3D = $Area/CollisionShape

func _ready():
	# Trova l'objective come figlio diretto di questo nodo
	entity = get_node_or_null("objective")
	
	if entity == null:
		push_error("Non ho trovato il nodo 'objective' come figlio di " + str(get_path()))
		return
	
	if area_shape == null:
		push_error("Non è stata trovata una CollisionShape3D in Area!")
		return
	
	# La classe base Randomizer si aspetta un array di aree
	areas = [area_shape]
	
	# L'offset per il target
	offset = 1.5  # o Constants.TARGET_OFFSET se definito
	
	# Importante: usare call_deferred per assicurarsi che tutto sia pronto
	call_deferred("set_random")

# Override del metodo set_random
func set_random():
	if entity == null or areas.is_empty():
		return
		
	# Chiama il metodo della classe base
	super.set_random()

# Questo metodo viene chiamato quando finisce l'episodio
func get_end_episode():
	if entity == null or areas.is_empty():
		return
	
	# Chiama set_random per randomizzare di nuovo la posizione
	set_random()
