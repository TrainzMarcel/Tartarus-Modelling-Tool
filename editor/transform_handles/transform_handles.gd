extends Node3D
class_name TransformHandle

"TODO"#set the staticbodys layer and mask to 2
class HandleData:
	var direction_array : Array[Vector3]
	var color : Color
	var mesh_array : Array[Mesh]
	var staticbody_array : Array[StaticBody3D]
	
	
	

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
