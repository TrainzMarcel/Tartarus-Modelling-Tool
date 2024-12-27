extends StaticBody3D
class_name TransformHandle

"TODO"#set the staticbodys layer and mask to 2
#i would like to have transform handles occupy about
#1/4th of the screenspace at all distances from the handles
enum DirectionTypeEnum
{
	axis_move,
	plane_move,
	axis_rotate,#rotate around center of selection TODO later add tool to move rotational pivot
	
}

@export var direction_vector : Vector3
@export var direction_type : DirectionTypeEnum = DirectionTypeEnum.axis_move

#material to be used
@export var material : Material
@export var color_default : Color
#brighter color
@export var color_drag : Color
@export var mesh_array : Array[MeshInstance3D]
#for hovering, scale this up a little bit
@export var collider_array : Array[CollisionShape3D]

func _ready():
	for i in mesh_array:
		i.material_override = material
		i.set_instance_shader_parameter("color", color_default)


func visual_drag():
	for i in mesh_array:
		i.set_instance_shader_parameter("color", color_drag)

func visual_default():
	for i in mesh_array:
		i.set_instance_shader_parameter("color", color_default)
