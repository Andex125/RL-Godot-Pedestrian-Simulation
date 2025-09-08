extends Randomizer

@onready var passage = $Passage

# Override the entity with the specific node
func _ready():
	# Verifica che il nodo passage esista
	if passage == null:
		push_error("Nodo Passage non trovato in " + str(get_path()))
		return
	
	entity = passage
	offset = 0  # Specific offset for Passage
	areas = find_children("CollisionShapePassage*")
	
	# Verifica che ci siano aree
	if areas.is_empty():
		push_error("Nessuna CollisionShapePassage trovata in " + str(get_path()))
		return
	
	# Usa call_deferred per assicurarti che tutto sia pronto
	call_deferred("set_random")
