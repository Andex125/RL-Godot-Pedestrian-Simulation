extends Area3D
signal custom_body_entered(area: Area3D, body: Node3D)
var active: bool = false  

func _ready():
	# Disabilita monitoring inizialmente
	monitoring = false
	self.body_entered.connect(_custom_body_entered)
	add_to_group(Constants.OBJECTIVES_GROUP)
	
	# Attiva dopo un delay per permettere la randomizzazione
	await get_tree().create_timer(0.5).timeout  
	active = true
	monitoring = true

func _custom_body_entered(body: Node3D):
	if active:  # Solo se attivo
		custom_body_entered.emit(self, body)
