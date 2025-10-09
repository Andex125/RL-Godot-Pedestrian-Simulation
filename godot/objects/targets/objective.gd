extends Area3D
signal custom_body_entered(area: Area3D, body: Node3D)

@export_category("Objective Settings")
@export var objective_id: int = 0  # ID univoco dell'obiettivo
@export var objective_name: String = ""  # Nome opzionale per debug

var active: bool = false  

func _ready():
	# Disabilita monitoring inizialmente
	monitoring = false
	self.body_entered.connect(_custom_body_entered)
	add_to_group(Constants.OBJECTIVES_GROUP)
	
	# Attiva dopo un delay per permettere la randomizzazione
	await get_tree().create_timer(0.1).timeout  
	active = true
	monitoring = true
	
	# Debug: stampa l'ID dell'obiettivo
	if objective_name.is_empty():
		objective_name = name
	print("Objective '%s' initialized with ID: %d" % [objective_name, objective_id])

func _custom_body_entered(body: Node3D):
	if active:
		custom_body_entered.emit(self, body)

# Metodo helper per ottenere l'ID
func get_objective_id() -> int:
	return objective_id
