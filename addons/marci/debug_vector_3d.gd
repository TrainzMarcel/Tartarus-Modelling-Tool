@tool
extends MeshInstance3D
class_name DebugVector3D

var cyl : CylinderMesh
@export var color : Color = Color(1.0, 1.0, 1.0) :
	set(value):
		color = value
		mesh.surface_get_material(0).albedo_color = value

@export var origin_position : Vector3 = Vector3.ZERO:
	set(value):
		if !is_inside_tree():
			return
		origin_position = value
		global_position = origin_position + input_vector * 0.5

@export var size : float = 0.5:
	set(value):
		size = value
		cyl.bottom_radius = value


@export var input_vector : Vector3 = Vector3.FORWARD : 
	set(value):
		if !is_inside_tree():
			return
		input_vector = value
		global_position = origin_position + input_vector * 0.5
		scale = Vector3.ONE
		scale.y = input_vector.length()
	#first rotate y to face input vector
		var y_rotation : float = atan2(-input_vector.x, -input_vector.z)
	#then x to rotate up or down toward input vector
		var rotation_vector : Vector3 = input_vector
		rotation_vector.y = 0
	#i am doing the same thing above as with atan, except
	#im providing up and forward vectors that are rotated by the y axis
		var x_rotation : float
		x_rotation = -atan2(rotation_vector.normalized().dot(input_vector.normalized()), Vector3.UP.dot(input_vector.normalized()))
		rotation.x = x_rotation
		rotation.y = y_rotation
	#if i dont set this it flips to 180 and back every execution
		rotation.z = 0



func _init():
	cyl = CylinderMesh.new()
	cyl.top_radius = 0
	cyl.height = 1
	cyl.radial_segments = 16
	cyl.rings = 1
	cyl.cap_top = false
	var mat : StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = mat.TRANSPARENCY_ALPHA
	cyl.material = mat
	mesh = cyl
	rotation_degrees.x = -90
