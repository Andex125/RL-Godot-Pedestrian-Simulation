extends Resource
class_name ONNXModel
var inferencer_script = load("res://addons/godot_rl_agents/onnx/csharp/ONNXInference.cs")

var inferencer = null


# Must provide the path to the model and the batch size
func _init(model_path, batch_size):
	inferencer = inferencer_script.new()
	inferencer.Initialize(model_path, batch_size)


# This function is the one that will be called from the game,
# requires the observation as an array and the state_ins as an int
# returns an Array containing the action the model takes.
func run_inference(obs: Array, state_ins: int) -> Dictionary:
	if inferencer == null:
		printerr("Inferencer not initialized")
		return {"output": []}  # Restituisci un Dictionary con struttura base
	
	var result = inferencer.RunInference(obs, state_ins)
	
	# Se RunInference restituisce null, ritorna un Dictionary vuoto
	if result == null:
		printerr("RunInference returned null")
		return {"output": []}
	
	return result


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		inferencer.FreeDisposables()
		inferencer.free()
