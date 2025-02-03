@tool
extends StaticBody3D
class_name TransformHandle

"TODO"#i would like to have transform handles occupy about
#1/4th of the screenspace at all distances from the handles
enum DirectionTypeEnum
{
	axis_move,
	plane_move,
	axis_rotate,#rotate around center of selection TODO later add tool to move rotational pivot
	
}


@export var set_up : bool = false:
	set(value):
		#rotation MUST be untouched for this to work properly, only rotate and move child nodes into place
		quaternion = Quaternion()
		
		var child_nodes = get_children()
		collider_array.clear()
		for i in child_nodes:
			if i is CollisionShape3D:
				collider_array.append(i)
		mesh_array.clear()
		for j in child_nodes:
			if j is MeshInstance3D:
				mesh_array.append(j)
		
		if color_default == Color() and color_drag == Color():
			if name.to_lower().contains("x"):
				direction_vector = Vector3.RIGHT
				color_default = Color(0.58, 0, 0)
				color_drag = Color(1, 0, 0)
			elif name.to_lower().contains("y"):
				direction_vector = Vector3.UP
				color_default = Color(0, 0.58, 0)
				color_drag = Color(0, 1, 0)
			elif name.to_lower().contains("z"):
				direction_vector = Vector3.BACK
				color_default = Color(0, 0, 0.58)
				color_drag = Color(0, 0, 1)
			if name.contains("2"):
				direction_vector = -direction_vector
		
		if self.material == null:
			material = ShaderMaterial.new()
			"TODO"#not sure if this works, will test tomorrow
			material.shader = preload("res://editor/transform_handles/render_over.gdshader")


@export var identifier : String = ""
@export var direction_vector : Vector3
@export var direction_type : DirectionTypeEnum = DirectionTypeEnum.axis_move

#material to be used
@export var material : Material
@export var color_default : Color
#brighter color
@export var color_drag : Color

#all meshes part of this handle
@export var mesh_array : Array[MeshInstance3D]
#all colliders part of this handle
@export var collider_array : Array[CollisionShape3D]


func _ready():
	for i in mesh_array:
		i.material_override = material
		i.set_instance_shader_parameter("color", color_default)
